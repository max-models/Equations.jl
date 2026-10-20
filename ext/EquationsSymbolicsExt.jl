module EquationsSymbolicsExt

using Equations: Equations, Relation, EqualTo, LessEqual, GreaterEqual, AbstractRelation, EquationSystem,
    EquationProblem, ClosedForm, Solution, residual_function, isequality
using Symbolics: Symbolics, Num, substitute, ≲, ≳
using CommonSolve: CommonSolve

Equations.evaluate(ex::Num, x::AbstractDict) = Symbolics.value(substitute(ex, x))

Symbolics.Equation(r::Relation{EqualTo}) = r.lhs ~ r.rhs
Symbolics.Inequality(r::Relation{LessEqual}) = r.lhs ≲ r.rhs
Symbolics.Inequality(r::Relation{GreaterEqual}) = r.lhs ≳ r.rhs

Equations.Relation(eq::Symbolics.Equation) = Relation(EqualTo(), Symbolics.wrap(eq.lhs), Symbolics.wrap(eq.rhs))

function Equations.Relation(ineq::Symbolics.Inequality)
    l, r = Symbolics.wrap(ineq.lhs), Symbolics.wrap(ineq.rhs)
    ineq.relational_op === Symbolics.leq && return Relation(LessEqual(), l, r)
    ineq.relational_op === Symbolics.geq && return Relation(GreaterEqual(), l, r)
    throw(ArgumentError("unsupported relational operator $(ineq.relational_op)"))
end

# Closed-form solutions with Symbolics.symbolic_solve.

# Equations with symbolic sides, for the given Symbolics variables.
function CommonSolve.solve(r::Union{AbstractRelation,EquationSystem}, vars::Union{Num,AbstractVector{Num}}, alg::ClosedForm)
    sys = r isa EquationSystem ? r : EquationSystem(r)
    all(isequality, sys) || throw(ArgumentError("ClosedForm solves equations only"))
    equations = [Symbolics.wrap(rel.lhs) ~ Symbolics.wrap(rel.rhs) for rel in sys]
    solutions = Symbolics.symbolic_solve(length(equations) == 1 ? only(equations) : equations, vars)
    return Solution(_solutions(solutions, vars), :Success, 0, NaN, alg)
end

# Equations with function sides: they are evaluated on Symbolics variables named after the unknowns.
function Equations._closed_form(prob::EquationProblem, alg::ClosedForm)
    u0 = prob.u0
    u0 isa Equations.Bracket && throw(ArgumentError("ClosedForm needs no bracket; give starting values that name the unknowns"))
    vars = u0 isa NamedTuple ? [Symbolics.variable(k) for k in keys(u0)] :
           u0 isa Number ? [Symbolics.variable(:x)] : Symbolics.variables(:x, 1:length(u0))
    residuals = residual_function(prob)(vars)
    equations = [Symbolics.wrap(r) ~ 0 for r in residuals]
    unknowns = length(vars) == 1 ? only(vars) : vars
    solutions = Symbolics.symbolic_solve(length(equations) == 1 ? only(equations) : equations, unknowns)
    found = _solutions(solutions, unknowns)
    shaped = unknowns isa Num ? [_shape([s], u0) for s in found] : [_shape([s[v] for v in vars], u0) for s in found]
    return Solution(shaped, :Success, 0, NaN, alg)
end

# symbolic_solve returns nothing when it finds no solution, values for one unknown and
# dictionaries for several.
_solutions(::Nothing, _) = []
_solutions(solutions, ::Num) = [Symbolics.wrap(s) for s in solutions]
_solutions(solutions, vars) = [Dict(v => Symbolics.wrap(s[v]) for v in vars) for s in solutions]

_shape(values, u0::NamedTuple) = NamedTuple{keys(u0)}(Tuple(values))
_shape(values, ::Number) = only(values)
_shape(values, ::AbstractVector) = collect(values)

end

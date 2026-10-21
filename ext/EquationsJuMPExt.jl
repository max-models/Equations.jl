module EquationsJuMPExt

using Equations: Equations, Relation, EquationSystem, EqualTo, LessEqual, GreaterEqual, comparison,
    JuMPSolver, Solution, Optimum
using JuMP: JuMP, @constraint, @objective, @variable

function Equations.add_constraint!(model::JuMP.AbstractModel, r::Relation{EqualTo})
    l, rh = r.lhs, r.rhs
    return _isvector(r) ? @constraint(model, l .== rh) : @constraint(model, l == rh)
end
function Equations.add_constraint!(model::JuMP.AbstractModel, r::Relation{LessEqual})
    l, rh = r.lhs, r.rhs
    return _isvector(r) ? @constraint(model, l .<= rh) : @constraint(model, l <= rh)
end
function Equations.add_constraint!(model::JuMP.AbstractModel, r::Relation{GreaterEqual})
    l, rh = r.lhs, r.rhs
    return _isvector(r) ? @constraint(model, l .>= rh) : @constraint(model, l >= rh)
end
Equations.add_constraint!(::JuMP.AbstractModel, r::Relation) = throw(ArgumentError(
    "JuMP does not support constraints with comparison $(comparison(r)); use =, ≤ or ≥"))

Equations.add_constraint!(model::JuMP.AbstractModel, sys::EquationSystem) =
    [Equations.add_constraint!(model, r) for r in sys]

_isvector(r::Relation) = r.lhs isa AbstractArray || r.rhs isa AbstractArray

# Feasibility (f === nothing) and optimization with a JuMP optimizer: the unknowns become JuMP
# variables, and the function sides and the objective are called on them.
function Equations._jump_solve(f, sense, sys::EquationSystem, u0, alg::JuMPSolver)
    u0 isa Equations.Bracket && throw(ArgumentError("JuMPSolver needs a starting point, not a bracket"))
    c = Equations.Constraints(sys, u0)
    any(c.strict) && throw(ArgumentError("JuMP does not support strict inequalities (<, >); use ≤ or ≥"))
    model = JuMP.Model(alg.optimizer)
    alg.silent && JuMP.set_silent(model)
    x0 = Equations._vector(u0)
    x = @variable(model, [i in eachindex(x0)], start = x0[i])
    u = Equations._rebuild(x, u0)
    for r in sys
        l, rh = Equations.evaluate(r.lhs, u), Equations.evaluate(r.rhs, u)
        Equations.add_constraint!(model, Relation{typeof(comparison(r))}(l, rh))
    end
    f === nothing || @objective(model, sense > 0 ? JuMP.MIN_SENSE : JuMP.MAX_SENSE, f(u))
    JuMP.optimize!(model)
    status = JuMP.termination_status(model)
    xv = JuMP.has_values(model) ? JuMP.value.(x) : x0
    uv = Equations._rebuild(xv, u0)
    violation = Equations._violation(c, xv)
    iterations = _iterations(model)
    f === nothing && return Solution(uv, _retcode(status), iterations, violation, alg)
    return Optimum(uv, f(uv), _retcode(status), iterations, violation, alg)
end

function _retcode(status)
    status in (JuMP.OPTIMAL, JuMP.LOCALLY_SOLVED, JuMP.ALMOST_OPTIMAL, JuMP.ALMOST_LOCALLY_SOLVED) && return :Success
    status in (JuMP.INFEASIBLE, JuMP.LOCALLY_INFEASIBLE, JuMP.INFEASIBLE_OR_UNBOUNDED) && return :Infeasible
    status == JuMP.DUAL_INFEASIBLE && return :Unbounded
    return Symbol(status)
end

# Not every optimizer reports its iterations.
function _iterations(model)
    for attr in (JuMP.barrier_iterations, JuMP.simplex_iterations)
        n = try
            attr(model)
        catch
            continue
        end
        n > 0 && return Int(n)
    end
    return 0
end

end

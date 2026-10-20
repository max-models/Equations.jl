module EquationsSymbolicsExt

using Equations: Equations, Relation, EqualTo, LessEqual, GreaterEqual
using Symbolics: Symbolics, Num, substitute, ≲, ≳

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

end

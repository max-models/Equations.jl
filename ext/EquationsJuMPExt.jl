module EquationsJuMPExt

using Equations: Equations, Relation, EquationSystem, EqualTo, LessEqual, GreaterEqual, comparison
using JuMP: JuMP, @constraint

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

end

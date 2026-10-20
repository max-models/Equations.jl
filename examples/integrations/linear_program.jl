# # A linear program with JuMP
#
# Write the constraints of a JuMP model as relations, solve it with HiGHS, and check the answer.
#
# thumbnail: max 3x + 2y  s.t.  x + y ≤ 4
# order: 11
#
# A workshop makes tables ($x$) and chairs ($y$) and wants the largest profit $3x + 2y$ with four
# days of work, ten units of wood and at least as many chairs as half the tables.

using Equations
using JuMP
using HiGHS

model = Model(HiGHS.Optimizer)
set_silent(model)
@variable(model, x >= 0)
@variable(model, y >= 0)
@objective(model, Max, 3x + 2y);

# The constraints as an `EquationSystem` of relations between JuMP expressions:

constraints = EquationSystem(
    Relation(<=, x + y, 4),
    Relation(<=, 3x + y, 10),
    Relation(>=, y, x / 2),
)

#

add_constraint!(model, constraints)
model

#

optimize!(model)
termination_status(model), objective_value(model)

#

solution = Dict(x => value(x), y => value(y))

# The same relations check the solution, with plain numbers substituted for the variables:

numeric_value(side) = side isa Number ? side : value(side)
numeric = EquationSystem([Relation(comparison(r), numeric_value(lhs(r)), numeric_value(rhs(r))) for r in constraints])
issatisfied(numeric; atol=1e-8)

# ## Strict inequalities
#
# JuMP has no strict inequalities, so they are refused:

try
    add_constraint!(model, Relation(<, x, 1))
catch err
    println(sprint(showerror, err))
end

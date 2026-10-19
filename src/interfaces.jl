# Functions whose methods are provided by package extensions.

"""
    add_constraint!(model, r::Relation)
    add_constraint!(model, sys::EquationSystem)

Add `r` (or every relation in `sys`) as a constraint to the optimization model
`model`. Available for JuMP models after `using JuMP`.
"""
function add_constraint! end

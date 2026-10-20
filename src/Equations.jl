"""
    Equations

One package for working with equations — and, more generally, relations such as
inequalities — independent of what the two sides are made of: numbers, arrays,
plain Julia functions, symbolic expressions or optimization-model expressions.

See [`Relation`](@ref), [`EquationSystem`](@ref) and [`solve`](@ref).
"""
module Equations

using ADTypes: ADTypes, AutoFiniteDiff, AutoForwardDiff
using CommonSolve: CommonSolve, solve
using LinearAlgebra: norm

export AbstractRelation, Relation, Equation, Inequality, @relation
export Comparison, EqualTo, NotEqualTo, LessThan, LessEqual, GreaterThan, GreaterEqual
export lhs, rhs, comparison, isequality, isinequality
export residual, issatisfied, canonicalize
export EquationSystem, equalities, inequalities
export solve, NewtonMethod, Solution, add_constraint!
export AutoFiniteDiff, AutoForwardDiff

include("relations.jl")
include("operations.jl")
include("system.jl")
include("solve.jl")
include("show.jl")
include("interfaces.jl")

end

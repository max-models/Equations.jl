"""
    Equations

One package for working with equations — and, more generally, relations such as
inequalities — independent of what the two sides are made of: numbers, arrays,
plain Julia functions, symbolic expressions or optimization-model expressions.

See [`Relation`](@ref), [`EquationSystem`](@ref), [`EquationProblem`](@ref) and [`solve`](@ref).
"""
module Equations

using ADTypes: ADTypes, AutoFiniteDiff, AutoForwardDiff
using CommonSolve: CommonSolve, solve
using LinearAlgebra: SingularException, norm

export AbstractRelation, Relation, Equation, Inequality, @relation
export Comparison, EqualTo, NotEqualTo, LessThan, LessEqual, GreaterThan, GreaterEqual
export lhs, rhs, comparison, isequality, isinequality
export residual, issatisfied, canonicalize
export EquationSystem, equalities, inequalities
export EquationProblem, Linear, unknowns, residual_function, linear_system
export solve, default_algorithm, AbstractEquationAlgorithm, NewtonMethod, Bisection, DirectLinear, AllRoots, ClosedForm, Solution
export add_constraint!
export lean, leanvariables, lean_theorem, lean_check, lean_file
export AutoFiniteDiff, AutoForwardDiff

include("relations.jl")
include("operations.jl")
include("system.jl")
include("problem.jl")
include("solve.jl")
include("show.jl")
include("interfaces.jl")
include("lean.jl")

end

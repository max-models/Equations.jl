"""
    Equations

One package for working with equations — and, more generally, relations such as
inequalities — independent of what the two sides are made of: numbers, arrays,
plain Julia functions, symbolic expressions or optimization-model expressions.

See [`Relation`](@ref), [`EquationSystem`](@ref), [`EquationProblem`](@ref),
[`InitialValueProblem`](@ref) and [`solve`](@ref).
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
export TimeDerivative, ∂ₜ, Hamiltonian, InitialValueProblem, vector_field, Trajectory
export AbstractTimeStepper, RungeKutta4, MidpointRule
export add_constraint!
export AutoFiniteDiff, AutoForwardDiff

include("relations.jl")
include("operations.jl")
include("system.jl")
include("problem.jl")
include("solve.jl")
include("evolution.jl")
include("show.jl")
include("interfaces.jl")

end

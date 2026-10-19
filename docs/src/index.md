# Equations.jl

There are too many XYZEquations.jl packages out there; it would obviously be
better to have one package that solves all equations.

Equations.jl provides one small vocabulary for equations, and relations
in general, that works whatever the two sides are made of: numbers,
arrays, plain Julia functions, Symbolics.jl expressions or JuMP expressions.
On top of that it offers a single [`solve`](@ref) entry point.

```jldoctest
julia> using Equations

julia> eq = Equation(x -> x^2, 2)
f(x) = 2

julia> sol = solve(eq, 1.0);

julia> sol.u ≈ √2
true
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/max-models/Equations.jl")
```

## Features

- [`Relation`](@ref) types for `=`, `≠`, `<`, `≤`, `>` and `≥`, with the
  [`Equation`](@ref) and [`Inequality`](@ref) aliases and the [`@relation`](@ref) macro.
- [`residual`](@ref), [`issatisfied`](@ref) and [`canonicalize`](@ref).
- Arithmetic on both sides at once, flipping inequalities where needed.
- [`EquationSystem`](@ref)s that mix equations and inequalities.
- [`solve`](@ref) with a built-in Newton method, or any NonlinearSolve.jl algorithm.
- Package extensions for ForwardDiff.jl, Symbolics.jl, JuMP.jl and NonlinearSolve.jl.

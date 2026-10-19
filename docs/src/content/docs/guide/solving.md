---
title: Systems and solving
description: Collect relations into systems and solve equations with Newton's method or NonlinearSolve.jl.
---

## Systems

An `EquationSystem` is an ordered collection of relations; equations and inequalities may be
mixed. It supports iteration, indexing, `length` and `push!`:

```julia
julia> sys = EquationSystem(
           Equation(x -> x[1]^2 + x[2]^2, 1),
           Equation(x -> x[1], x -> x[2]),
           Relation(>=, x -> x[1], 0))
EquationSystem with 3 relations:
  f(x) = 1
  f(x) = g(x)
  f(x) ≥ 0

julia> length(equalities(sys)), length(inequalities(sys))
(2, 1)

julia> residual(sys, [1.0, 0.0])
3-element Vector{Float64}:
 0.0
 1.0
 1.0
```

`residual` concatenates the residuals of all relations into one vector, and `issatisfied` and
`canonicalize` work on whole systems too.

## Solving

`solve` finds a root of an equation or of a system of equations. The default algorithm is
`NewtonMethod`, Newton's method with no dependencies beyond LinearAlgebra; for systems with more
equations than unknowns it does Gauss–Newton steps.

```julia
julia> sol = solve(Equation(x -> x^2, 2), 1.0)
Solution (retcode: Success, iterations: 4, residual norm: 4.510614104447086e-12)
u: 1.4142135623746899

julia> solve(sys[1:2], [1.0, 0.5]).u
2-element Vector{Float64}:
 0.7071067811873449
 0.7071067811873449
```

The iteration stops once the norm of the residual is at most `abstol` ($10^{-10}$ by default);
the Jacobians are finite differences unless you choose otherwise (see below). `solve` returns a `Solution` with the fields `u`, `retcode` (`:Success` or `:MaxIters`),
`iterations` and `residual_norm`. `NewtonMethod` takes the keywords `ad`, `abstol` and
`maxiters`.

## Choosing the derivatives

Jacobians use central finite differences by default (`AutoFiniteDiff()`). With ForwardDiff.jl
loaded you can switch to automatic differentiation:

```julia
using ForwardDiff
solve(sys[1:2], [1.0, 0.5], NewtonMethod(ad=AutoForwardDiff()))
```

## NonlinearSolve.jl

With NonlinearSolve.jl loaded, any of its algorithms can be passed instead of `NewtonMethod`; the
result is still a `Solution`:

```julia
using NonlinearSolve
solve(sys[1:2], [1.0, 0.5], TrustRegion())
```

`solve` is `CommonSolve.solve`, the function the SciML ecosystem shares, so loading both
packages causes no name clash.

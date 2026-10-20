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

`solve(relations, u0)` finds values of the unknowns that make every equation hold. The starting
values `u0` also say what the unknowns are:

| `u0` | the unknowns, as the function sides receive them | default algorithm |
|---|---|---|
| a number | a scalar `x` | `NewtonMethod` |
| a vector | a vector `x` | `NewtonMethod`, or `DirectLinear` for linear equations |
| a `NamedTuple` such as `(x=1.0, y=0.5)` | named unknowns `u.x`, `u.y` | `NewtonMethod` |
| a tuple `(a, b)` | a scalar in the bracket `[a, b]` | `Bisection` |

```julia
julia> sol = solve(Equation(x -> x^2, 2), 1.0)
Solution (NewtonMethod, retcode: Success, iterations: 4, residual norm: 4.510614104447086e-12)
u: 1.4142135623746899

julia> solve(sys[1:2], [1.0, 0.5]).u
2-element Vector{Float64}:
 0.7071067811873449
 0.7071067811873449
```

`solve` returns a `Solution` with the fields `u` (in the shape of `u0`), `retcode` (`:Success`,
`:MaxIters`, or `:Failure` when a step could not be computed), `iterations`, `residual_norm` and
`alg`, the algorithm that was used.

## Named unknowns

With a `NamedTuple` of starting values the function sides receive the unknowns by name, and the
solution comes back the same way:

```julia
julia> circle = EquationSystem(Equation(u -> u.x^2 + u.y^2, 1), Equation(u -> u.y, u -> u.x / 2));

julia> solve(circle, (x=1.0, y=0.0)).u
(x = 0.8944271909999159, y = 0.4472135954999579)
```

## Brackets

For a scalar equation that changes sign between `a` and `b`, pass the bracket `(a, b)`.
`Bisection` halves it until the floating-point numbers run out: slower than Newton's method, but
it always converges.

```julia
julia> solve(Equation(cos, 0), (0, 2))
Solution (Bisection, retcode: Success, iterations: 54, residual norm: 6.123233995736766e-17)
u: 1.5707963267948966
```

## Linear equations

Write the linear part as `Linear(A)`, the map `x -> A * x`, and `solve` recognises the system and
solves it in one step with `DirectLinear` (least squares when there are more equations than
unknowns):

```julia
julia> solve(Equation(Linear([2.0 1.0; 1.0 3.0]), [3.0, 5.0]), zeros(2))
Solution (DirectLinear, retcode: Success, iterations: 1, residual norm: 0.0)
u: [0.8, 1.4]
```

## All the roots

`AllRoots()` asks for every solution instead of one; `sol.u` is then a vector of solutions. On a
bracket it samples the equation and bisects every sign change:

```julia
julia> solve(Equation(sin, 0), (-1, 7), AllRoots()).u
3-element Vector{Float64}:
 0.0
 3.141592653589793
 6.283185307179586
```

Roots where the function touches zero without changing sign, and roots closer together than the
sampling (`samples=1000` points by default), can be missed. With Polynomials.jl it finds all
complex roots of a polynomial, and with HomotopyContinuation.jl all solutions of a polynomial
system; see [Integrations](/Equations.jl/guide/integrations/#all-roots-polynomials-and-homotopycontinuationjl).

## Problems and algorithms

`solve(relations, u0)` is short for `solve(EquationProblem(relations, u0))`. The problem knows its
unknowns, and `default_algorithm` shows which algorithm `solve` will pick; pass one as the last
argument to override it:

```julia
julia> prob = EquationProblem(circle, (x=1.0, y=0.0))
EquationProblem with unknowns (:x, :y) and starting values (x = 1.0, y = 0.0)
EquationSystem with 2 relations:
  f(x) = 1
  f(x) = g(x)

julia> default_algorithm(prob)
NewtonMethod(ad=AutoFiniteDiff(), abstol=1.0e-10, maxiters=100, linesearch=true)

julia> solve(prob, NewtonMethod(abstol=1e-14)).retcode
:Success
```

`residual_function(prob)` gives the residual as a function of a flat vector of unknowns, and
`linear_system(prob)` the matrix and right-hand side of a linear problem, for use with other
solvers.

## Newton's method

`NewtonMethod` takes the keywords `ad`, `abstol` (the iteration stops once the norm of the
residual is at most this, $10^{-10}$ by default), `maxiters` and `linesearch`. With the line
search, a step that does not reduce the residual is shortened, which rescues starting points where
plain Newton steps overshoot:

```julia
julia> solve(Equation(atan, 0), 3.0, NewtonMethod(linesearch=false)).retcode
:Failure

julia> solve(Equation(atan, 0), 3.0).retcode
:Success
```

## Choosing the derivatives

Jacobians use central finite differences by default (`AutoFiniteDiff()`). With ForwardDiff.jl
loaded you can switch to automatic differentiation:

```julia
using ForwardDiff
solve(sys[1:2], [1.0, 0.5], NewtonMethod(ad=AutoForwardDiff()))
```

## NonlinearSolve.jl

With NonlinearSolve.jl loaded, any of its algorithms can be passed instead of `NewtonMethod`,
with any form of starting values except a bracket; the result is still a `Solution`:

```julia
using NonlinearSolve
solve(sys[1:2], [1.0, 0.5], TrustRegion())
```

`solve` is `CommonSolve.solve`, the function the SciML ecosystem shares, so loading both
packages causes no name clash.

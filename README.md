# Equations.jl

[![CI](https://github.com/max-models/Equations.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/max-models/Equations.jl/actions/workflows/CI.yml)
[![Docs](https://img.shields.io/badge/docs-site-blue.svg)](https://max-models.github.io/Equations.jl/)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

There are too many XYZEquations.jl packages out there, it would obviously be better to have one package that solves all equations

Equations.jl provides one small vocabulary for equations, and relations
in general (`=`, `≠`, `<`, `≤`, `>`, `≥`), that works whatever the two sides
are made of: numbers, arrays, plain Julia functions, Symbolics.jl expressions or
JuMP expressions. On top of that it offers a single `solve` entry point.

## Quick start

```julia
using Equations

# Define
eq   = Equation(x -> x^2, 2)                       # x² = 2
disk = Relation(<=, x -> x[1]^2 + x[2]^2, 1)       # ‖x‖² ≤ 1
x = 3; @relation x^2 > 2x                          # 9 > 6

# Check
issatisfied(disk, [0.5, 0.5])                      # true
residual(disk, [1.0, 1.0])                         # 1.0

# Manipulate
Relation(<=, 1, 2) * -2                            # -2 ≥ -4
Relation(<=, 1, 2) + Relation(<, 3, 4)             # 4 < 6
canonicalize(Relation(>=, 1, 3))                   # 2 ≤ 0

# Solve
solve(eq, 1.0).u                                   # ≈ 1.41421

sys = EquationSystem(Equation(x -> x[1]^2 + x[2]^2, 1),
                     Equation(x -> x[1], x -> x[2]))
solve(sys, [1.0, 0.5]).u                           # ≈ [0.70711, 0.70711]

# The starting values pick the unknowns, and solve picks the algorithm
solve(Equation(cos, 0), (0, 2)).u                  # bracket → Bisection: π/2
rect = EquationSystem(Equation(u -> u.w * u.h, 12), Equation(u -> 2u.w + 2u.h, 14))
solve(rect, (w=5.0, h=1.0)).u                      # named unknowns: ≈ (w = 4.0, h = 3.0)
solve(Equation(Linear([2.0 1.0; 1.0 3.0]), [3.0, 5.0]), zeros(2)).u   # linear → DirectLinear: [0.8, 1.4]
solve(Equation(sin, 0), (-1, 7), AllRoots()).u     # every root in the bracket: [0, π, 2π]
```

## Integrations

Package extensions load automatically together with the corresponding package:

| Package          | What you get                                                                     |
| ---------------- | -------------------------------------------------------------------------------- |
| ForwardDiff.jl   | `NewtonMethod(ad=AutoForwardDiff())`: exact Jacobians in `solve`                 |
| NonlinearSolve.jl | `solve(sys, x0, TrustRegion())`, or any other NonlinearSolve algorithm          |
| LinearSolve.jl   | `solve(eq, x0, KrylovJL_CG())`: sparse and iterative solvers for `Linear(A)` equations |
| Roots.jl         | `solve(eq, (a, b), Roots.Brent())`, or any other Roots method for scalar equations |
| Polynomials.jl   | Polynomial sides, and `solve(eq, AllRoots())` for all their complex roots        |
| HomotopyContinuation.jl | `AllRoots()` for all solutions of polynomial systems                      |
| Symbolics.jl     | Conversion to and from `Symbolics.Equation`/`Inequality`, evaluation by substitution |
| JuMP.jl          | `add_constraint!(model, relation_or_system)`                                     |

`solve` is `CommonSolve.solve`, so it does not clash with the SciML ecosystem.
Symbolics.jl also exports `Equation` and `Inequality`; when both packages are
loaded, write `Equations.Equation` and `Equations.Inequality`.

## Documentation

The site at <https://max-models.github.io/Equations.jl/> has a guide, a gallery of
[examples](examples/) run at build time, and the API reference. It is built with the shared
[max-models starlight-theme](https://github.com/max-models/starlight-theme); see
[Building the docs](https://max-models.github.io/Equations.jl/development/docs/) to preview it
locally or add an example.

## Development

```julia
julia> ] activate .
julia> ] test
```

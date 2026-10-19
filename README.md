# Equations.jl

[![CI](https://github.com/max-models/Equations.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/max-models/Equations.jl/actions/workflows/CI.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://max-models.github.io/Equations.jl/dev/)
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
```

## Integrations

Package extensions load automatically together with the corresponding package:

| Package          | What you get                                                                     |
| ---------------- | -------------------------------------------------------------------------------- |
| ForwardDiff.jl   | `NewtonMethod(ad=AutoForwardDiff())`: exact Jacobians in `solve`                 |
| NonlinearSolve.jl | `solve(sys, x0, TrustRegion())`, or any other NonlinearSolve algorithm          |
| Symbolics.jl     | Conversion to and from `Symbolics.Equation`/`Inequality`, evaluation by substitution |
| JuMP.jl          | `add_constraint!(model, relation_or_system)`                                     |

`solve` is `CommonSolve.solve`, so it does not clash with the SciML ecosystem.
Symbolics.jl also exports `Equation` and `Inequality`; when both packages are
loaded, write `Equations.Equation` and `Equations.Inequality`.

## Development

```julia
julia> ] activate .
julia> ] test
```

Documentation is built with `julia --project=docs docs/make.jl`.

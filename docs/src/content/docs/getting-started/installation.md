---
title: Installation
description: Add Equations.jl to a Julia environment.
---

Equations.jl needs Julia 1.10 or later. It is not registered yet; add it from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/max-models/Equations.jl")
```

and load it:

```julia
using Equations
```

The core package depends only on ADTypes.jl, CommonSolve.jl and LinearAlgebra. The integrations
are package extensions: they load automatically when the corresponding package is loaded too.

| Package | Adds |
|---|---|
| [ForwardDiff.jl](https://github.com/JuliaDiff/ForwardDiff.jl) | `NewtonMethod(ad=AutoForwardDiff())`: exact Jacobians in `solve` |
| [NonlinearSolve.jl](https://github.com/SciML/NonlinearSolve.jl) | `solve(sys, x0, TrustRegion())`, or any other NonlinearSolve algorithm |
| [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl) | Conversion to and from `Symbolics.Equation`/`Inequality`, evaluation by substitution |
| [JuMP.jl](https://github.com/jump-dev/JuMP.jl) | `add_constraint!(model, relation_or_system)` |

Next: the [guide](/Equations.jl/guide/relations/) or the [examples](/Equations.jl/examples/).

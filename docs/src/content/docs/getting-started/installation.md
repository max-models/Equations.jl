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
| [LinearSolve.jl](https://github.com/SciML/LinearSolve.jl) | `solve(eq, x0, KrylovJL_CG())`: sparse and iterative solvers for `Linear(A)` equations |
| [Roots.jl](https://github.com/JuliaMath/Roots.jl) | `solve(eq, (a, b), Roots.Brent())`, or any other Roots method for scalar equations |
| [Polynomials.jl](https://github.com/JuliaMath/Polynomials.jl) | Polynomial sides, and `AllRoots()` for all their complex roots |
| [HomotopyContinuation.jl](https://www.juliahomotopycontinuation.org) | `AllRoots()` for all solutions of polynomial systems |
| [GeometricIntegrators.jl](https://github.com/JuliaGNI/GeometricIntegrators.jl) | Geometric integrators (`Gauss(2)`, `SymplecticEulerA()`, …) for evolution equations and Hamiltonian systems |
| [Symbolics.jl](https://github.com/JuliaSymbolics/Symbolics.jl) | Conversion to and from `Symbolics.Equation`/`Inequality`, evaluation by substitution, `ClosedForm()` for exact solutions |
| [JuMP.jl](https://github.com/jump-dev/JuMP.jl) | `add_constraint!(model, relation_or_system)` |

Next: the [guide](/Equations.jl/guide/relations/) or the [examples](/Equations.jl/examples/).

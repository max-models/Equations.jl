---
title: Integrations
description: Solvers and expression types from other packages, through package extensions.
---

Each integration is a package extension: it loads by itself when the package is loaded next to
Equations.jl. ForwardDiff.jl and NonlinearSolve.jl are covered in
[Systems and solving](/Equations.jl/guide/solving/).

## LinearSolve.jl

For linear problems, written with `Linear(A)`, any LinearSolve.jl algorithm can be passed to
`solve`: sparse factorizations, or Krylov methods for large systems. The matrix goes to the
solver as it is, so a sparse matrix stays sparse.

```julia
using Equations, LinearSolve, SparseArrays

n = 1000
A = spdiagm(-1 => -ones(n - 1), 0 => 2ones(n), 1 => -ones(n - 1))
eq = Equation(Linear(A), ones(n))
solve(eq, zeros(n), KrylovJL_CG())        # conjugate gradients
solve(eq, zeros(n), KLUFactorization())   # sparse LU
```

## Roots.jl

Roots.jl's methods solve scalar equations: its bracketing methods (`Brent()`, `A42()`, `ITP()`,
…) from a bracket, converging much faster than `Bisection`, and its derivative-free methods
(`Order1()`, …) from a starting point.

```julia
using Equations, Roots

solve(Equation(cos, 0), (0, 2), Roots.Brent())
solve(Equation(x -> x^3, 2), 1.0, Roots.Order1())
```

## All roots: Polynomials and HomotopyContinuation.jl

With Polynomials.jl, polynomials can be the sides of equations, and `AllRoots()` computes all
their complex roots; no starting values are needed. The other algorithms work with polynomial
sides too.

```julia
using Equations, Polynomials

p = Polynomial([-6, 11, -6, 1])               # (x - 1)(x - 2)(x - 3)
solve(Equation(p, 0), AllRoots()).u            # [1.0, 2.0, 3.0]
solve(Equation(Polynomial([1, 0, 1]), 0), AllRoots(real=true)).u   # x² + 1: none real
```

With HomotopyContinuation.jl, `AllRoots()` finds all isolated complex solutions of a system of
polynomial equations written as ordinary Julia functions; the starting values only name the
unknowns. HomotopyContinuation exports its own `solve`, so the one of Equations is written
`Equations.solve`:

```julia
using Equations, HomotopyContinuation

sys = EquationSystem(Equation(u -> u.x^2 + u.y^2, 4), Equation(u -> u.y, u -> u.x^2 - 2))
Equations.solve(sys, (x=0.0, y=0.0), AllRoots(real=true)).u   # the real intersections
```

## Symbolics.jl

Symbolic expressions work as sides directly. The extension adds conversions to and from
Symbolics' own types, and evaluation by substitution.

:::caution
Symbolics also exports `Equation` and `Inequality`, so when both packages are loaded those two
names must be qualified, e.g. `Equations.Equation`.
:::

```julia
using Equations, Symbolics
@variables x y

r = Relation(<=, x^2 + y, 1)
issatisfied(r, Dict(x => 0.5, y => 0.5))           # true
Symbolics.Equation(Equations.Equation(x^2, 2))     # x^2 ~ 2
Relation(x^2 ~ 2)                                  # x^2 = 2
Relation(x ≲ 1)                                    # x ≤ 1
```

## JuMP.jl

Relations between JuMP expressions can be added to a model as constraints, one at a time or as a
whole system. JuMP has no strict inequalities, so only `=`, `≤` and `≥` are accepted.

```julia
using Equations, JuMP
model = Model()
@variable(model, x[1:2])
add_constraint!(model, Relation(<=, x[1] + x[2], 1))
add_constraint!(model, EquationSystem(Equation(x[1], 0.5), Relation(>=, x[2], 0)))
```

See the [optimization example](/Equations.jl/examples/linear-program/) for a full model solved
with HiGHS.

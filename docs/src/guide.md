# Guide

```@meta
DocTestSetup = :(using Equations)
```

## Building relations

A [`Relation`](@ref) stores a left-hand side, a right-hand side and a
[`Comparison`](@ref). Build one from a Base comparison function, with the
[`Equation`](@ref) shorthand, or with the [`@relation`](@ref) macro:

```jldoctest
julia> Relation(<=, 1, 2)
1 ≤ 2

julia> Equation(2 + 2, 4)
4 = 4

julia> x = 3; @relation x^2 > 2x
9 > 6
```

The sides are stored as given and are not compared until you ask, so they can
be any type that supports subtraction.

## Functions as sides

When a side is a `Function`, it is evaluated at a point you supply:

```jldoctest
julia> disk = Relation(<=, x -> x[1]^2 + x[2]^2, 1);

julia> issatisfied(disk, [0.5, 0.5])
true

julia> residual(disk, [1.0, 1.0])
1.0
```

## Manipulating relations

Arithmetic applies to both sides. Multiplying or dividing an inequality by a
negative number flips it, and adding relations adds them side by side:

```jldoctest
julia> -Relation(<, 1, 2)
-1 > -2

julia> Relation(<=, 1, 2) * -2
-2 ≥ -4

julia> Relation(<=, 1, 2) + Relation(<, 3, 4)
4 < 6

julia> reverse(Relation(<, 1, 2))
2 > 1
```

[`canonicalize`](@ref) moves everything to the left-hand side and turns `≥`/`>`
into `≤`/`<`, the form optimizers expect:

```jldoctest
julia> canonicalize(Relation(>=, 1, 3))
2 ≤ 0
```

## Systems

```jldoctest
julia> sys = EquationSystem(
           Equation(x -> x[1]^2 + x[2]^2, 1),
           Equation(x -> x[1], x -> x[2]),
           Relation(>=, x -> x[1], 0));

julia> length(equalities(sys)), length(inequalities(sys))
(2, 1)
```

## Solving

[`solve`](@ref) finds a root of an equation or a system of equations
with Newton's method:

```jldoctest
julia> sol = solve(EquationSystem(Equation(x -> x[1]^2 + x[2]^2, 1), Equation(x -> x[1], x -> x[2])), [1.0, 0.5]);

julia> sol.retcode, sol.u ≈ [1, 1] / √2
(:Success, true)
```

Jacobians use finite differences by default. With ForwardDiff.jl loaded you can
switch to automatic differentiation:

```julia
using ForwardDiff
solve(sys, x0, NewtonMethod(ad=AutoForwardDiff()))
```

With NonlinearSolve.jl loaded, any of its algorithms can be used instead:

```julia
using NonlinearSolve
solve(sys, x0, TrustRegion())
```

`solve` is the `CommonSolve.solve` function shared with the SciML ecosystem, so
there are no name clashes.

## Symbolics.jl

Symbolic expressions work as sides directly. The extension adds conversions
to and from Symbolics' own types, and evaluation by substitution.

Symbolics also exports `Equation` and `Inequality`, so when both packages are
loaded those two names must be qualified, e.g. `Equations.Equation`:

```julia
using Symbolics
@variables x y
r = Relation(<=, x^2 + y, 1)
issatisfied(r, Dict(x => 0.5, y => 0.5))        # true
Symbolics.Equation(Equations.Equation(x^2, 2))  # x^2 ~ 2
Relation(x^2 ~ 2)                               # x^2 = 2
```

## JuMP.jl

Relations between JuMP expressions can be added to a model as constraints:

```julia
using JuMP
model = Model()
@variable(model, x[1:2])
add_constraint!(model, Relation(<=, x[1] + x[2], 1))
add_constraint!(model, EquationSystem(Equation(x[1], 0.5), Relation(>=, x[2], 0)))
```

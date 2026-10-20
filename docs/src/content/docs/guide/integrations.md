---
title: Integrations
description: Symbolics.jl and JuMP.jl expressions as the sides of relations.
---

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

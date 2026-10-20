---
title: Relations
description: Build, check and manipulate equations and inequalities.
---

## Building relations

A `Relation` stores a left-hand side, a right-hand side and a `Comparison`. Build one from a
Base comparison function, with the `Equation` shorthand, or with the `@relation` macro:

```julia
julia> Relation(<=, 1, 2)
1 ≤ 2

julia> Equation(2 + 2, 4)
4 = 4

julia> x = 3; @relation x^2 > 2x
9 > 6
```

The sides are stored as given and are not compared until you ask, so they can be anything that
supports subtraction: numbers, arrays, symbolic expressions, JuMP expressions.

The comparisons are the singleton types `EqualTo`, `NotEqualTo`, `LessThan`, `LessEqual`,
`GreaterThan` and `GreaterEqual`. `Equation` is an alias for `Relation{EqualTo}`, and
`Inequality` matches any relation with `<`, `≤`, `>` or `≥`:

```julia
julia> comparison(Relation(>=, 1, 0))
≥

julia> Relation(<, 1, 2) isa Inequality, isequality(Equation(1, 1))
(true, true)
```

## Functions as sides

When a side is a `Function`, it is evaluated at a point you supply. Anonymous functions print as
`f(x)` on the left and `g(x)` on the right; named functions print by name:

```julia
julia> disk = Relation(<=, x -> x[1]^2 + x[2]^2, 1)
f(x) ≤ 1

julia> issatisfied(disk, [0.5, 0.5])
true

julia> residual(disk, [1.0, 1.0])
1.0

julia> Equation(sin, cos)
sin(x) = cos(x)
```

`issatisfied` takes an absolute tolerance on the residual: an equation holds when
$|\mathrm{lhs} - \mathrm{rhs}| \le \mathrm{atol}$, an inequality $\mathrm{lhs} \le \mathrm{rhs}$ when
$\mathrm{lhs} - \mathrm{rhs} \le \mathrm{atol}$. Array-valued sides must hold elementwise.

```julia
julia> issatisfied(Equation(sin, cos), π / 4; atol=1e-12)
true
```

## Manipulating relations

Arithmetic applies to both sides. Multiplying or dividing an inequality by a negative number
flips it, and adding relations adds them side by side:

```julia
julia> -Relation(<, 1, 2)
-1 > -2

julia> Relation(<=, 1, 2) * -2
-2 ≥ -4

julia> Relation(<=, 1, 2) + Relation(<, 3, 4)
4 < 6

julia> reverse(Relation(<, 1, 2))
2 > 1
```

Multiplying an inequality by zero, or dividing anything by zero, throws a `DomainError`.

`canonicalize` moves everything to the left-hand side and turns `≥` and `>` into `≤` and `<`,
the form $g(x) \le 0$, $h(x) = 0$ that optimizers expect:

```julia
julia> canonicalize(Relation(>=, 1, 3))
2 ≤ 0
```

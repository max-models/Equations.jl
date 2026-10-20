---
title: Lean 4
description: Write equations, inequalities and their solutions as Lean 4 theorems about real numbers.
---

Equations.jl writes relations as statements about real numbers in
[Lean 4](https://lean-lang.org) with [Mathlib](https://leanprover-community.github.io), so that
what was solved numerically can be stated, checked and proved formally.

## Relations as Lean propositions

The sides have to be expressions rather than functions: write the relation as a quoted
comparison, or use Symbolics.jl expressions. `lean` translates numbers, variables, `+`, `-`, `*`,
`/`, `^`, `sqrt`, `exp`, `log`, the trigonometric and hyperbolic functions, `abs` and `π`:

```julia
julia> r = Relation(:(x^2 + y^2 <= 1))
x ^ 2 + y ^ 2 ≤ 1

julia> lean(r)
"(x ^ 2 + y ^ 2 : ℝ) ≤ 1"

julia> lean(:(sqrt(2) * exp(-t / 2)))
"Real.sqrt 2 * Real.exp (-t / 2)"
```

Every relation types its left-hand side as `ℝ`, so that numerals are real numbers. Exponents that
are natural numbers stay as they are; other exponents are typed explicitly, because Lean would
otherwise compute `1 / 2` in the natural numbers, where it is `0`:

```julia
julia> lean(:(x^(1//2) + x^-1))
"x ^ (1 / 2 : ℝ) + x ^ (-1 : ℤ)"
```

## Theorems

`lean_theorem` states that hypotheses imply a conclusion, for all real values of the variables.
The proof is `sorry` unless you give one, so Lean checks the statement and leaves the proof open:

```julia
julia> print(lean_theorem(Relation(:(x == 2)); name="solve_linear", hypotheses=[Relation(:(3x + 1 == 7))]))
theorem solve_linear (x : ℝ) (h₁ : (3 * x + 1 : ℝ) = 7) :
    (x : ℝ) = 2 := by
  sorry
```

## Checking solutions

`lean_check` substitutes a solution into the relations, which leaves a statement about numbers
alone; for rational solutions `norm_num` proves it:

```julia
julia> sys = EquationSystem(Relation(:(x + y == 3)), Relation(:(x - y == 1)));

julia> sol = solve(EquationSystem(Equation(u -> u.x + u.y, 3), Equation(u -> u.x - u.y, 1)), (x=0.0, y=0.0)).u
(x = 2.0, y = 1.0)

julia> print(lean_check(sys, (x=2, y=1)))
theorem solution_check :
    ((2 + 1 : ℝ) = 3) ∧ ((2 - 1 : ℝ) = 1) := by
  norm_num
```

Values can be expressions too, such as an exact solution `:(sqrt(2))`, or, with Symbolics.jl, the
exact solutions that `ClosedForm()` finds. `lean_file(theorems...)` puts theorems into a Lean
source file that imports Mathlib.

## Checking the generated code

The repository has a small Lean project in `lean/`: `lean/generate.jl` writes theorems generated
from the examples into it, and the `Lean` workflow builds them against Mathlib on every pull
request, so that the translation stays valid Lean.

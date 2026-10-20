---
title: Inequalities and optimization
description: Find points that satisfy systems of inequalities, and minimize or maximize subject to equations and inequalities.
---

## Feasibility

A system with inequalities is solved by finding a point that satisfies all of its relations.
`solve` then uses `Feasibility()`, which minimizes how far the relations are from holding, with
Levenberg–Marquardt steps:

```julia
julia> disc = EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5))
EquationSystem with 2 relations:
  f(x) ≤ 1
  f(x) ≥ 0.5

julia> sol = solve(disc, (x=-2.0, y=2.0))
Solution (Feasibility, retcode: Success, iterations: 6, residual norm: 0.0)
u: (x = 0.5000000097005604, y = 0.8660253935909558)

julia> issatisfied(disc, sol.u)
true
```

The steps aim a small `margin` (`1e-8`) inside the inequalities, so they hold exactly where the
region has an interior; equations hold to the tolerance `abstol` (`1e-10`), and so do `≤`, `≥`
where the region is only a boundary. Strict inequalities `<`, `>` always hold exactly. A starting
point that already satisfies the system comes back unchanged.

```julia
julia> solve(EquationSystem(Relation(>, x -> x, 2), Relation(<, x -> x, 3)), 0.0).u
2.000000009926033
```

When the violation cannot be reduced any further, the retcode is `:Infeasible`. That proves
nothing on its own: `Feasibility` is a local method, and a system with a solution far from the
start can stop at a local minimum of the violation. The `residual_norm` says how far the point is
from satisfying the system.

```julia
julia> solve(EquationSystem(Relation(<=, x -> x, 0), Relation(>=, x -> x, 1)), 0.5)
Solution (Feasibility, retcode: Infeasible, iterations: 1, residual norm: 0.7071067811865475)
u: 0.4999999999988553
```

## Minimizing and maximizing

`minimize(f, u0; subject_to=constraints)` finds the minimum of the objective `f(u)` subject to
equations and inequalities: a `Relation`, an `EquationSystem` or a vector of relations. The
starting values name the unknowns as for `solve`. The result is an `Optimum` with the fields `u`,
`objective`, `retcode`, `iterations`, `violation` (how far `u` is from satisfying the constraints)
and `alg`:

```julia
julia> opt = minimize(u -> (u.x - 1)^2 + (u.y - 2)^2, (x=0.0, y=0.0); subject_to=Relation(<=, u -> u.x + u.y, 1))
Optimum (AugmentedLagrangian, retcode: Success, iterations: 24, violation: 9.328586347834289e-9)
u: (x = 4.8032305043249725e-9, y = 1.0000000045253559)
objective: 1.9999999813428273

julia> maximize(u -> u.x * u.y, (x=1.0, y=1.0); subject_to=Equation(u -> 2u.x + 2u.y, 20)).u
(x = 5.000000001624851, y = 5.000000001624851)
```

Without constraints, it is plain minimization:

```julia
julia> minimize(u -> (1 - u[1])^2 + 100 * (u[2] - u[1]^2)^2, [-1.2, 1.0]).u
2-element Vector{Float64}:
 0.9999999928048707
 0.9999999856455204
```

The default algorithm, `AugmentedLagrangian()`, minimizes the objective plus multiplier and
penalty terms for the constraints with BFGS, updating the multipliers and raising the penalty
until the constraints hold to `abstol` (`1e-8`). Like `Feasibility`, it is a local method: it finds a local minimum near the
start. Strict inequalities are refused, since their optimum generally lies on the boundary they
exclude. With `using ForwardDiff`, `AugmentedLagrangian(ad=AutoForwardDiff())` uses exact
gradients and finds the optimum to more digits; `Feasibility(ad=AutoForwardDiff())` likewise.

## JuMP optimizers

`JuMPSolver(optimizer)` hands the problem to a [JuMP](https://jump.dev) optimizer: HiGHS for
linear and quadratic problems, Ipopt for nonlinear ones, or any other. The unknowns become JuMP
variables and the function sides and objective are called on them, so they must be built from
operations JuMP knows: arithmetic, powers, `sin`, `exp` and the like. It works for `minimize`,
`maximize` and feasibility with `solve`:

```julia
using Equations, JuMP, HiGHS, Ipopt

# a linear program: the largest profit 3x + 2y
maximize(u -> 3u.x + 2u.y, (x=0.0, y=0.0), JuMPSolver(HiGHS.Optimizer);
         subject_to=[Relation(<=, u -> u.x + u.y, 4), Relation(<=, u -> u.x + 3u.y, 6),
                     Relation(>=, u -> u.x, 0), Relation(>=, u -> u.y, 0)])   # x = 4, y = 0: 12

# nonlinear: the closest point on the unit circle to (2, 1)
minimize(u -> (u.x - 2)^2 + (u.y - 1)^2, (x=0.0, y=1.0), JuMPSolver(Ipopt.Optimizer);
         subject_to=Equation(u -> u.x^2 + u.y^2, 1))                          # (2, 1)/√5

# a feasible point
solve(EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5)),
      (x=-2.0, y=2.0), JuMPSolver(Ipopt.Optimizer))
```

The retcode is `:Success`, `:Infeasible`, `:Unbounded` or, for anything else, the JuMP
termination status as a symbol. As with `add_constraint!`, strict inequalities are not supported.

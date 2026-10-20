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

## Map of mathematics

The goal is one package that solves all equations. This map lists the kinds of equations across
mathematics and ticks the ones Equations.jl can solve today; an unticked item with a note is
partly there. Items marked *(roadmap n)* are the next planned steps.

### Representing equations
- [x] Equations and inequalities (`=`, `≠`, `<`, `≤`, `>`, `≥`) between numbers, arrays and functions
- [x] Systems of equations and inequalities
- [x] Named unknowns
- [x] Algebra on relations: arithmetic on both sides, adding relations, canonical form `g ≤ 0`, `h = 0`
- [x] Symbolic sides (Symbolics.jl) and optimization-model sides (JuMP.jl)
- [ ] Parameters (`f(x, p)`) and solving for a chosen unknown in terms of the others
- [ ] Units (Unitful.jl)
- [x] Lean 4 output: relations as Mathlib statements about real numbers, solutions as theorems (`lean`, `lean_theorem`, `lean_check`), checked against Mathlib in CI
- [ ] Proofs beyond `norm_num`: tactics chosen for the statement, proofs of closed-form solutions

### Algebraic equations
- [x] Linear systems, dense and sparse, direct and iterative (LinearSolve.jl)
- [x] Overdetermined linear systems (least squares)
- [ ] Underdetermined linear systems: minimum-norm solution and the full solution set (null space)
- [x] Scalar nonlinear equations from a starting point (Newton, Roots.jl)
- [x] Scalar nonlinear equations on a bracket, with guaranteed convergence (bisection, Brent, …)
- [x] Nonlinear systems (Newton with line search, NonlinearSolve.jl)
- [x] Overdetermined nonlinear systems (Gauss–Newton, nonlinear least squares)
- [x] All complex roots of a polynomial (Polynomials.jl)
- [x] All solutions of a polynomial system (HomotopyContinuation.jl)
- [ ] All roots in a region, proven complete (interval methods) *(roadmap 8)*
- [ ] All roots in an interval, including roots without a sign change (partly: `AllRoots` finds the sign changes)
- [ ] Fixed-point equations `x = g(x)` (Anderson acceleration)
- [ ] Equations over complex unknowns
- [ ] Equations with matrix unknowns: Sylvester, Lyapunov, algebraic Riccati
- [ ] Eigenvalue problems `A x = λ x`, generalized and nonlinear
- [ ] Parametric systems and continuation, bifurcation diagrams (BifurcationKit.jl)

### Symbolic and exact
- [ ] Closed-form solutions (`x^2 ~ 2` → `±√2`) *(roadmap 5)*
- [ ] Exact rational and integer linear algebra
- [ ] Diophantine equations: linear, Pell, Pythagorean triples
- [ ] Modular equations and congruences, Chinese remainder theorem
- [ ] Equations over finite fields
- [ ] Gröbner bases for polynomial systems

### Inequalities and optimization
- [x] Checking inequalities on a solution (`issatisfied`)
- [ ] Feasibility: find a point satisfying a system of inequalities *(roadmap 6)*
- [ ] Linear programming (partly: relations become JuMP constraints with `add_constraint!`)
- [ ] Nonlinear optimization with equality and inequality constraints *(roadmap 6)*
- [ ] Mixed-integer problems
- [ ] Complementarity problems and variational inequalities
- [ ] Semidefinite and conic constraints

### Differential equations
- [ ] Ordinary differential equations, initial value problems *(roadmap 7)*
- [ ] Boundary value problems (partly: by discretizing by hand, see the sparse Poisson example)
- [ ] Differential-algebraic equations
- [ ] Delay differential equations
- [ ] Stochastic differential equations
- [ ] Partial differential equations: elliptic, parabolic, hyperbolic *(roadmap 9)*
- [ ] Eigenvalue problems for differential operators (Sturm–Liouville, Schrödinger)
- [ ] Fractional differential equations
- [ ] Hamiltonian, Lagrangian and other structure-preserving integration: see *Geometric numerical integration* below

### Geometric numerical integration
Structure-preserving integrators keep the geometry of a problem (symplecticity, energy, momenta,
constraints) over long times. The [JuliaGNI](https://github.com/JuliaGNI) packages by Michael Kraus
cover this field; the equation types are those of GeometricEquations.jl, solved with
GeometricIntegrators.jl.
- [ ] Ordinary and implicit ODEs (`ODE`, `IODE`) with GeometricIntegrators.jl and the Runge–Kutta tableaus of RungeKutta.jl
- [ ] Partitioned and Hamiltonian ODEs (`PODE`, `HODE`): symplectic and partitioned Runge–Kutta, Gauss–Legendre
- [ ] Lagrangian ODEs (`LODE`) and variational integrators (VPRK, degenerate variational integrators)
- [ ] Euler–Lagrange and Hamilton's equations generated from a Lagrangian or Hamiltonian (EulerLagrange.jl)
- [ ] Discrete Euler–Lagrange equations (`DELE`)
- [ ] Split ODEs (`SODE`): splitting and composition methods (Lie–Trotter, Strang, higher order)
- [ ] Constrained systems (`DAE`, `PDAE`, `HDAE`, `IDAE`, `LDAE`): SPARK methods and projections onto the constraints
- [ ] Stochastic systems (`SDE`, `PSDE`, `SPSDE`): stochastic symplectic and variational integrators (StochasticIntegrators.jl)
- [ ] Integrators with nonlinear, e.g. neural-network, bases in time (NonlinearIntegrators.jl)
- [ ] Invariants: energy, momenta and Casimirs, and their long-time behaviour
- [ ] Poincaré integral invariants (PoincareInvariants.jl)
- [ ] Hamiltonian PDEs through discretised Poisson brackets (GeometricBrackets.jl)
- [ ] Ensembles of initial conditions and parameters
- [ ] The test problems of GeometricProblems.jl (harmonic oscillator, pendulum, Kepler, Lotka–Volterra, …) as examples
- [ ] Structure-preserving learned models: symplectic networks, symplectic autoencoders (GeometricMachineLearning.jl)
- [ ] SimpleSolvers.jl as a nonlinear-solver backend for `solve`

### Differential geometry
- [ ] Equations whose unknowns live on manifolds: spheres, rotation groups, Stiefel and Grassmann manifolds (Manifolds.jl)
- [ ] Optimization on manifolds (Manopt.jl; GeometricOptimizers.jl for Stiefel and Grassmann)
- [ ] ODEs on Lie groups and homogeneous spaces: Lie group integrators, Runge–Kutta–Munthe-Kaas, Crouch–Grossman (LieGroups.jl)
- [ ] Geodesic equations: initial value (exponential map) and boundary value (logarithm map) problems
- [ ] Connections, parallel transport and curvature: Christoffel symbols and the Riemann tensor from a metric
- [ ] Hamiltonian mechanics on symplectic and Poisson manifolds: Poisson brackets, Casimirs, momentum maps
- [ ] Differential forms and exterior calculus; discrete exterior calculus for PDEs on meshes (CombinatorialSpaces.jl, Decapodes.jl)
- [ ] Geometric algebra (Grassmann.jl)
- [ ] Geometric PDEs: harmonic maps, minimal surfaces, mean curvature and Ricci flow, Einstein's field equations

### Plasma physics
The [JuliaPlasma](https://github.com/JuliaPlasma) packages build on the geometric integrators.
- [ ] Charged-particle and guiding-centre dynamics in electromagnetic fields (ChargedParticleDynamics.jl, ElectromagneticFields.jl)
- [ ] The Vlasov equation: particle, grid-based and reduced-basis methods (VlasovMethods.jl, ParticleMethods.jl)
- [ ] Particle-in-cell simulation (ParticleInCell.jl)
- [ ] The Poisson equation, spectral and B-spline Galerkin (PoissonSolvers.jl, SimpleSplines.jl)

### Integral and functional equations
- [ ] Fredholm and Volterra integral equations (quadrature from QuadratureRules.jl)
- [ ] Integro-differential equations
- [ ] Difference equations and recurrences, closed forms of linear recurrences
- [ ] Functional equations (`f(x + y) = f(x) f(y)`, …)

### Calculus of variations and control
- [ ] Euler–Lagrange equations from a functional (for mechanics: EulerLagrange.jl, below)
- [ ] Optimal control problems
- [ ] Hamilton–Jacobi–Bellman equations

### Logic and discrete
- [ ] Boolean equations and satisfiability (SAT)
- [ ] Constraint satisfaction over finite domains
- [ ] Graph equations: flows, matchings, shortest paths as optimality conditions

## Lean 4

Relations can be written as Lean 4 statements about the real numbers with Mathlib, and solutions
as theorems that Lean checks:

```julia
lean(Relation(:(x^2 + y^2 <= 1)))                      # "(x ^ 2 + y ^ 2 : ℝ) ≤ 1"
sys = EquationSystem(Relation(:(x + y == 3)), Relation(:(x - y == 1)))
print(lean_check(sys, (x=2, y=1)))
# theorem solution_check :
#     ((2 + 1 : ℝ) = 3) ∧ ((2 - 1 : ℝ) = 1) := by
#   norm_num
```

The `Lean` workflow builds theorems generated from the examples (`lean/`) against Mathlib.

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

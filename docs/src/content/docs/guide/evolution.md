---
title: Evolution equations
description: Initial value problems, Hamiltonian systems and geometric integrators.
---

## Evolution equations

`∂ₜ` (or `TimeDerivative()`) is the time derivative of the unknowns. `Equation(∂ₜ, f)` is the
evolution equation $\dot u = f(t, u)$, and `solve(equation, u0, (t0, t1); dt)` integrates it from
the initial values `u0` with time step `dt`:

```julia
julia> decay = Equation(∂ₜ, (t, u) -> -u)
∂ₜu = f(t, u)

julia> sol = solve(decay, 1.0, (0.0, 1.0); dt=0.1)
Trajectory (RungeKutta4, retcode: Success, 10 steps from t = 0.0 to 1.0)
u(1.0): 0.36787977441249836

julia> sol.u[end] - exp(-1)
3.332410560275001e-7
```

The result is a `Trajectory` with the times `t`, the states `u` (in the shape of `u0`: a number, a
vector or a `NamedTuple`), `retcode` and `alg`. If `dt` does not divide the time span, the built-in
integrators shorten the last step so the trajectory ends exactly at `t1`.

## Hamiltonian systems

`Equation(∂ₜ, Hamiltonian(H))` is Hamilton's equations $\dot q = \partial H/\partial p$,
$\dot p = -\partial H/\partial q$ for a Hamiltonian `H(t, q, p)`; the initial values are
`(q=q0, p=p0)`, numbers or vectors:

```julia
julia> oscillator = Equation(∂ₜ, Hamiltonian((t, q, p) -> p^2 / 2 + q^2 / 2))
∂ₜu = J∇H(q, p)

julia> solve(oscillator, (q=1.0, p=0.0), (0.0, 10.0); dt=0.1)
Trajectory (MidpointRule, retcode: Success, 100 steps from t = 0.0 to 10.0)
u(10.0): (q = -0.8435691506346454, p = 0.5370205658346019)
```

The gradients of `H` use finite differences by default; with ForwardDiff.jl loaded, pass
`ad=AutoForwardDiff()` for exact ones.

## Structure-preserving integration

The default integrator for Hamiltonian systems is the implicit midpoint rule, `MidpointRule()`,
which is symplectic: the energy error stays bounded over long times instead of drifting, as it
does with the classical Runge–Kutta method `RungeKutta4()`:

```julia
julia> energy(u) = u.p^2 / 2 + u.q^2 / 2;

julia> maximum(u -> abs(energy(u) - 0.5), solve(oscillator, (q=1.0, p=0.0), (0.0, 1000.0); dt=0.1).u)
1.2244074643064096e-9

julia> maximum(u -> abs(energy(u) - 0.5), solve(oscillator, (q=1.0, p=0.0), (0.0, 1000.0), RungeKutta4(); dt=0.1).u)
6.935284931708363e-5
```

Each midpoint step is itself an equation, solved with Equations.jl's own `NewtonMethod`
(`MidpointRule(newton=NewtonMethod(abstol=1e-12))` to tighten it).

## The problem

`solve(equation, u0, tspan; dt)` is short for `solve(InitialValueProblem(equation, u0, tspan; dt))`;
`vector_field(ivp)` gives the right-hand side as a function of the flat state vector (`[q; p]` for
Hamiltonian systems), for use with other integrators:

```julia
julia> ivp = InitialValueProblem(oscillator, (q=1.0, p=0.0), (0, 10); dt=0.1)
InitialValueProblem from t = 0.0 to 10.0 with dt = 0.1
  ∂ₜu = J∇H(q, p)
  u0 = (q = 1.0, p = 0.0)

julia> vector_field(ivp)(0.0, [1.0, 0.0])
2-element Vector{Float64}:
  0.0
 -0.9999999999914689
```

## GeometricIntegrators.jl

With [GeometricIntegrators.jl](https://github.com/JuliaGNI/GeometricIntegrators.jl) loaded, every
one of its integrators can be passed to `solve`: Gauss–Legendre Runge–Kutta methods, symplectic
partitioned methods, Lobatto IIIA–IIIB pairs, explicit tableaus and more. Hamiltonian systems are
handed to it as Hamiltonian ODEs, so its symplectic and variational methods apply, and other
equations as ODEs. GeometricIntegrators takes whole steps, so `dt` must divide the time span.

```julia
using Equations, GeometricIntegrators, ForwardDiff

kepler = Equation(∂ₜ, Hamiltonian((t, q, p) -> sum(abs2, p) / 2 - 1 / sqrt(sum(abs2, q))))
solve(kepler, (q=[1.0, 0.0], p=[0.0, 1.0]), (0.0, 2π), Gauss(2); dt=2π / 600, ad=AutoForwardDiff())
solve(kepler, (q=[1.0, 0.0], p=[0.0, 1.0]), (0.0, 2π), SymplecticEulerA(); dt=2π / 600, ad=AutoForwardDiff())
```

GeometricIntegrators exports its own `EquationProblem` and `Solution`; with both packages loaded,
write `Equations.EquationProblem` and `Equations.Solution` when you need those names.

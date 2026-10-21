# # A double pendulum from its Lagrangian
#
# Solve the Euler–Lagrange equations of GeometricProblems.jl's double pendulum with variational
# integrators, and derive them symbolically with EulerLagrange.jl.
#
# thumbnail: L = T − V,  d/dt ∂L/∂v = ∂L/∂q
# order: 22
#
# A double pendulum is the textbook chaotic system: two rods, the second hanging from the first.
# Its Lagrangian, kinetic minus potential energy, comes from
# [GeometricProblems.jl](https://github.com/JuliaGNI/GeometricProblems.jl), together with its
# parameters, initial values and Hamiltonian.

using Equations
using GeometricProblems: DoublePendulum

params = DoublePendulum.default_parameters()
L(t, q, v) = DoublePendulum.lagrangian(t, q, v, params)
pendulum = Equation(∂ₜ, Lagrangian(L))

# The unknowns are the two angles and their angular velocities, starting from GeometricProblems'
# initial values. `solve` uses the variational integrator `VariationalMidpoint`:

u0 = (q=DoublePendulum.θ₀, v=DoublePendulum.ω₀)
sol = solve(pendulum, u0, (0.0, 200.0); dt=0.02)

# ## Energy over a long time
#
# The motion is chaotic, so after a while the angles depend on every rounding error, but the
# energy must stay what it was. GeometricProblems gives the Hamiltonian, a function of the momenta
# `ϑ(t, q, v) = ∂L/∂v`:

energy(t, u) = DoublePendulum.hamiltonian(t, u.q, DoublePendulum.ϑ(t, u.q, u.v, params), params)
E0 = energy(0.0, (q=DoublePendulum.θ₀, v=DoublePendulum.ω₀))

# The largest energy error in each window of 50 time units shows whether it is bounded or drifts:

windows(sol) = [maximum(abs(energy(t, u) - E0) for (t, u) in zip(sol.t, sol.u) if a <= t <= a + 50)
                for a in 0:50:150]
windows(sol)

# The variational integrator's error oscillates but does not grow. It is of order 2, so a smaller
# step makes it smaller, by about 4 for half the step.
#
# ## Order 4: variational or not
#
# The variational partitioned Runge–Kutta methods of
# [GeometricIntegrators.jl](https://github.com/JuliaGNI/GeometricIntegrators.jl) take the same
# equation; Equations.jl hands it over as a Lagrangian ODE. With two Gauss stages the method is of
# order 4, like the classical Runge–Kutta method, which solves the Euler–Lagrange equations for the
# accelerations and is not variational. Same order, same step:

using GeometricIntegrators, ForwardDiff

vprk = solve(pendulum, u0, (0.0, 200.0), VPRKGauss(2); dt=0.02, ad=AutoForwardDiff())
rk4 = solve(pendulum, u0, (0.0, 200.0), RungeKutta4(); dt=0.02, ad=AutoForwardDiff())
(variational=windows(vprk), rk4=windows(rk4))

# The Runge–Kutta energy error grows window after window; the variational one does not grow, and
# is far smaller to begin with.
#
# ## The equations, symbolically
#
# [EulerLagrange.jl](https://github.com/JuliaGNI/EulerLagrange.jl) derives the Euler–Lagrange
# equations of the same Lagrangian symbolically (GeometricProblems builds the system with it).
# The momenta $\vartheta = \partial L/\partial v$, with $x$ the angles and the lengths and masses kept
# as symbols:

using EulerLagrange: equations

symbolic = equations(DoublePendulum.lagrangian_system(params))
ϑ = symbolic.ϑ

# and the mass matrix $M = \partial^2 L/\partial v^2$, which Equations.jl inverts numerically to find the
# accelerations:

M = symbolic.M

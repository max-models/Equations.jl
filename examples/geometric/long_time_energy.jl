# # Energy over a long time
#
# Why symplectic integrators: on a pendulum, the energy error of Runge–Kutta drifts while that of the midpoint rule stays bounded.
#
# thumbnail: H(q, p) = p²/2 − cos q
# order: 20
#
# The pendulum has the Hamiltonian $H(q, p) = p^2/2 - \cos q$. Its energy is conserved exactly, so
# the energy error of a numerical solution shows how well an integrator preserves the structure of
# the problem over a long time.

using Equations
using ForwardDiff

H(t, q, p) = p^2 / 2 - cos(q)
pendulum = Equation(∂ₜ, Hamiltonian(H))
u0 = (q=1.0, p=0.0)
energy(u) = H(0, u.q, u.p)
E0 = energy(u0);

# Integrate for 2000 time units, about 300 periods, with a coarse step and two integrators of
# different kinds: the explicit fourth-order Runge–Kutta method and the symplectic, second-order
# implicit midpoint rule. `AutoForwardDiff()` gives exact gradients of $H$.

tspan, dt = (0.0, 2000.0), 0.2
rk4 = solve(pendulum, u0, tspan, RungeKutta4(); dt, ad=AutoForwardDiff())
midpoint = solve(pendulum, u0, tspan, MidpointRule(); dt, ad=AutoForwardDiff());

# The largest energy error in each stretch of 400 time units: Runge–Kutta's grows steadily, while
# the midpoint rule's oscillates within the same band throughout, although the method is of lower
# order:

window_max(sol, t) = maximum(i -> abs(energy(sol.u[i]) - E0), findall(s -> t - 400 < s <= t, sol.t))
for t in 400:400:2000
    println("t ≤ ", rpad(t, 6), "RungeKutta4: ", rpad(round(window_max(rk4, t); sigdigits=3), 12),
        "MidpointRule: ", round(window_max(midpoint, t); sigdigits=3))
end

# ## With GeometricIntegrators.jl
#
# GeometricIntegrators.jl has many more structure-preserving methods. Gauss–Legendre Runge–Kutta
# methods are symplectic and of high order (`Gauss(1)` is the midpoint rule); the symplectic Euler
# methods are of first order, but explicit for separable Hamiltonians like this one. All the
# symplectic methods keep a bounded error; only `RK4` drifts:

using GeometricIntegrators

for (name, method) in ("Gauss(1)" => Gauss(1), "Gauss(2)" => Gauss(2), "SymplecticEulerA" => SymplecticEulerA(), "RK4" => RK4())
    sol = solve(pendulum, u0, tspan, method; dt, ad=AutoForwardDiff())
    println(rpad(name, 18), "max |energy error| = ",
        round(maximum(u -> abs(energy(u) - E0), sol.u); sigdigits=3))
end

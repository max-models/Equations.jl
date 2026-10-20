# # Kepler orbits
#
# An eccentric planetary orbit over many periods: energy, angular momentum and the precession of the orbit.
#
# thumbnail: H = |p|²/2 − 1/|q|
# order: 21
#
# A planet around a star of unit mass follows Hamilton's equations for
#
# $$
# H(q, p) = \frac{|p|^2}{2} - \frac{1}{|q|},
# $$
#
# which conserve the energy $H$ and the angular momentum $L = q_1 p_2 - q_2 p_1$. Starting at
# $q = (1 - e, 0)$ with the right speed gives an ellipse of eccentricity $e$ and period $2\pi$.

using Equations
using ForwardDiff
using GeometricIntegrators

kepler = Equation(∂ₜ, Hamiltonian((t, q, p) -> sum(abs2, p) / 2 - 1 / sqrt(sum(abs2, q))))
e = 0.6
u0 = (q=[1 - e, 0.0], p=[0.0, sqrt((1 + e) / (1 - e))])
H(u) = sum(abs2, u.p) / 2 - 1 / sqrt(sum(abs2, u.q))
L(u) = u.q[1] * u.p[2] - u.q[2] * u.p[1];

# Fifty periods with 200 steps per period. GeometricIntegrators takes whole steps, so the step
# divides the time span:

periods = 50
tspan, dt = (0.0, periods * 2π), 2π / 200
results = Dict(
    "RK4 (explicit)" => solve(kepler, u0, tspan, RK4(); dt, ad=AutoForwardDiff()),
    "Gauss(2) (symplectic)" => solve(kepler, u0, tspan, Gauss(2); dt, ad=AutoForwardDiff()),
);

# Both methods have order 4, but only the Gauss–Legendre method is symplectic. Its energy error
# stays bounded and it conserves the angular momentum, a quadratic invariant, to round-off; the
# explicit method's errors in both grow with time:

for (name, sol) in sort(collect(results); by=first)
    println(rpad(name, 23), "max |ΔH| = ", rpad(round(maximum(u -> abs(H(u) - H(u0)), sol.u); sigdigits=3), 10),
        " max |ΔL| = ", round(maximum(u -> abs(L(u) - L(u0)), sol.u); sigdigits=3))
end

# ## Precession
#
# A numerical orbit closes only approximately, so the ellipse slowly turns. The direction of the
# perihelion (the point closest to the star) after the last period shows how far:

for (name, sol) in sort(collect(results); by=first)
    last_period = sol.u[end-200:end]
    perihelion = argmin(u -> sum(abs2, u.q), last_period).q
    println(rpad(name, 23), "perihelion angle after $periods periods: ",
        round(rad2deg(atan(perihelion[2], perihelion[1])); digits=4), "°")
end

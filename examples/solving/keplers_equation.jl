# # Kepler's equation
#
# Find where a planet is on its orbit, comparing finite differences, ForwardDiff.jl and NonlinearSolve.jl.
#
# thumbnail: E − e sin E = M
# order: 6
#
# A body on an elliptic orbit with eccentricity $e$ is at eccentric anomaly $E$ at mean anomaly
# $M$, where
#
# $$
# E - e \sin E = M .
# $$
#
# There is no closed form for $E(M)$, so it is solved numerically.

using Equations
using ForwardDiff
using NonlinearSolve

kepler(e, M) = Equation(E -> E - e * sin(E), M)

e, M = 0.6, 1.0
eq = kepler(e, M)

# The default Newton method differentiates with finite differences. Starting from $E_0 = M$:

fd = solve(eq, M)

# With ForwardDiff.jl loaded, the derivatives can be exact instead. Newton's method forgives small
# errors in the derivative, so here both reach the same answer in the same number of steps:

ad = solve(eq, M, NewtonMethod(ad=AutoForwardDiff()))

# And with NonlinearSolve.jl loaded, any of its algorithms solves the same equation and returns the
# same kind of `Solution`:

tr = solve(eq, M, TrustRegion())

# All three agree, and the default tolerance of `NewtonMethod` is a residual of $10^{-10}$:

fd.u ≈ ad.u ≈ tr.u, issatisfied(eq, ad.u; atol=1e-10)

# Or with Roots.jl: its bracketing methods converge from a bracket like bisection does, but in far
# fewer steps. $E$ lies in $[0, 2\pi]$:

using Roots

br = solve(eq, (0, 2π), Roots.Brent())
bi = solve(eq, (0, 2π))
br.u ≈ bi.u, br.iterations, bi.iterations

# ## A whole orbit
#
# Solving for many mean anomalies traces the orbit; the position in the orbital plane follows from
# $E$:

for M in range(0, 2π; length=9)
    E = solve(kepler(e, M), M, NewtonMethod(ad=AutoForwardDiff())).u
    x, y = cos(E) - e, sqrt(1 - e^2) * sin(E)
    println("M = ", rpad(round(M; digits=3), 6), "  E = ", rpad(round(E; digits=4), 7),
        "  position = (", round(x; digits=3), ", ", round(y; digits=3), ")")
end

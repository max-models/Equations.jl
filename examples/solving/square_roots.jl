# # Square roots by Newton's method
#
# Solve a scalar equation with the built-in Newton method and watch it converge.
#
# thumbnail: x² = 2
# order: 3
#
# `solve` takes an equation and a starting point and returns a `Solution`.

using Equations

sol = solve(Equation(x -> x^2, 2), 1.0)

#

sol.u - sqrt(2)

# Newton's method converges quadratically: the number of correct digits roughly doubles per step.
# Capping the iterations shows it.

for n in 0:5
    s = solve(Equation(x -> x^2, 2), 1.0, NewtonMethod(maxiters=n))
    println(rpad("$n iterations:", 15), s.u, "   error ", abs(s.u - sqrt(2)))
end

# The same works for any root:

[solve(Equation(x -> x^k, 10), 1.0).u for k in 2:5] ≈ [10^(1 / k) for k in 2:5]

# Without a real root the method does not converge, and the return code says so:

solve(Equation(x -> x^2, -1), 1.0, NewtonMethod(maxiters=20)).retcode

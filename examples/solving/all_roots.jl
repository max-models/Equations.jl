# # All the roots
#
# Every root in an interval, every complex root of a polynomial, and every solution of a polynomial system.
#
# thumbnail: x³ = 8 → 3 roots
# order: 7
#
# `AllRoots()` asks `solve` for all solutions instead of one. `sol.u` is then a vector of
# solutions, each in the shape of the starting values.

using Equations

# ## In an interval
#
# On a bracket, `AllRoots` samples the equation and bisects every sign change. The line $x/10$
# crosses $\sin x$ seven times:

sol = solve(Equation(sin, x -> x / 10), (-10, 10), AllRoots())
round.(sol.u; digits=6)

# Sampling misses roots where the function touches zero without changing sign, such as the double
# root of $(x - 1/3)^2$, unless one happens to fall on a sample point:

solve(Equation(x -> (x - 1/3)^2, 0), (0, 2), AllRoots()).u

# ## Polynomials
#
# With Polynomials.jl loaded, an equation between polynomials has all its complex roots computed
# directly, without starting values:

using Polynomials

p = Polynomial([-6, 11, -6, 1])          # (x - 1)(x - 2)(x - 3)
solve(Equation(p, 0), AllRoots()).u

#

solve(Equation(Polynomial([1, 0, 1]), 0), AllRoots()).u   # x² + 1 = 0

# ## Polynomial systems
#
# With HomotopyContinuation.jl loaded, a system of polynomial equations written as ordinary Julia
# functions is solved completely by homotopy continuation. The starting values only name the
# unknowns. HomotopyContinuation exports its own `solve`, so the one of Equations is qualified:

using HomotopyContinuation

circle_and_parabola = EquationSystem(
    Equation(u -> u.x^2 + u.y^2, 4),
    Equation(u -> u.y, u -> u.x^2 - 2),
)
sol = Equations.solve(circle_and_parabola, (x=0.0, y=0.0), AllRoots(real=true))
[(round(s.x; digits=4), round(s.y; digits=4)) for s in sol.u]

# A scalar polynomial written as a function works the same way; complex roots included:

Equations.solve(Equation(x -> x^3, 8), 0.0, AllRoots()).u

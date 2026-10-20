# # One solve for every problem
#
# Scalars, vectors, named unknowns, brackets and linear systems: the same solve picks a suitable algorithm for each.
#
# thumbnail: solve(eq, u0)
# order: 4
#
# The starting values tell `solve` what the unknowns are, and the structure of the equations tells
# it how to solve them. `default_algorithm` shows the choice; `sol.alg` records it.

using Equations

# ## A scalar unknown
#
# A number as the starting value: Newton's method.

sol = solve(Equation(x -> exp(x), 3), 1.0)
sol.u, sol.alg

# ## A bracket
#
# A tuple `(a, b)` between which the equation changes sign: bisection, which cannot fail. Here, the
# root of a polynomial with roots 1, 2, 3 and 4 in $[2.6, 3.7]$:

p(x) = (x - 1) * (x - 2) * (x - 3) * (x - 4)
sol = solve(Equation(p, 0), (2.6, 3.7))
sol.u, sol.iterations

# ## Named unknowns
#
# A `NamedTuple` names the unknowns. A rectangle with area 12 and perimeter 14:

rectangle = EquationSystem(
    Equation(u -> u.width * u.height, 12),
    Equation(u -> 2u.width + 2u.height, 14),
)
solve(rectangle, (width=5.0, height=1.0)).u

# ## A linear system
#
# `Linear(A)` marks the map $x \mapsto Ax$. A system of only linear maps and constants is solved
# directly, in one step. The currents in three meshes of a resistor network, from Kirchhoff's
# voltage law:

R = [ 7.0 -2.0  0.0
     -2.0  9.0 -3.0
      0.0 -3.0  8.0]
V = [10.0, 0.0, -5.0]
currents = solve(Equation(Linear(R), V), zeros(3))

#

R * currents.u ≈ V

# ## The choice, before solving
#
# `EquationProblem` is what `solve(relations, u0)` builds; `default_algorithm` shows what it will
# pick, and any algorithm can be passed instead:

for u0 in (1.0, (0.0, 2.0))
    prob = EquationProblem(Equation(x -> x^3 - 2, 0), u0)
    println(rpad(repr(u0), 12), "→ ", default_algorithm(prob))
end

#

solve(Equation(x -> x^3 - 2, 0), (0.0, 2.0), Bisection(abstol=1e-3)).u

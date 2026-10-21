# # A point in a feasible region
#
# Find points that satisfy a system of nonlinear inequalities, strict ones included.
#
# thumbnail: x² + 4y² ≤ 4, y ≥ x² − 1
# order: 12
#
# The region below is the part of the ellipse $x^2 + 4y^2 \le 4$ that lies above the parabola
# $y = x^2 - 1$ and to the right of the line $x + y = 1$. A system of inequalities is solved by
# finding a point in it.

using Equations

region = EquationSystem(
    Relation(<=, u -> u.x^2 + 4u.y^2, 4),
    Relation(>=, u -> u.y, u -> u.x^2 - 1),
    Relation(>=, u -> u.x + u.y, 1),
)

# `solve` picks the `Feasibility` algorithm for a system with inequalities. From a start far
# outside, it walks to the edge of the region:

sol = solve(region, (x=-3.0, y=3.0))

#

issatisfied(region, sol.u; atol=1e-10)

# A start inside the region is already a solution, and comes back unchanged:

solve(region, (x=1.0, y=0.5)).u

# ## Strict inequalities
#
# A strict inequality must hold strictly. Asking for a point strictly above the line, the steps
# aim a small margin inside:

strictly = EquationSystem(region[1], region[2], Relation(>, u -> u.x + u.y, 1))
point = solve(strictly, (x=-3.0, y=3.0)).u

#

point.x + point.y > 1

# ## Equations in the same system
#
# Equations and inequalities mix: the points of the region on the circle $x^2 + y^2 = 1.2$.

on_circle = EquationSystem(region..., Equation(u -> u.x^2 + u.y^2, 1.2))
sol = solve(on_circle, (x=1.0, y=0.0))

#

issatisfied(on_circle, sol.u; atol=1e-10)

# ## No solution
#
# Ask for a point of the region below the parabola's vertex, and there is none: the violation of
# the relations cannot be reduced to zero, and the retcode says so.

empty = EquationSystem(region..., Relation(<=, u -> u.y, -1.5))
solve(empty, (x=0.0, y=0.0))

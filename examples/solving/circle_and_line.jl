# # Intersecting a circle and a line
#
# Solve a system of two nonlinear equations; different starting points find different solutions.
#
# thumbnail: x² + y² = 1, y = x/2
# order: 5
#
# The circle $x^2 + y^2 = 1$ meets the line $y = x/2$ in two points,
# $\pm(2, 1)/\sqrt{5}$.

using Equations

sys = EquationSystem(
    Equation(p -> p[1]^2 + p[2]^2, 1),
    Equation(p -> p[2], p -> p[1] / 2),
)

#

right = solve(sys, [1.0, 0.0])

#

left = solve(sys, [-1.0, 0.0])

#

right.u ≈ [2, 1] / sqrt(5), left.u ≈ -[2, 1] / sqrt(5)

# Inequalities can sit in the same system, as conditions on the solution: they hold for one of
# the two intersections only.

conditions = EquationSystem(sys..., Relation(>=, p -> p[1], 0))
issatisfied(conditions, right.u; atol=1e-10), issatisfied(conditions, left.u; atol=1e-10)

# `solve` on the whole system looks for a point that satisfies all three relations, with the
# `Feasibility` algorithm:

solve(conditions, [0.0, 1.0])

# It is a local method. From the start that led to the left intersection before, it stops where
# the violation of the relations cannot be reduced any further, and says so:

solve(conditions, [-1.0, 0.0])

# ## Overdetermined systems
#
# With more equations than unknowns, Newton's method takes Gauss–Newton steps, which find the
# solution of a consistent system:

over = EquationSystem(
    Equation(p -> p[1] + p[2], 3),
    Equation(p -> p[1] - p[2], 1),
    Equation(p -> 2p[1] + p[2], 5),
)
solve(over, [0.0, 0.0]).u

# # Minimizing under constraints
#
# Minimize and maximize subject to equations and inequalities: a can of least metal, and the
# workshop's linear program in one call.
#
# thumbnail: min 2πr² + 2πrh  s.t.  πr²h = 330
# order: 13
#
# ## The can of least metal
#
# A can of 330 ml (330 cm³) with radius $r$ and height $h$ takes $2\pi r^2 + 2\pi r h$ of metal.
# Minimize that, with the volume $\pi r^2 h = 330$ as an equation:

using Equations

volume = Equation(u -> π * u.r^2 * u.h, 330)
can = minimize(u -> 2π * u.r^2 + 2π * u.r * u.h, (r=3.0, h=10.0); subject_to=volume)

# Calculus gives the answer: the height equals the diameter, $h = 2r$, with
# $r = (330 / 2\pi)^{1/3}$.

r = cbrt(330 / 2π)
isapprox(can.u.r, r; rtol=1e-6), isapprox(can.u.h, 2r; rtol=1e-6)

# Real cans are taller, since they must fit a hand. Add the inequality $r \le 3$ cm and the
# optimum moves onto it:

slim = minimize(u -> 2π * u.r^2 + 2π * u.r * u.h, (r=3.0, h=10.0);
                subject_to=[volume, Relation(<=, u -> u.r, 3)])

#

slim.objective - can.objective   # the extra metal, in cm²

# ## Maximizing
#
# `maximize` is the same with the sign turned: the largest rectangle with a perimeter of 20 is the
# square.

maximize(u -> u.w * u.h, (w=1.0, h=1.0); subject_to=Equation(u -> 2u.w + 2u.h, 20)).u

# ## The workshop's linear program, with a JuMP optimizer
#
# The [linear program example](/Equations.jl/examples/linear-program/) builds a JuMP model by
# hand. With `JuMPSolver`, the same problem is one call: the unknowns become JuMP variables, and
# HiGHS solves the linear program exactly.

using JuMP, HiGHS

plan = maximize(u -> 3u.x + 2u.y, (x=0.0, y=0.0), JuMPSolver(HiGHS.Optimizer);
                subject_to=[Relation(<=, u -> u.x + u.y, 4), Relation(<=, u -> 3u.x + u.y, 10),
                            Relation(>=, u -> u.y, u -> u.x / 2),
                            Relation(>=, u -> u.x, 0), Relation(>=, u -> u.y, 0)])

# The built-in augmented Lagrangian method finds the same plan, to its tolerance:

approx = maximize(u -> 3u.x + 2u.y, (x=0.0, y=0.0);
                  subject_to=[Relation(<=, u -> u.x + u.y, 4), Relation(<=, u -> 3u.x + u.y, 10),
                              Relation(>=, u -> u.y, u -> u.x / 2),
                              Relation(>=, u -> u.x, 0), Relation(>=, u -> u.y, 0)])
isapprox(approx.objective, plan.objective; rtol=1e-6)

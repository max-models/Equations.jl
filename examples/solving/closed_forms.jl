# # Closed-form solutions
#
# Exact answers instead of numbers: square roots, logarithms and solutions of polynomial systems.
#
# thumbnail: x² = 2 → ±√2
# order: 9
#
# `ClosedForm()` asks for the solutions in closed form, through Symbolics.jl's `symbolic_solve`.
# Polynomial equations need Nemo.jl and systems Groebner.jl as well. Both export their own `solve`,
# so they are loaded with `import`.

using Equations
using Symbolics
import Nemo, Groebner

# ## Symbolic equations
#
# With Symbolics variables as the unknowns. Symbolics exports its own `Equation`, so the one of
# Equations is qualified:

@variables x y
sol = solve(Equations.Equation(x^2, 2), x, ClosedForm())
sol.u

# The answers are exact; `symbolic_to_float` gives their values:

Symbolics.symbolic_to_float.(sol.u)

# Transcendental equations too; `slog` is Symbolics' logarithm, guarded against negative arguments:

solve(Equations.Equation(exp(x), 3), x, ClosedForm()).u

# A cubic:

solve(Equations.Equation(x^3 - 2x, 0), x, ClosedForm()).u

# ## Systems
#
# A system gives one dictionary per solution, here a linear system and the intersections of a
# circle with a line:

solve(EquationSystem(Equations.Equation(x + y, 3), Equations.Equation(x - y, 1)), [x, y], ClosedForm()).u

#

solve(EquationSystem(Equations.Equation(x^2 + y^2, 1), Equations.Equation(y, x)), [x, y], ClosedForm()).u

# ## Functions as sides
#
# Equations written with ordinary functions work too: they are evaluated on symbolic variables named
# after the unknowns, so the starting values only name them.

rectangle = EquationSystem(
    Equations.Equation(u -> u.width * u.height, 12),
    Equations.Equation(u -> 2u.width + 2u.height, 14),
)
solve(rectangle, (width=0.0, height=0.0), ClosedForm()).u

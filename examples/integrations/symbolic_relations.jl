# # Symbolic relations
#
# Relations between Symbolics.jl expressions: substitute values, canonicalize, convert both ways.
#
# thumbnail: x² + y ≲ 1
# order: 7
#
# Symbolics.jl also exports `Equation` and `Inequality`, so with both packages loaded those two
# names are qualified as `Equations.Equation` and `Equations.Inequality`.

using Equations
using Symbolics

@variables x y

r = Relation(<=, x^2 + y, 1)

# A dictionary of values substitutes the variables:

issatisfied(r, Dict(x => 0.5, y => 0.5)), issatisfied(r, Dict(x => 1.0, y => 0.5))

# Manipulations act on the expressions:

canonicalize(r)

#

-2r

# ## Converting
#
# Relations convert to Symbolics' equations and inequalities, and back:

eq = Symbolics.Equation(Equations.Equation(x^2, 2))

#

Relation(eq)

#

Relation(x ≳ y)

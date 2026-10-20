# # First relations
#
# Build equations and inequalities between numbers, arrays and functions, and check them.
#
# thumbnail: x² + y² ≤ 1
# order: 1
#
# A relation keeps its two sides and a comparison; nothing is compared until you ask.

using Equations

# The sides can be plain values,

r = Relation(<=, 1, 2)

# and the comparison is a singleton type:

comparison(r), isinequality(r)

# `@relation` reads ordinary comparison syntax without evaluating the comparison:

a, b = 3, 4
pythagoras = @relation a^2 + b^2 == 5^2

#

issatisfied(pythagoras)

# ## Functions as sides
#
# A function side is evaluated at the point you pass. Here is the unit disk $x^2 + y^2 \le 1$:

disk = Relation(<=, x -> x[1]^2 + x[2]^2, 1)

#

points = ([0.0, 0.0], [0.6, 0.6], [0.8, 0.6], [1.0, 1.0])
for p in points
    println(p, " => ", issatisfied(disk, p), " (residual ", residual(disk, p), ")")
end

# Floating-point equations need a tolerance; `atol` bounds the residual:

trig = Equation(x -> sin(x)^2 + cos(x)^2, 1)
issatisfied(trig, 0.7), issatisfied(trig, 0.7; atol=1e-12)

# ## Arrays
#
# Array sides hold elementwise:

issatisfied(Relation(<=, [1, 2, 3], [3, 2, 1]))

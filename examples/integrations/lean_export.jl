# # Proofs in Lean 4
#
# Turn equations, inequalities and their solutions into Lean 4 theorems about the real numbers.
#
# thumbnail: theorem … := by norm_num
# order: 15
#
# Numbers from a solver are evidence; a theorem checked by [Lean](https://lean-lang.org) is proof.
# Equations.jl writes relations as Lean 4 statements about real numbers with Mathlib, leaving the
# proof as `sorry` or filling it in where `norm_num` can do it.

using Equations

# ## Solve, then state the solution
#
# A rectangle with area 12 and perimeter 14, solved numerically:

rectangle = EquationSystem(Equation(u -> u.w * u.h, 12), Equation(u -> 2u.w + 2u.h, 14))
sol = solve(rectangle, (w=5.0, h=1.0))
sol.u

# The same equations as expressions, which Lean can read, and the rounded solution as a theorem
# that `norm_num` proves:

equations = EquationSystem(Relation(:(w * h == 12)), Relation(:(2w + 2h == 14)))
print(lean_check(equations, map(round, sol.u); name="rectangle"))

# ## Statements with variables
#
# With variables, the relations become hypotheses and conclusions. The intersection of the unit
# circle with the line $y = x/2$, from the examples, as a theorem left for Lean to prove:

print(lean_theorem(Relation(:(x^2 + y^2 == 1)); name="circle_and_line",
    hypotheses=[Relation(:(y == x / 2)), Relation(:(5x^2 == 4))]))

# Functions, constants and real exponents are translated to Mathlib's:

print(lean_theorem(Relation(:(exp(-t / 2) * sqrt(x) <= x^(1//2) + π)); name="bound",
    hypotheses=[Relation(:(t >= 0)), Relation(:(x >= 0))]))

# ## A Lean file
#
# `lean_file` collects theorems into a source file that imports Mathlib; `write` it into a Lean
# project and build it with `lake build`:

file = lean_file(
    lean_check(equations, (w=4, h=3); name="rectangle_4_3"),
    lean_check(equations, (w=3, h=4); name="rectangle_3_4"),
)
print(file)

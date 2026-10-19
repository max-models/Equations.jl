# # Manipulating relations
#
# Do algebra on both sides at once: inequalities flip where they must, and relations add up.
#
# thumbnail: a ≤ b ⟹ −2a ≥ −2b
# order: 2
#
# Arithmetic with a number applies to both sides. Multiplying or dividing an inequality by a
# negative number reverses it, exactly as on paper.

using Equations

r = Relation(<, 2, 5)

#

r + 1, 3r, r / -1, -r

# `reverse` swaps the sides without changing the meaning:

reverse(r)

# Multiplying an inequality by zero would lose the information, so it is refused:

try
    0 * r
catch err
    println(sprint(showerror, err))
end

# ## Adding relations
#
# Two relations add side by side. The result is strict as soon as one of them is, and
# inequalities pointing in opposite directions are reversed first:

Relation(<=, 1, 2) + Relation(<, 10, 20)

#

Relation(<=, 1, 2) + Relation(>=, 20, 10)

# This is enough for small proofs. From $a \le b$ and $c \le d$ follows $a + c \le b + d$; with
# function sides the derived relation can be checked at any point:

a_le_b = Relation(<=, x -> x^2, x -> x^2 + 1)
c_le_d = Relation(<=, x -> sin(x), 1)
sum_relation = a_le_b + c_le_d
all(issatisfied(sum_relation, x) for x in range(-5, 5; length=101))

# ## Canonical form
#
# Optimizers want constraints as $g(x) \le 0$ and $h(x) = 0$. `canonicalize` moves everything to
# the left-hand side and turns `≥` into `≤`:

canonicalize(Relation(>=, 1, 3))

#

g = canonicalize(Relation(>=, x -> x^2, 4))
g.lhs(1.0), g.lhs(3.0)

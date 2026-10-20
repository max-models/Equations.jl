module EquationsPolynomialsExt

using Equations: Equations, Relation, EqualTo
using Polynomials: AbstractPolynomial, roots

# A polynomial side is a function of the unknown, not a constant.
Equations.evaluate(p::AbstractPolynomial, x) = p(x)

Equations._polynomial_roots(r::Relation{EqualTo,<:AbstractPolynomial,<:Union{Number,AbstractPolynomial}}) =
    roots(r.lhs - r.rhs)
Equations._polynomial_roots(r::Relation{EqualTo,<:Number,<:AbstractPolynomial}) = roots(r.rhs - r.lhs)

end

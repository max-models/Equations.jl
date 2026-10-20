"""
    evaluate(side, x)

Evaluate one side of a relation at the point `x`. Functions are called,
anything else is treated as a constant. Packages can add methods for their own
types (the Symbolics extension does this for symbolic expressions).
"""
evaluate(f::Function, x) = f(x)
evaluate(c, x) = c

# Apply `f` elementwise to one or two sides, deferring the computation when a side is a function.
_apply(f, a) = a isa Function ? (x -> f.(evaluate(a, x))) : f.(a)
_apply(f, a, b) =
    a isa Function || b isa Function ? (x -> f.(evaluate(a, x), evaluate(b, x))) : f.(a, b)

"""
    residual(r::Relation)
    residual(r::Relation, x)

`lhs - rhs`, computed elementwise. The second form first evaluates function
sides at `x` (see [`evaluate`](@ref Equations.evaluate)).
"""
residual(r::Relation) = r.lhs .- r.rhs
residual(r::Relation, x) = evaluate(r.lhs, x) .- evaluate(r.rhs, x)

"""
    issatisfied(r::Relation; atol=0)
    issatisfied(r::Relation, x; atol=0)

Whether the relation holds, up to the absolute tolerance `atol` on the
[`residual`](@ref). For array-valued sides the relation must hold elementwise.
Equations hold when `|lhs - rhs| ≤ atol`; `lhs ≤ rhs` holds when
`lhs - rhs ≤ atol`, and similarly for the other comparisons.
"""
issatisfied(r::Relation; atol::Real=0) = _holds(comparison(r), residual(r), atol)
issatisfied(r::Relation, x; atol::Real=0) = _holds(comparison(r), residual(r, x), atol)

_holds(c::Comparison, d::AbstractArray, atol) = all(di -> _holds_scalar(c, di, atol), d)
_holds(c::Comparison, d, atol) = _holds_scalar(c, d, atol)

_holds_scalar(::EqualTo, d, atol) = abs(d) <= atol
_holds_scalar(::NotEqualTo, d, atol) = abs(d) > atol
_holds_scalar(::LessThan, d, atol) = d < atol
_holds_scalar(::LessEqual, d, atol) = d <= atol
_holds_scalar(::GreaterThan, d, atol) = d > -atol
_holds_scalar(::GreaterEqual, d, atol) = d >= -atol

"""
    reverse(r::Relation)

Swap the two sides of `r`, flipping the comparison: `reverse(a ≤ b) == (b ≥ a)`.
"""
Base.reverse(r::Relation) = Relation(flip(comparison(r)), r.rhs, r.lhs)

"""
    canonicalize(r::Relation)

Rewrite `r` with zero on the right-hand side, in the form optimizers expect:
equations become `g = 0`, `≤`/`<` stay `g ≤ 0`/`g < 0` and `≥`/`>` become
`g ≤ 0`/`g < 0` with `g = rhs - lhs`.
"""
canonicalize(r::Relation{<:Union{EqualTo,NotEqualTo,LessThan,LessEqual}}) =
    Relation(comparison(r), _apply(-, r.lhs, r.rhs), 0)
canonicalize(r::Relation{<:Union{GreaterThan,GreaterEqual}}) = canonicalize(reverse(r))

# Arithmetic: applying the same operation to both sides.

Base.:-(r::Relation) = Relation(flip(comparison(r)), _apply(-, r.lhs), _apply(-, r.rhs))

Base.:+(r::Relation, c) = Relation(comparison(r), _apply(+, r.lhs, c), _apply(+, r.rhs, c))
Base.:+(c, r::Relation) = Relation(comparison(r), _apply(+, c, r.lhs), _apply(+, c, r.rhs))
Base.:-(r::Relation, c) = Relation(comparison(r), _apply(-, r.lhs, c), _apply(-, r.rhs, c))
Base.:-(c, r::Relation) = c + (-r)

"""
    a::Relation + b::Relation

Add two relations side by side: `(a₁ ≤ a₂) + (b₁ < b₂) == (a₁ + b₁ < a₂ + b₂)`.
Equations can be added to anything except `≠`; inequalities pointing in
opposite directions are reversed first.
"""
function Base.:+(a::Relation, b::Relation)
    ca, cb = comparison(a), comparison(b)
    c = _combine(ca, cb)
    if c === nothing && ca isa InequalityComparison && cb isa InequalityComparison
        b = reverse(b)
        c = _combine(ca, comparison(b))
    end
    c === nothing && throw(ArgumentError("cannot add relations with comparisons $ca and $cb"))
    return Relation(c, _apply(+, a.lhs, b.lhs), _apply(+, a.rhs, b.rhs))
end
Base.:-(a::Relation, b::Relation) = a + (-b)

_combine(::Comparison, ::Comparison) = nothing
_combine(::EqualTo, ::EqualTo) = EqualTo()
_combine(::EqualTo, c::InequalityComparison) = c
_combine(c::InequalityComparison, ::EqualTo) = c
_combine(::LessEqual, ::LessEqual) = LessEqual()
_combine(::Union{LessThan,LessEqual}, ::Union{LessThan,LessEqual}) = LessThan()
_combine(::GreaterEqual, ::GreaterEqual) = GreaterEqual()
_combine(::Union{GreaterThan,GreaterEqual}, ::Union{GreaterThan,GreaterEqual}) = GreaterThan()

"""
    r::Relation * c
    c * r::Relation
    r::Relation / c

Multiply (divide) both sides by the number `c`. Inequalities are flipped when
`c < 0`. Dividing by zero, or multiplying an inequality or `≠` by zero, throws
a `DomainError`.
"""
Base.:*(r::Relation, c::Number) = _scale(r, c, *)
Base.:*(c::Number, r::Relation) = _scale(r, c, *)
Base.:/(r::Relation, c::Number) = _scale(r, c, /)

function _scale(r::Relation, c, op)
    cmp = comparison(r)
    if iszero(c) && (op === (/) || !(cmp isa EqualTo))
        throw(DomainError(c, "cannot $(op === (/) ? "divide" : "multiply") a relation with comparison $cmp by zero"))
    end
    cmp isa InequalityComparison && c < 0 && (cmp = flip(cmp))
    return Relation(cmp, _apply(x -> op(x, c), r.lhs), _apply(x -> op(x, c), r.rhs))
end

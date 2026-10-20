"""
    Comparison

Abstract supertype of the singleton tags that identify the comparison of a
[`Relation`](@ref): [`EqualTo`](@ref), [`NotEqualTo`](@ref), [`LessThan`](@ref),
[`LessEqual`](@ref), [`GreaterThan`](@ref) and [`GreaterEqual`](@ref).
"""
abstract type Comparison end

"Comparison tag for `lhs = rhs`."
struct EqualTo <: Comparison end
"Comparison tag for `lhs ≠ rhs`."
struct NotEqualTo <: Comparison end
"Comparison tag for `lhs < rhs`."
struct LessThan <: Comparison end
"Comparison tag for `lhs ≤ rhs`."
struct LessEqual <: Comparison end
"Comparison tag for `lhs > rhs`."
struct GreaterThan <: Comparison end
"Comparison tag for `lhs ≥ rhs`."
struct GreaterEqual <: Comparison end

const InequalityComparison = Union{LessThan,LessEqual,GreaterThan,GreaterEqual}

"""
    comparison(op)
    comparison(r::Relation)

Return the [`Comparison`](@ref) tag corresponding to the Base comparison
function `op` (`==`, `!=`, `<`, `<=`, `>`, `>=`), or the comparison of the
relation `r`.
"""
comparison(c::Comparison) = c
comparison(::typeof(==)) = EqualTo()
comparison(::typeof(!=)) = NotEqualTo()
comparison(::typeof(<)) = LessThan()
comparison(::typeof(<=)) = LessEqual()
comparison(::typeof(>)) = GreaterThan()
comparison(::typeof(>=)) = GreaterEqual()

"""
    basefunction(c::Comparison)

The Base comparison function corresponding to `c`, e.g. `basefunction(LessEqual()) === (<=)`.
"""
basefunction(::EqualTo) = (==)
basefunction(::NotEqualTo) = (!=)
basefunction(::LessThan) = (<)
basefunction(::LessEqual) = (<=)
basefunction(::GreaterThan) = (>)
basefunction(::GreaterEqual) = (>=)

"""
    flip(c::Comparison)

The comparison obtained by swapping both sides, e.g. `flip(LessThan()) == GreaterThan()`.
"""
flip(c::Union{EqualTo,NotEqualTo}) = c
flip(::LessThan) = GreaterThan()
flip(::LessEqual) = GreaterEqual()
flip(::GreaterThan) = LessThan()
flip(::GreaterEqual) = LessEqual()

"""
    AbstractRelation

Abstract supertype for relations between a left-hand side and a right-hand side.
"""
abstract type AbstractRelation end

"""
    Relation{C<:Comparison}(lhs, rhs)
    Relation(op, lhs, rhs)

The relation `lhs op rhs`, where `op` is one of `==`, `!=`, `<`, `<=`, `>`, `>=`
(or the corresponding [`Comparison`](@ref) tag).

The two sides can be anything that supports subtraction: numbers, arrays,
symbolic expressions, JuMP expressions, … A side can also be a `Function`, in
which case it is evaluated at a point `x` by [`residual(r, x)`](@ref residual)
and [`issatisfied(r, x)`](@ref issatisfied).

# Examples
```jldoctest
julia> r = Relation(<=, x -> x^2, 4)
f(x) ≤ 4

julia> issatisfied(r, 1.5)
true

julia> Equation(2 + 2, 4) |> issatisfied
true
```
"""
struct Relation{C<:Comparison,L,R} <: AbstractRelation
    lhs::L
    rhs::R
end

Relation{C}(lhs::L, rhs::R) where {C<:Comparison,L,R} = Relation{C,L,R}(lhs, rhs)
Relation(op, lhs, rhs) = Relation{typeof(comparison(op))}(lhs, rhs)

"""
    Equation(lhs, rhs)

The equation `lhs = rhs`; an alias for `Relation{EqualTo}`.
"""
const Equation = Relation{EqualTo}

"""
    Inequality

Any [`Relation`](@ref) with comparison `<`, `≤`, `>` or `≥`.
"""
const Inequality = Relation{<:InequalityComparison}

"Left-hand side of a relation."
lhs(r::Relation) = r.lhs
"Right-hand side of a relation."
rhs(r::Relation) = r.rhs
comparison(::Relation{C}) where {C} = C()

"Whether `r` is an equation (`lhs = rhs`)."
isequality(r::AbstractRelation) = comparison(r) isa EqualTo
"Whether `r` is an inequality (`<`, `≤`, `>` or `≥`)."
isinequality(r::AbstractRelation) = comparison(r) isa InequalityComparison

# `isequal` on the sides: for symbolic expressions `==` builds a new expression instead of returning a Bool.
Base.:(==)(a::Relation, b::Relation) =
    comparison(a) == comparison(b) && isequal(a.lhs, b.lhs) && isequal(a.rhs, b.rhs)
Base.hash(r::Relation, h::UInt) = hash(r.rhs, hash(r.lhs, hash(comparison(r), hash(:Relation, h))))

const _COMPARISON_OPS = (:(==), :!=, :≠, :<, :<=, :≤, :>, :>=, :≥)

"""
    @relation lhs op rhs

Build a [`Relation`](@ref) using ordinary comparison syntax, without evaluating
the comparison itself. `op` must be one of `==`, `!=`, `≠`, `<`, `<=`, `≤`,
`>`, `>=`, `≥`.

# Examples
```jldoctest
julia> x = 3;

julia> @relation x^2 + 1 >= 2x
10 ≥ 6
```
"""
macro relation(ex)
    if !(Meta.isexpr(ex, :call, 3) && ex.args[1] in _COMPARISON_OPS)
        throw(ArgumentError("@relation expects a single comparison `lhs op rhs`, got `$ex`"))
    end
    op, l, r = ex.args
    return :(Relation($(esc(op)), $(esc(l)), $(esc(r))))
end

"""
    Linear(A)

The linear map `x -> A * x`, as a side of a relation. Writing a linear equation as
`Equation(Linear(A), b)` lets [`solve`](@ref) recognise it and solve it directly with
[`DirectLinear`](@ref) instead of iterating.

# Examples
```jldoctest
julia> eq = Equation(Linear([2.0 1.0; 1.0 3.0]), [3.0, 5.0])
A*x = [3.0, 5.0]

julia> solve(eq, zeros(2)).u ≈ [0.8, 1.4]
true
```
"""
struct Linear{T<:AbstractMatrix} <: Function
    A::T
end

(L::Linear)(x) = L.A * x

"""
    EquationProblem(relations, u0)

A problem for [`solve`](@ref): the relations (a [`Relation`](@ref) or an
[`EquationSystem`](@ref)) and the starting values of the unknowns, which also set their shape:

| `u0` | the unknowns, as the function sides receive them |
|---|---|
| a number | a scalar `x` |
| a vector | a vector `x` |
| a `NamedTuple` such as `(x=1.0, y=0.5)` | named unknowns, used as `u.x`, `u.y` |
| a tuple `(a, b)` of two numbers | a scalar in the bracket `[a, b]`, where the equation changes sign |

# Examples
```jldoctest
julia> prob = EquationProblem(Equation(u -> u.x * u.y, 2), (x=1.0, y=1.0));

julia> unknowns(prob)
(:x, :y)
```
"""
struct EquationProblem{U}
    system::EquationSystem
    u0::U
    function EquationProblem(system::EquationSystem, u0::U) where {U}
        _check_u0(u0)
        return new{U}(system, u0)
    end
end

EquationProblem(r::AbstractRelation, u0) = EquationProblem(EquationSystem(r), u0)

const Bracket = Tuple{Real,Real}

_check_u0(::Union{Number,AbstractVector{<:Number}}) = nothing
function _check_u0(u0::Bracket)
    u0[1] < u0[2] || throw(ArgumentError("a bracket (a, b) needs a < b, got $u0"))
    return nothing
end
function _check_u0(u0::NamedTuple)
    all(v -> v isa Number, values(u0)) || throw(ArgumentError("named unknowns must have number values, got $u0"))
    return nothing
end
_check_u0(u0) = throw(ArgumentError("u0 must be a number, a vector, a NamedTuple of numbers or a bracket (a, b); got $(typeof(u0))"))

"""
    unknowns(prob::EquationProblem)

The names of the unknowns for named starting values, otherwise their number.
"""
unknowns(prob::EquationProblem{<:NamedTuple}) = keys(prob.u0)
unknowns(prob::EquationProblem) = length(_vector(prob.u0))

# The unknowns as the flat vector the algorithms work on, and back.
_vector(u0::Number) = [float(u0)]
_vector(u0::AbstractVector) = float.(collect(u0))
_vector(u0::NamedTuple) = collect(float.(values(u0)))
_vector(u0::Bracket) = [float(_middle(u0...))]

_middle(a, b) = a + (b - a) / 2

_rebuild(u, ::Union{Number,Bracket}) = only(u)
_rebuild(u, ::AbstractVector) = u
_rebuild(u, u0::NamedTuple) = NamedTuple{keys(u0)}(Tuple(u))

"The residual of the equations of `prob` as a function of the flat vector of unknowns."
function residual_function(prob::EquationProblem)
    sys = prob.system
    all(isequality, sys) || throw(ArgumentError(
        "solve supports equations only; the system has inequalities (check them on the solution with issatisfied)"))
    u0 = prob.u0
    return u -> residual(sys, _rebuild(u, u0))
end

# Structure of the problem, for the choice of the default algorithm.
_islinear_side(side) = !(side isa Function) || side isa Linear
_islinear(prob::EquationProblem) =
    all(r -> r isa Relation && _islinear_side(r.lhs) && _islinear_side(r.rhs), prob.system) &&
    any(r -> r.lhs isa Linear || r.rhs isa Linear, prob.system)

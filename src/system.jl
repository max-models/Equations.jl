"""
    EquationSystem(relations...)
    EquationSystem(relations::AbstractVector)

An ordered collection of relations — equations and inequalities may be mixed.
Supports iteration, indexing, `length` and `push!`.

# Examples
```jldoctest
julia> sys = EquationSystem(Equation(x -> x[1] + x[2], 3), Relation(<=, x -> x[1], 1));

julia> residual(sys, [1.0, 2.0])
2-element Vector{Float64}:
 0.0
 0.0

julia> issatisfied(sys, [1.0, 2.0])
true
```
"""
struct EquationSystem
    relations::Vector{AbstractRelation}
end

EquationSystem(relations::AbstractRelation...) = EquationSystem(collect(AbstractRelation, relations))
EquationSystem(relations::AbstractVector) = EquationSystem(convert(Vector{AbstractRelation}, relations))

Base.length(sys::EquationSystem) = length(sys.relations)
Base.iterate(sys::EquationSystem, state...) = iterate(sys.relations, state...)
Base.eltype(::Type{EquationSystem}) = AbstractRelation
Base.getindex(sys::EquationSystem, i) = sys.relations[i]
Base.getindex(sys::EquationSystem, i::AbstractVector) = EquationSystem(sys.relations[i])
Base.firstindex(sys::EquationSystem) = firstindex(sys.relations)
Base.lastindex(sys::EquationSystem) = lastindex(sys.relations)
Base.push!(sys::EquationSystem, rs::AbstractRelation...) = (push!(sys.relations, rs...); sys)
Base.:(==)(a::EquationSystem, b::EquationSystem) = a.relations == b.relations
Base.hash(sys::EquationSystem, h::UInt) = hash(sys.relations, hash(:EquationSystem, h))

"The equations of `sys`, as a new [`EquationSystem`](@ref)."
equalities(sys::EquationSystem) = EquationSystem(filter(isequality, sys.relations))
"The inequalities of `sys`, as a new [`EquationSystem`](@ref)."
inequalities(sys::EquationSystem) = EquationSystem(filter(isinequality, sys.relations))

"""
    residual(sys::EquationSystem)
    residual(sys::EquationSystem, x)

The residuals of all relations in `sys`, concatenated into one vector.
"""
residual(sys::EquationSystem) = _vcat_residuals(residual(r) for r in sys)
residual(sys::EquationSystem, x) = _vcat_residuals(residual(r, x) for r in sys)

_vcat_residuals(rs) = mapreduce(vec ∘ collect, vcat, rs; init=Union{}[])

issatisfied(sys::EquationSystem; atol::Real=0) = all(r -> issatisfied(r; atol), sys)
issatisfied(sys::EquationSystem, x; atol::Real=0) = all(r -> issatisfied(r, x; atol), sys)

canonicalize(sys::EquationSystem) = EquationSystem(map(canonicalize, sys.relations))

"""
    NewtonMethod(; ad=AutoFiniteDiff(), abstol=1e-10, maxiters=100)

Newton's method (Gauss–Newton for non-square systems), the dependency-free
default algorithm of [`solve`](@ref). Jacobians are computed with the
automatic-differentiation backend `ad`: `AutoFiniteDiff()` works out of the
box, `AutoForwardDiff()` requires `using ForwardDiff`.
"""
Base.@kwdef struct NewtonMethod{AD<:ADTypes.AbstractADType}
    ad::AD = AutoFiniteDiff()
    abstol::Float64 = 1e-10
    maxiters::Int = 100
end

"""
    Solution

Result of [`solve`](@ref). Fields: `u` (the solution), `retcode` (`:Success`
or `:MaxIters`), `iterations` and `residual_norm`.
"""
struct Solution{T}
    u::T
    retcode::Symbol
    iterations::Int
    residual_norm::Float64
end

"""
    solve(eq::Equation, x0, alg=NewtonMethod())
    solve(sys::EquationSystem, x0, alg=NewtonMethod())

Find `x` such that every equation holds, starting from `x0` (a number or a
vector). Function sides are evaluated at `x`. Returns a [`Solution`](@ref).

`alg` can also be a NonlinearSolve.jl algorithm such as `NewtonRaphson()`
once NonlinearSolve is loaded.

# Examples
```jldoctest
julia> sol = solve(Equation(x -> x^2, 2), 1.0);

julia> sol.u ≈ √2
true
```
"""
CommonSolve.solve(r::Relation, x0, alg=NewtonMethod()) = solve(EquationSystem(r), x0, alg)

function CommonSolve.solve(sys::EquationSystem, x0, alg::NewtonMethod=NewtonMethod())
    f = _residual_function(sys, x0)
    u = x0 isa Number ? [float(x0)] : float.(collect(x0))
    fu = f(u)
    for k in 0:alg.maxiters
        n = norm(fu)
        n <= alg.abstol && return Solution(_unwrap(u, x0), :Success, k, float(n))
        k == alg.maxiters && return Solution(_unwrap(u, x0), :MaxIters, k, float(n))
        u = u - jacobian(f, u, alg.ad) \ fu
        fu = f(u)
    end
end

function _residual_function(sys::EquationSystem, x0)
    all(isequality, sys) || throw(ArgumentError("solve only supports equations; got inequalities in the system"))
    return x0 isa Number ? (u -> residual(sys, only(u))) : (u -> residual(sys, u))
end

_unwrap(u, x0) = x0 isa Number ? only(u) : u

"""
    jacobian(f, x::AbstractVector, ad)

The Jacobian of the vector-valued function `f` at `x`, computed with the
backend `ad`. `AutoFiniteDiff()` uses central differences and is always
available; `AutoForwardDiff()` is provided by the ForwardDiff extension.
"""
function jacobian(f, x::AbstractVector, ::AutoFiniteDiff)
    fx = f(x)
    J = similar(fx, float(eltype(fx)), length(fx), length(x))
    for j in eachindex(x)
        h = cbrt(eps(float(eltype(x)))) * max(one(real(eltype(x))), abs(x[j]))
        xp = copy(x); xp[j] += h
        xm = copy(x); xm[j] -= h
        J[:, j] = (f(xp) - f(xm)) / 2h
    end
    return J
end

jacobian(f, x, ad::ADTypes.AbstractADType) = throw(ArgumentError(
    "no Jacobian method for $(typeof(ad)); load the package that implements it (e.g. `using ForwardDiff`)"))

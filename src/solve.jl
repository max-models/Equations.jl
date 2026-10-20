"""
    AbstractEquationAlgorithm

Supertype of the algorithms built into Equations.jl: [`NewtonMethod`](@ref),
[`Bisection`](@ref) and [`DirectLinear`](@ref). Algorithms from other packages (e.g.
NonlinearSolve.jl) are accepted by [`solve`](@ref) through package extensions.
"""
abstract type AbstractEquationAlgorithm end

"""
    NewtonMethod(; ad=AutoFiniteDiff(), abstol=1e-10, maxiters=100, linesearch=true)

Newton's method (Gauss–Newton for systems with more equations than unknowns), the
general-purpose algorithm of [`solve`](@ref). Jacobians are computed with the
automatic-differentiation backend `ad`: `AutoFiniteDiff()` works out of the box,
`AutoForwardDiff()` requires `using ForwardDiff`.

With `linesearch=true`, steps are shortened by backtracking until the residual decreases, which
makes the method converge from starting points where plain Newton steps overshoot. Iteration
stops once the norm of the residual is at most `abstol`.
"""
Base.@kwdef struct NewtonMethod{AD<:ADTypes.AbstractADType} <: AbstractEquationAlgorithm
    ad::AD = AutoFiniteDiff()
    abstol::Float64 = 1e-10
    maxiters::Int = 100
    linesearch::Bool = true
end

"""
    Bisection(; abstol=0.0, maxiters=1000)

Bisection on a bracket `(a, b)` in which a scalar equation changes sign: always converges, to an
interval of width at most `abstol` (by default until the floating-point numbers in the bracket
run out). The default algorithm of [`solve`](@ref) when the starting value is a bracket.
"""
Base.@kwdef struct Bisection <: AbstractEquationAlgorithm
    abstol::Float64 = 0.0
    maxiters::Int = 1000
end

"""
    DirectLinear()

Solve a linear system `A * x = b` in one step, with `\\` (least squares for non-square `A`).
The default algorithm of [`solve`](@ref) when every side of the equations is a constant or a
[`Linear`](@ref) map. Passed explicitly, it assumes the residual is affine in the unknowns.
"""
struct DirectLinear <: AbstractEquationAlgorithm end

"""
    Solution

Result of [`solve`](@ref). Fields: `u` (the solution, in the shape of the starting values),
`retcode` (`:Success`, `:MaxIters`, or `:Failure` when a step could not be computed, e.g. at a
singular Jacobian), `iterations`, `residual_norm` and `alg` (the
algorithm used).
"""
struct Solution{T,A}
    u::T
    retcode::Symbol
    iterations::Int
    residual_norm::Float64
    alg::A
end

"""
    solve(prob::EquationProblem[, alg])
    solve(relations, u0[, alg])

Solve the equations of `prob` (or of `relations`, a [`Relation`](@ref) or an
[`EquationSystem`](@ref), with starting values `u0`; see [`EquationProblem`](@ref) for their
forms). Returns a [`Solution`](@ref).

Without `alg`, the algorithm is chosen from the problem ([`default_algorithm`](@ref)):
[`Bisection`](@ref) for a bracket, [`DirectLinear`](@ref) for linear equations and
[`NewtonMethod`](@ref) otherwise. `alg` can also be a NonlinearSolve.jl algorithm such as
`TrustRegion()` once NonlinearSolve is loaded.

# Examples
```jldoctest
julia> solve(Equation(x -> x^2, 2), 1.0).u ≈ √2
true

julia> solve(Equation(x -> x^2, 2), (0, 2)).alg
Bisection(abstol=0.0, maxiters=1000)

julia> sol = solve(Equation(u -> u.x + u.y, 3), (x=0.0, y=0.0));

julia> sol.u.x + sol.u.y ≈ 3
true
```
"""
CommonSolve.solve(prob::EquationProblem) = solve(prob, default_algorithm(prob))
CommonSolve.solve(r::Union{AbstractRelation,EquationSystem}, u0, args...; kwargs...) =
    solve(EquationProblem(r, u0), args...; kwargs...)

"""
    default_algorithm(prob::EquationProblem)

The algorithm [`solve`](@ref) uses for `prob` when none is given.
"""
function default_algorithm(prob::EquationProblem)
    prob.u0 isa Bracket && return Bisection()
    prob.u0 isa Union{Number,AbstractVector} && _islinear(prob) && return DirectLinear()
    return NewtonMethod()
end

function CommonSolve.solve(prob::EquationProblem, alg::NewtonMethod)
    prob.u0 isa Bracket && throw(ArgumentError("NewtonMethod needs a starting point, not a bracket; use Bisection"))
    f = residual_function(prob)
    u = _vector(prob.u0)
    fu = f(u)
    n = norm(fu)
    for k in 0:alg.maxiters
        n <= alg.abstol && return Solution(_rebuild(u, prob.u0), :Success, k, float(n), alg)
        k == alg.maxiters && break
        step = _newton_step(jacobian(f, u, alg.ad), fu)
        step === nothing && return Solution(_rebuild(u, prob.u0), :Failure, k, float(n), alg)
        t = 1.0
        unew = u - step
        fnew = f(unew)
        # backtrack until the residual decreases (Armijo condition on ‖f‖)
        while alg.linesearch && !(norm(fnew) <= (1 - 1e-4 * t) * n) && t > 1e-6
            t /= 2
            unew = u - t * step
            fnew = f(unew)
        end
        u, fu, n = unew, fnew, norm(fnew)
    end
    return Solution(_rebuild(u, prob.u0), :MaxIters, alg.maxiters, float(n), alg)
end

# The Newton step J \ f, or nothing where the Jacobian is singular or the step not finite.
function _newton_step(J, fu)
    step = try
        J \ fu
    catch err
        err isa SingularException || rethrow()
        return nothing
    end
    return all(isfinite, step) ? step : nothing
end

function CommonSolve.solve(prob::EquationProblem, alg::Bisection)
    prob.u0 isa Bracket || throw(ArgumentError("Bisection needs a bracket (a, b) as starting value"))
    length(prob.system) == 1 || throw(ArgumentError("Bisection solves a single scalar equation"))
    f = residual_function(prob)
    g(x) = only(f([x]))
    a, b = float.(prob.u0)
    ga, gb = g(a), g(b)
    iszero(ga) && return Solution(a, :Success, 0, 0.0, alg)
    iszero(gb) && return Solution(b, :Success, 0, 0.0, alg)
    sign(ga) == sign(gb) && throw(ArgumentError("the equation does not change sign on the bracket ($a, $b)"))
    for k in 1:alg.maxiters
        m = _middle(a, b)
        gm = g(m)
        if iszero(gm) || m == a || m == b || b - a <= alg.abstol
            return Solution(m, :Success, k, float(abs(gm)), alg)
        end
        if sign(gm) == sign(ga)
            a, ga = m, gm
        else
            b = m
        end
    end
    m = _middle(a, b)
    return Solution(m, :MaxIters, alg.maxiters, float(abs(g(m))), alg)
end

function CommonSolve.solve(prob::EquationProblem, alg::DirectLinear)
    prob.u0 isa Bracket && throw(ArgumentError("DirectLinear needs a starting point, not a bracket"))
    f = residual_function(prob)
    u0 = _vector(prob.u0)
    # f(u) = A u - b: f(0) gives -b and f(eⱼ) - f(0) the columns of A, exactly for affine f
    f0 = f(zero(u0))
    A = similar(f0, float(eltype(f0)), length(f0), length(u0))
    for j in eachindex(u0)
        e = zero(u0)
        e[j] = 1
        A[:, j] = f(e) - f0
    end
    u = A \ -f0
    return Solution(_rebuild(u, prob.u0), :Success, 1, float(norm(f(u))), alg)
end

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

"""
    AbstractEquationAlgorithm

Supertype of the algorithms built into Equations.jl: [`NewtonMethod`](@ref),
[`Bisection`](@ref), [`DirectLinear`](@ref), [`AllRoots`](@ref) and [`ClosedForm`](@ref). Algorithms from other packages (e.g.
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
[`Linear`](@ref) map; `A` and `b` then come from [`linear_system`](@ref), so sparse matrices
stay sparse. Passed explicitly for other equations, it assumes the residual is affine in the
unknowns and builds a dense `A` from it. For iterative and specialised solvers, pass a
LinearSolve.jl algorithm instead (with `using LinearSolve`).
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
forms). Returns a [`Solution`](@ref). A system with inequalities is solved by finding a point
that satisfies all of its relations.

Without `alg`, the algorithm is chosen from the problem ([`default_algorithm`](@ref)):
[`Bisection`](@ref) for a bracket, [`Feasibility`](@ref) for a system with inequalities,
[`DirectLinear`](@ref) for linear equations and [`NewtonMethod`](@ref) otherwise. `alg` can also be a NonlinearSolve.jl algorithm such as
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
    any(isinequality, prob.system) && return Feasibility()
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
    A, b = _islinear(prob) ? linear_system(prob) : _probe_linear(f, _vector(prob.u0))
    u = A \ b
    return Solution(_rebuild(u, prob.u0), :Success, 1, float(norm(f(u))), alg)
end

# A u = b for an affine residual f(u) = A u - b: f(0) gives -b and f(eⱼ) - f(0) the columns of A.
function _probe_linear(f, u0)
    f0 = f(zero(u0))
    A = similar(f0, float(eltype(f0)), length(f0), length(u0))
    for j in eachindex(u0)
        e = zero(u0)
        e[j] = 1
        A[:, j] = f(e) - f0
    end
    return A, -f0
end

"""
    AllRoots(; samples=1000, real=false)

Find all solutions instead of one. What "all" means depends on the problem:

- a scalar equation with a bracket `(a, b)`: every root in `[a, b]` where the equation changes
  sign, by sampling it at `samples` points and bisecting each sign change (roots of even
  multiplicity, and roots closer together than the sampling, can be missed);
- an equation between Polynomials.jl polynomials (and numbers): all complex roots, from the
  Polynomials extension;
- a system of polynomial equations, written as ordinary Julia functions: all isolated complex
  solutions, by homotopy continuation, from the HomotopyContinuation extension.

`real=true` keeps the real solutions only. The solution `u` is a vector of solutions, each in the
shape of the starting values. For a polynomial the starting values can be left out
(`solve(eq, AllRoots())`); for a system they only declare the unknowns.

# Examples
```jldoctest
julia> solve(Equation(x -> sin(x), 0), (-1, 7), AllRoots()).u ≈ [0, π, 2π]
true
```
"""
Base.@kwdef struct AllRoots <: AbstractEquationAlgorithm
    samples::Int = 1000
    real::Bool = false
end

# The roots of a polynomial need no starting values.
CommonSolve.solve(r::Union{AbstractRelation,EquationSystem}, alg::AllRoots) = solve(EquationProblem(r, 0.0), alg)

function CommonSolve.solve(prob::EquationProblem, alg::AllRoots)
    if length(prob.system) == 1
        roots = _polynomial_roots(only(prob.system))
        if roots !== nothing
            alg.real && (roots = [real(z) for z in roots if abs(imag(z)) <= 1e-10 * max(1, abs(z))])
            residuals = [only(residual_function(prob)([z])) for z in roots]
            return Solution(roots, :Success, 1, float(maximum(abs, residuals; init=0.0)), alg)
        end
    end
    prob.u0 isa Bracket && return _bracket_roots(prob, alg)
    return _homotopy_roots(prob, alg)
end

# Extension points: all roots of a polynomial equation (Polynomials) and of a polynomial
# system (HomotopyContinuation).
_polynomial_roots(_) = nothing
_homotopy_roots(_, _) = throw(ArgumentError(
    "AllRoots needs a bracket (a, b) for a scalar equation, polynomials from Polynomials.jl, " *
    "or `using HomotopyContinuation` for polynomial systems"))

function _bracket_roots(prob::EquationProblem, alg::AllRoots)
    length(prob.system) == 1 || throw(ArgumentError("AllRoots on a bracket solves a single scalar equation"))
    f = residual_function(prob)
    g(x) = only(f([x]))
    a, b = float.(prob.u0)
    xs = range(a, b; length=alg.samples + 1)
    gs = g.(xs)
    roots = Float64[]
    for i in eachindex(xs)
        iszero(gs[i]) && (push!(roots, xs[i]); continue)
        i < lastindex(xs) && !iszero(gs[i+1]) && sign(gs[i]) != sign(gs[i+1]) || continue
        sol = solve(EquationProblem(prob.system, (xs[i], xs[i+1])), Bisection())
        push!(roots, sol.u)
    end
    return Solution(roots, :Success, length(xs), float(maximum(abs ∘ g, roots; init=0.0)), alg)
end

"""
    ClosedForm()

Solve in closed form, symbolically, instead of numerically: `x^2 = 2` gives `±√2`. Provided by
the Symbolics extension (`using Symbolics`), which uses `Symbolics.symbolic_solve`; that in turn
needs `using Nemo` for polynomial equations and `using Groebner` for systems.

The equations can have symbolic sides, with the unknowns given as Symbolics variables
(`solve(eq, x, ClosedForm())`), or function sides, with starting values that only declare the
unknowns as for every other algorithm (`solve(eq, (a=0, b=0), ClosedForm())`). `sol.u` is a vector
of all the solutions found; `residual_norm` is `NaN`, since nothing is evaluated numerically.
"""
struct ClosedForm <: AbstractEquationAlgorithm end

CommonSolve.solve(r::Union{AbstractRelation,EquationSystem}, alg::ClosedForm) = solve(EquationProblem(r, 0.0), alg)
CommonSolve.solve(prob::EquationProblem, alg::ClosedForm) = _closed_form(prob, alg)

# Extension point: the Symbolics extension solves in closed form.
_closed_form(_, _) = throw(ArgumentError("ClosedForm needs `using Symbolics` (and `using Nemo` for polynomial equations)"))

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

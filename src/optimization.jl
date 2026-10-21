# Inequalities and optimization: feasibility of systems with inequalities, and minimization subject
# to equations and inequalities.

# The relations of a system as constraints on the flat vector of unknowns: equations h(u) = 0 and
# inequalities g(u) ≤ 0, or g(u) < 0 where `strict` is set (`a ≥ b` becomes `b - a ≤ 0`).
struct Constraints{U}
    equations::Vector{AbstractRelation}
    inequalities::Vector{AbstractRelation}
    strict::BitVector
    u0::U
end

function Constraints(sys::EquationSystem, u0)
    any(r -> comparison(r) isa NotEqualTo, sys) && throw(ArgumentError(
        "≠ is not supported as a constraint; split it into two problems with < and >"))
    eqs = filter(isequality, sys.relations)
    ineqs = filter(isinequality, sys.relations)
    x0 = _rebuild(_vector(u0), u0)
    strict = BitVector(reduce(vcat,
        [fill(comparison(r) isa Union{LessThan,GreaterThan}, length(_canonical(r, x0))) for r in ineqs]; init=Bool[]))
    return Constraints(eqs, ineqs, strict, u0)
end

_orientation(::Union{EqualTo,LessThan,LessEqual}) = 1
_orientation(::Union{GreaterThan,GreaterEqual}) = -1
_canonical(r::AbstractRelation, x) = _orientation(comparison(r)) .* vec(collect(residual(r, x)))

_flatcat(parts) = reduce(vcat, parts; init=Float64[])
_equations(c::Constraints, u) = _flatcat([_canonical(r, _rebuild(u, c.u0)) for r in c.equations])
_inequalities(c::Constraints, u) = _flatcat([_canonical(r, _rebuild(u, c.u0)) for r in c.inequalities])

"How far `u` is from satisfying the constraints: the norm of the equation residuals and the positive parts of the inequalities."
_violation(c::Constraints, u) = float(norm(vcat(_equations(c, u), max.(_inequalities(c, u), 0))))

function _isfeasible(c::Constraints, u, abstol)
    h, g = _equations(c, u), _inequalities(c, u)
    return norm(h, Inf) <= abstol && all(i -> c.strict[i] ? g[i] < 0 : g[i] <= abstol, eachindex(g))
end

"""
    Feasibility(; ad=AutoFiniteDiff(), abstol=1e-10, margin=1e-8, maxiters=200)

Find a point that satisfies a system of equations and inequalities: the default algorithm of
[`solve`](@ref) for systems with inequalities. It minimizes the violation of the relations,
`‖h(u)‖² + ‖max(g(u), 0)‖²` for equations `h(u) = 0` and inequalities `g(u) ≤ 0`, with
Levenberg–Marquardt steps that aim `margin` inside the inequalities. Equations must hold to
`abstol`, inequalities `≤`, `≥` to `abstol` (they hold exactly where the region has an interior)
and `<`, `>` exactly.

A starting point that already satisfies the system is returned as it is. Otherwise the retcode is
`:Success` once a feasible point is found, `:Infeasible` where the violation cannot be reduced any
further (a local minimum: the system may have no solution, or none near the start) and `:MaxIters`.
`residual_norm` is the remaining violation.

# Examples
```jldoctest
julia> disc = EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5));

julia> sol = solve(disc, (x=-2.0, y=2.0));

julia> sol.retcode, issatisfied(disc, sol.u; atol=1e-10)
(:Success, true)
```
"""
Base.@kwdef struct Feasibility{AD<:ADTypes.AbstractADType} <: AbstractEquationAlgorithm
    ad::AD = AutoFiniteDiff()
    abstol::Float64 = 1e-10
    margin::Float64 = 1e-8
    maxiters::Int = 200
end

function CommonSolve.solve(prob::EquationProblem, alg::Feasibility)
    prob.u0 isa Bracket && throw(ArgumentError("Feasibility needs a starting point, not a bracket"))
    c = Constraints(prob.system, prob.u0)
    r(u) = vcat(_equations(c, u), max.(_inequalities(c, u) .+ alg.margin, 0))
    # Jacobian of r: that of the smooth h and g, with the rows of inactive inequalities zeroed
    # (differentiating max(g, 0) itself would smear its kink over the finite-difference step)
    hg(u) = vcat(_equations(c, u), _inequalities(c, u))
    neq = length(_equations(c, _vector(prob.u0)))
    u = _vector(prob.u0)
    ru = r(u)
    λ = 1e-3
    stalled = 0   # consecutive steps that barely reduce the violation
    for k in 0:alg.maxiters
        _isfeasible(c, u, alg.abstol) && return Solution(_rebuild(u, prob.u0), :Success, k, _violation(c, u), alg)
        k == alg.maxiters && break
        stalled >= 10 && return Solution(_rebuild(u, prob.u0), :Infeasible, k, _violation(c, u), alg)
        J = jacobian(hg, u, alg.ad)
        J[neq+1:end, :] .*= ru[neq+1:end] .> 0
        JtJ, Jtr = J' * J, J' * ru
        # Marquardt scaling, floored relative to the largest entry so that no direction is left
        # without damping
        d = diag(JtJ)
        D = Diagonal(max.(d, 1e-3 * maximum(d; init=0.0), 1e-12))
        n = norm(ru)
        while true
            unew = u - (JtJ + λ * D) \ Jtr
            rnew = r(unew)
            if norm(rnew) < n
                stalled = norm(rnew) > (1 - 1e-6) * n ? stalled + 1 : 0
                u, ru, λ = unew, rnew, max(λ / 3, 1e-12)
                break
            end
            λ *= 4
            λ > 1e10 && return Solution(_rebuild(u, prob.u0), :Infeasible, k, _violation(c, u), alg)
        end
    end
    return Solution(_rebuild(u, prob.u0), :MaxIters, alg.maxiters, _violation(c, u), alg)
end

"""
    Optimum

Result of [`minimize`](@ref) and [`maximize`](@ref). Fields: `u` (the optimal point, in the shape
of the starting values), `objective` (the objective there), `retcode` (`:Success`, `:MaxIters`,
`:Infeasible`, `:Unbounded`, or a JuMP termination status), `iterations`, `violation` (how far
`u` is from satisfying the constraints) and `alg`.
"""
struct Optimum{T,V,A}
    u::T
    objective::V
    retcode::Symbol
    iterations::Int
    violation::Float64
    alg::A
end

"""
    AugmentedLagrangian(; ad=AutoFiniteDiff(), abstol=1e-8, gtol=1e-8, maxiters=50, inner_maxiters=1000, penalty=10.0)

The default algorithm of [`minimize`](@ref) and [`maximize`](@ref): the augmented Lagrangian
method for equations `h(u) = 0` and inequalities `g(u) ≤ 0`. Each outer iteration minimizes
`f(u) + λ⋅h(u) + ρ/2 ‖h(u)‖² + 1/(2ρ) ‖max(μ + ρ g(u), 0)‖²` with BFGS, then updates the
multipliers `λ`, `μ`, and raises the penalty `ρ` (from `penalty`) while the violation does not
shrink fast enough. Without constraints it is BFGS alone.

The result is `:Success` once the constraints hold to `abstol` and BFGS has converged: the gradient
is below `gtol` (relative to the objective), or no further decrease can be found. Gradients use
`ad`; `AutoForwardDiff()` (with `using ForwardDiff`) gives more accurate optima than finite
differences.
"""
Base.@kwdef struct AugmentedLagrangian{AD<:ADTypes.AbstractADType} <: AbstractEquationAlgorithm
    ad::AD = AutoFiniteDiff()
    abstol::Float64 = 1e-8
    gtol::Float64 = 1e-8
    maxiters::Int = 50
    inner_maxiters::Int = 1000
    penalty::Float64 = 10.0
end

"""
    JuMPSolver(optimizer; silent=true)

Solve with a [JuMP](https://jump.dev) optimizer, e.g. `HiGHS.Optimizer` for linear and quadratic
problems or `Ipopt.Optimizer` for nonlinear ones (needs `using JuMP` and the optimizer's package).
Works for [`minimize`](@ref)/[`maximize`](@ref) and for finding a feasible point with
[`solve`](@ref). The unknowns become JuMP variables, started at `u0`, and the function sides are
called on them, so they must be functions JuMP can build expressions from (arithmetic, powers,
`sin`, `exp`, …). Strict inequalities are not supported.
"""
struct JuMPSolver{O} <: AbstractEquationAlgorithm
    optimizer::O
    silent::Bool
end

JuMPSolver(optimizer; silent::Bool=true) = JuMPSolver(optimizer, silent)

CommonSolve.solve(prob::EquationProblem, alg::JuMPSolver) = _jump_solve(nothing, 1, prob.system, prob.u0, alg)

# Extension point: the JuMP extension solves feasibility (no objective) and optimization problems.
_jump_solve(_, _, _, _, _) = throw(ArgumentError("JuMPSolver needs `using JuMP`"))

"""
    minimize(f, u0[, alg]; subject_to=EquationSystem())

Minimize the objective `f(u)` over the unknowns `u`, subject to the equations and
inequalities `subject_to` (a [`Relation`](@ref), an [`EquationSystem`](@ref) or a vector of
relations). The starting values `u0` set the unknowns as for [`solve`](@ref): a number, a vector or
a `NamedTuple`. Returns an [`Optimum`](@ref).

`alg` is [`AugmentedLagrangian`](@ref) by default, or a [`JuMPSolver`](@ref).

# Examples
```jldoctest
julia> opt = minimize(u -> (u.x - 1)^2 + (u.y - 2)^2, (x=0.0, y=0.0);
                      subject_to=Relation(<=, u -> u.x + u.y, 1));

julia> opt.retcode, isapprox(opt.u.x, 0; atol=1e-6), isapprox(opt.u.y, 1; atol=1e-6)
(:Success, true, true)

julia> maximize(x -> x * (10 - x), 1.0).u ≈ 5
true
```
"""
minimize(f, u0, alg=AugmentedLagrangian(); subject_to=EquationSystem()) = _optimize(f, 1, u0, _system(subject_to), alg)

"""
    maximize(f, u0[, alg]; subject_to=EquationSystem())

Maximize the objective `f(u)`; see [`minimize`](@ref).
"""
maximize(f, u0, alg=AugmentedLagrangian(); subject_to=EquationSystem()) = _optimize(f, -1, u0, _system(subject_to), alg)

_system(r::AbstractRelation) = EquationSystem(r)
_system(sys::EquationSystem) = sys
_system(rs::AbstractVector) = EquationSystem(rs)

_optimize(f, sense, u0, sys, alg::JuMPSolver) = _jump_solve(f, sense, sys, u0, alg)
_optimize(_, _, _, _, alg) = throw(ArgumentError("$(nameof(typeof(alg))) does not minimize; use AugmentedLagrangian or a JuMPSolver"))

function _optimize(f, sense, u0, sys, alg::AugmentedLagrangian)
    u0 isa Bracket && throw(ArgumentError("minimize needs a starting point, not a bracket"))
    c = Constraints(sys, u0)
    any(c.strict) && throw(ArgumentError("strict inequalities (<, >) have no optimum in general; use ≤ or ≥"))
    objective(u) = sense * f(_rebuild(u, u0))
    u = _vector(u0)
    λ = zeros(length(_equations(c, u)))
    μ = zeros(length(_inequalities(c, u)))
    ρ = alg.penalty
    previous = Inf
    iterations = 0
    # f, h and g in one vector, so that one Jacobian gives the gradient of the augmented Lagrangian
    # by the chain rule (differentiating it as a whole would magnify finite-difference errors by ρ)
    nh = length(λ)
    fhg(x) = vcat(objective(x), _equations(c, x), _inequalities(c, x))
    for _ in 1:alg.maxiters
        L(x) = objective(x) + _augmentation(_equations(c, x), _inequalities(c, x), λ, μ, ρ)
        function ∇L(x)
            J = jacobian(fhg, x, alg.ad)
            v = fhg(x)
            h, g = v[2:nh+1], v[nh+2:end]
            return J[1, :] + J[2:nh+1, :]' * (λ + ρ * h) + J[nh+2:end, :]' * max.(μ + ρ * g, 0)
        end
        u, its, status = _bfgs(L, ∇L, u, alg)
        iterations += its
        h, g = _equations(c, u), _inequalities(c, u)
        violation = float(norm(vcat(h, max.(g, 0))))
        if violation <= alg.abstol && status !== :maxiters
            return Optimum(_rebuild(u, u0), f(_rebuild(u, u0)), :Success, iterations, violation, alg)
        end
        λ = λ + ρ * h
        μ = max.(μ + ρ * g, 0)
        violation > previous / 4 && (ρ *= 10)
        previous = violation
    end
    return Optimum(_rebuild(u, u0), f(_rebuild(u, u0)), :MaxIters, iterations, _violation(c, u), alg)
end

_augmentation(h, g, λ, μ, ρ) =
    (isempty(h) ? 0.0 : sum(λ .* h) + ρ / 2 * sum(abs2, h)) +
    (isempty(g) ? 0.0 : sum(abs2, max.(μ .+ ρ .* g, 0)) / 2ρ - sum(abs2, μ) / 2ρ)

# BFGS with backtracking line search. Returns the point, the number of iterations and the status:
# :converged (gradient below gtol, relative to the function value), :stalled (no further decrease
# found, to rounding) or :maxiters.
function _bfgs(φ, grad, u, alg)
    fu, g = φ(u), grad(u)
    H = Matrix{Float64}(I, length(u), length(u))
    scaled = false   # whether H carries curvature information yet
    flat = 0         # consecutive steps that change φ only by rounding
    for k in 0:alg.inner_maxiters
        norm(g, Inf) <= alg.gtol * (1 + abs(fu)) && return u, k, :converged
        flat >= 3 && return u, k, :stalled
        k == alg.inner_maxiters && return u, k, :maxiters
        p = -(H * g)
        if !(dot(g, p) < 0)   # not a descent direction: restart from the gradient
            H = Matrix{Float64}(I, length(u), length(u))
            scaled = false
            p = -g
        end
        # without curvature information, the first step moves by at most 1 in any unknown
        scaled || (p = p / max(1, norm(p, Inf)))
        slope = dot(g, p)
        t = 1.0
        unew = u + p
        fnew = φ(unew)
        while !(fnew <= fu + 1e-4 * t * slope)
            t /= 2
            t < 1e-16 && return u, k, :stalled
            unew = u + t * p
            fnew = φ(unew)
        end
        gnew = grad(unew)
        s, y = unew - u, gnew - g
        sy = dot(s, y)
        if sy > 1e-12 * norm(s) * norm(y)
            scaled || (H .*= sy / dot(y, y); scaled = true)
            ρ = 1 / sy
            H = (I - ρ * s * y') * H * (I - ρ * y * s') + ρ * s * s'
        end
        flat = abs(fu - fnew) <= 4eps() * (1 + abs(fu)) ? flat + 1 : 0
        u, fu, g = unew, fnew, gnew
    end
    return u, alg.inner_maxiters, :maxiters
end

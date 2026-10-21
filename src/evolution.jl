"""
    TimeDerivative()
    ∂ₜ

The time derivative of the unknowns, as the left-hand side of an evolution equation:
`Equation(∂ₜ, f)` reads `du/dt = f(t, u)`, `Equation(∂ₜ, Hamiltonian(H))` reads Hamilton's
equations and `Equation(∂ₜ, Lagrangian(L))` the Euler–Lagrange equations. Such equations are
solved over a time span with [`InitialValueProblem`](@ref).
"""
struct TimeDerivative end

"The time derivative `∂ₜ = TimeDerivative()`, see [`TimeDerivative`](@ref)."
const ∂ₜ = TimeDerivative()

"""
    Hamiltonian(H)

The Hamiltonian vector field of `H(t, q, p)`, as the right-hand side of an evolution equation:
`Equation(∂ₜ, Hamiltonian(H))` reads

    dq/dt =  ∂H/∂p,    dp/dt = -∂H/∂q.

The unknowns are given as `(q=q0, p=p0)`, with numbers or vectors. The gradients of `H` are
computed with the backend `ad` of the algorithm or of the problem.

# Examples
```jldoctest
julia> oscillator = Equation(∂ₜ, Hamiltonian((t, q, p) -> p^2 / 2 + q^2 / 2))
∂ₜu = J∇H(q, p)

julia> sol = solve(oscillator, (q=1.0, p=0.0), (0.0, 2π); dt=0.01);

julia> sol.u[end].q ≈ 1
true
```
"""
struct Hamiltonian{F}
    H::F
end

(h::Hamiltonian)(t, q, p) = h.H(t, q, p)

"""
    Lagrangian(L)

The Euler–Lagrange equations of the Lagrangian `L(t, q, v)`, as the right-hand side of an
evolution equation: `Equation(∂ₜ, Lagrangian(L))` reads

    dq/dt = v,    d/dt ∂L/∂v = ∂L/∂q.

The unknowns are the positions and velocities, given as `(q=q0, v=v0)` with numbers or vectors.
`L` must be regular (`∂²L/∂v²` invertible). Its derivatives are computed with the backend `ad`
of the problem. Without an algorithm, [`solve`](@ref) uses the variational integrator
[`VariationalMidpoint`](@ref).

# Examples
```jldoctest
julia> pendulum = Equation(∂ₜ, Lagrangian((t, q, v) -> v^2 / 2 + cos(q)))
d/dt ∂L/∂v = ∂L/∂q

julia> sol = solve(pendulum, (q=0.1, v=0.0), (0.0, 2π); dt=0.01);

julia> isapprox(sol.u[end].q, 0.1; rtol=1e-2)
true
```
"""
struct Lagrangian{F}
    L::F
end

(l::Lagrangian)(t, q, v) = l.L(t, q, v)

"""
    InitialValueProblem(equation, u0, tspan; dt, ad=AutoFiniteDiff())

The evolution equation `equation` (`Equation(∂ₜ, f)`, `Equation(∂ₜ, Hamiltonian(H))` or
`Equation(∂ₜ, Lagrangian(L))`) from the initial values `u0` over the time span `tspan = (t0, t1)`,
with time step `dt`. `u0` is a number, a vector or a `NamedTuple` of numbers, in which shape
`f(t, u)` receives the unknowns and returns their derivative; for Hamiltonian systems it is
`(q=q0, p=p0)` and for Lagrangian systems `(q=q0, v=v0)`.

`ad` is the backend for the derivatives of a Hamiltonian or Lagrangian. [`solve`](@ref) integrates
the problem and
returns a [`Trajectory`](@ref).
"""
struct InitialValueProblem{R<:Relation,U,T<:AbstractFloat,AD<:ADTypes.AbstractADType}
    equation::R
    u0::U
    tspan::Tuple{T,T}
    dt::T
    ad::AD
end

function InitialValueProblem(equation::Relation, u0, tspan::Tuple{Real,Real}; dt::Real, ad=AutoFiniteDiff())
    equation isa Equation && equation.lhs isa TimeDerivative ||
        throw(ArgumentError("an initial value problem needs an evolution equation Equation(∂ₜ, f)"))
    if equation.rhs isa Hamiltonian
        u0 isa NamedTuple{(:q, :p)} || throw(ArgumentError("a Hamiltonian system needs initial values (q=q0, p=p0)"))
        length(u0.q) == length(u0.p) || throw(DimensionMismatch("q and p must have the same length"))
    elseif equation.rhs isa Lagrangian
        u0 isa NamedTuple{(:q, :v)} || throw(ArgumentError("a Lagrangian system needs initial values (q=q0, v=v0)"))
        length(u0.q) == length(u0.v) || throw(DimensionMismatch("q and v must have the same length"))
    else
        _check_u0(u0)
        u0 isa Bracket && throw(ArgumentError("initial values cannot be a bracket"))
    end
    t0, t1 = float.(promote(tspan...))
    t1 > t0 || throw(ArgumentError("the time span must have t1 > t0, got $tspan"))
    dt > 0 || throw(ArgumentError("the time step must be positive, got $dt"))
    T = promote_type(typeof(t0), typeof(float(dt)))
    return InitialValueProblem(equation, u0, (T(t0), T(t1)), T(dt), ad)
end

ishamiltonian(ivp::InitialValueProblem) = ivp.equation.rhs isa Hamiltonian
islagrangian(ivp::InitialValueProblem) = ivp.equation.rhs isa Lagrangian
_ismechanical(ivp::InitialValueProblem) = ishamiltonian(ivp) || islagrangian(ivp)

# The state as one flat vector, (q, p) or (q, v) stacked for Hamiltonian and Lagrangian systems,
# and back.
function _state(ivp::InitialValueProblem)
    _ismechanical(ivp) || return _vector(ivp.u0)
    return vcat(float.(ivp.u0.q), float.(ivp.u0[2]))
end
function _unstate(x, ivp::InitialValueProblem)
    _ismechanical(ivp) || return _rebuild(x, ivp.u0)
    n = length(ivp.u0.q)
    q, y = x[1:n], x[n+1:end]
    return NamedTuple{keys(ivp.u0)}(ivp.u0.q isa Number ? (only(q), only(y)) : (q, y))
end

# A Lagrangian as a function of vectors q and v, whatever the shape of the initial values.
function _lagrangian(ivp::InitialValueProblem)
    L = ivp.equation.rhs
    return ivp.u0.q isa Number ? (t, q, v) -> L(t, q[1], v[1]) : (t, q, v) -> L(t, q, v)
end

_gradient(f, x, ad) = vec(jacobian(y -> [f(y)], x, ad))

# The Hessian of a scalar function. With finite differences, second differences with a step
# ε^(1/4) (accurate to about 1e-8) instead of differences of differences (about 1e-6).
function _hessian(f, x::AbstractVector, ::AutoFiniteDiff)
    n = length(x)
    H = zeros(float(eltype(x)), n, n)
    h = [eps(float(eltype(x)))^(1 / 4) * max(1, abs(xi)) for xi in x]
    e(i) = (v = zeros(n); v[i] = h[i]; v)
    for i in 1:n, j in i:n
        H[i, j] = H[j, i] = (f(x + e(i) + e(j)) - f(x + e(i) - e(j)) - f(x - e(i) + e(j)) + f(x - e(i) - e(j))) /
                            (4 * h[i] * h[j])
    end
    return H
end
_hessian(f, x::AbstractVector, ad) = jacobian(y -> _gradient(f, y, ad), x, ad)

# The Euler–Lagrange equations as a first-order system for x = (q, v): with z = (t, q, v),
# M v̇ = ∂L/∂q - (∂²L/∂v∂q) v - ∂²L/∂v∂t, where M = ∂²L/∂v² is the mass matrix.
function _euler_lagrange(ivp::InitialValueProblem)
    L = _lagrangian(ivp)
    n = length(ivp.u0.q)
    Lz(z) = L(z[1], z[2:n+1], z[n+2:end])
    return function (t, x)
        z = vcat(t, x)
        g = _gradient(Lz, z, ivp.ad)
        K = _hessian(Lz, z, ivp.ad)
        q̇ = x[n+1:end]
        M, C, c = K[n+2:end, n+2:end], K[n+2:end, 2:n+1], K[n+2:end, 1]
        return vcat(q̇, M \ (g[2:n+1] - C * q̇ - c))
    end
end
_flatten(du, ::Number) = [du]
_flatten(du, ::AbstractVector) = collect(du)
_flatten(du, u0::NamedTuple) = collect(values(du))

"""
    vector_field(ivp::InitialValueProblem)

The right-hand side of the problem as a function `(t, x) -> dx/dt` of the flat state vector `x`
(`[q; p]` for Hamiltonian systems, `[q; v]` for Lagrangian systems, whose Euler–Lagrange equations
are solved for the accelerations), for use with other integrators.
"""
function vector_field(ivp::InitialValueProblem)
    rhs = ivp.equation.rhs
    rhs isa Lagrangian && return _euler_lagrange(ivp)
    if rhs isa Hamiltonian
        n = length(ivp.u0.q)
        scalar = ivp.u0.q isa Number
        H(t, x) = scalar ? rhs(t, x[1], x[2]) : rhs(t, x[1:n], x[n+1:end])
        return function (t, x)
            ∇H = vec(jacobian(y -> [H(t, y)], x, ivp.ad))
            return vcat(∇H[n+1:end], -∇H[1:n])
        end
    end
    return (t, x) -> _flatten(rhs(t, _rebuild(x, ivp.u0)), ivp.u0)
end

"""
    Trajectory

Result of [`solve`](@ref) for an [`InitialValueProblem`](@ref). Fields: `t` (the times), `u` (the
state at each time, in the shape of the initial values), `retcode` and `alg`.
"""
struct Trajectory{T,U,A}
    t::Vector{T}
    u::Vector{U}
    retcode::Symbol
    alg::A
end

"""
    AbstractTimeStepper

Supertype of the time integrators built into Equations.jl, [`RungeKutta4`](@ref),
[`MidpointRule`](@ref) and [`VariationalMidpoint`](@ref). The geometric integrators of
GeometricIntegrators.jl are accepted too, with
`using GeometricIntegrators`.
"""
abstract type AbstractTimeStepper <: AbstractEquationAlgorithm end

"""
    RungeKutta4()

The classical explicit Runge–Kutta method of order 4, the default for evolution equations
`du/dt = f(t, u)`.
"""
struct RungeKutta4 <: AbstractTimeStepper end

"""
    MidpointRule(; newton=NewtonMethod())

The implicit midpoint rule `x₁ = x₀ + Δt f(t + Δt/2, (x₀ + x₁)/2)`, of order 2. It is symplectic,
so for Hamiltonian systems the energy error stays bounded over long times instead of drifting;
it is the default for them. Each step is an equation, solved with `newton`.
"""
Base.@kwdef struct MidpointRule{N<:NewtonMethod} <: AbstractTimeStepper
    newton::N = NewtonMethod()
end

"""
    VariationalMidpoint(; newton=NewtonMethod())

The variational integrator of the midpoint discrete Lagrangian
`L_d(q₀, q₁) = Δt L(t + Δt/2, (q₀ + q₁)/2, (q₁ - q₀)/Δt)`, for Lagrangian systems, and their
default. A step solves the discrete Euler–Lagrange equation `p₀ = -∂L_d/∂q₀` for `q₁` (with
`newton`, whose `abstol` is taken relative to the size of the momenta and of `L`) and sets
`p₁ = ∂L_d/∂q₁`, the momenta `p = ∂L/∂v`; the velocities are recovered from them. Being
variational, it is symplectic and conserves the momenta of symmetries exactly (Noether's theorem
holds for the discrete equations too), and the energy error stays bounded over long times. Of
order 2.
"""
Base.@kwdef struct VariationalMidpoint{N<:NewtonMethod} <: AbstractTimeStepper
    newton::N = NewtonMethod()
end

"""
    solve(ivp::InitialValueProblem[, alg])
    solve(equation, u0, tspan[, alg]; dt, ad)

Integrate an evolution equation from `u0` over `tspan` with time step `dt`; returns a
[`Trajectory`](@ref). Without `alg`, Hamiltonian systems use the symplectic [`MidpointRule`](@ref),
Lagrangian systems the variational [`VariationalMidpoint`](@ref) and other equations
[`RungeKutta4`](@ref). With GeometricIntegrators.jl loaded, any of its
integrators can be passed, e.g. `Gauss(2)` or `SymplecticEulerA()`.

# Examples
```jldoctest
julia> sol = solve(Equation(∂ₜ, (t, u) -> -u), 1.0, (0.0, 1.0); dt=0.1);

julia> isapprox(sol.u[end], exp(-1); rtol=1e-6)
true
```
"""
CommonSolve.solve(ivp::InitialValueProblem) = solve(ivp, default_algorithm(ivp))
CommonSolve.solve(equation::Relation, u0, tspan::Tuple{Real,Real}, args...; dt::Real, ad=AutoFiniteDiff(), kwargs...) =
    solve(InitialValueProblem(equation, u0, tspan; dt, ad), args...; kwargs...)

default_algorithm(ivp::InitialValueProblem) =
    ishamiltonian(ivp) ? MidpointRule() : islagrangian(ivp) ? VariationalMidpoint() : RungeKutta4()

# The time grid t0, t0 + dt, …, up to t1 (the last step is shortened to end exactly at t1).
function _times(ivp::InitialValueProblem)
    t0, t1 = ivp.tspan
    n = ceil(Int, (t1 - t0) / ivp.dt - sqrt(eps(t1)))
    return [min(t0 + i * ivp.dt, t1) for i in 0:n]
end

function _integrate(step, ivp::InitialValueProblem, alg)
    f = vector_field(ivp)
    ts = _times(ivp)
    xs = [_state(ivp)]
    for i in 1:length(ts)-1
        x = step(f, ts[i], ts[i+1] - ts[i], xs[end])
        x === nothing && return Trajectory(ts[1:i], [_unstate(x, ivp) for x in xs], :Failure, alg)
        push!(xs, x)
    end
    return Trajectory(ts, [_unstate(x, ivp) for x in xs], :Success, alg)
end

function CommonSolve.solve(ivp::InitialValueProblem, alg::RungeKutta4)
    return _integrate(ivp, alg) do f, t, h, x
        k1 = f(t, x)
        k2 = f(t + h / 2, x + h / 2 * k1)
        k3 = f(t + h / 2, x + h / 2 * k2)
        k4 = f(t + h, x + h * k3)
        x + h / 6 * (k1 + 2k2 + 2k3 + k4)
    end
end

function CommonSolve.solve(ivp::InitialValueProblem, alg::MidpointRule)
    return _integrate(ivp, alg) do f, t, h, x
        step = Equation(y -> y - x - h * f(t + h / 2, (x + y) / 2), 0)
        sol = solve(step, x + h * f(t, x), alg.newton)
        sol.retcode === :Success ? sol.u : nothing
    end
end

function CommonSolve.solve(ivp::InitialValueProblem, alg::VariationalMidpoint)
    islagrangian(ivp) || throw(ArgumentError("VariationalMidpoint integrates Lagrangian systems, Equation(∂ₜ, Lagrangian(L))"))
    L = _lagrangian(ivp)
    n = length(ivp.u0.q)
    momentum(t, q, v) = _gradient(w -> L(t, q, w), v, ivp.ad)
    ts = _times(ivp)
    x = _state(ivp)
    q, v = x[1:n], x[n+1:end]
    p = momentum(ts[1], q, v)
    xs = [x]
    for i in 1:length(ts)-1
        t, h = ts[i], ts[i+1] - ts[i]
        # the discrete Lagrangian and its derivatives with respect to q₀ and q₁
        Ld(y) = h * L(t + h / 2, (y[1:n] + y[n+1:end]) / 2, (y[n+1:end] - y[1:n]) / h)
        D(q₀, q₁) = _gradient(Ld, vcat(q₀, q₁), ivp.ad)
        # the residuals are differences of momenta, whose (finite-difference) errors scale with
        # the momenta and with L itself: so does their tolerance
        newton = _scaled(alg.newton, max(1, norm(p), abs(L(t, q, v))))
        step = solve(Equation(q₁ -> p + D(q, q₁)[1:n], 0), q + h * v, newton)
        step.retcode === :Success || return Trajectory(ts[1:i], [_unstate(x, ivp) for x in xs], :Failure, alg)
        q₁ = step.u
        p = D(q, q₁)[n+1:end]
        # the velocity that has this momentum: solve ∂L/∂v = p
        legendre = solve(Equation(w -> momentum(ts[i+1], q₁, w), p), (q₁ - q) / h, newton)
        legendre.retcode === :Success || return Trajectory(ts[1:i], [_unstate(x, ivp) for x in xs], :Failure, alg)
        q, v = q₁, legendre.u
        push!(xs, vcat(q, v))
    end
    return Trajectory(ts, [_unstate(x, ivp) for x in xs], :Success, alg)
end

_scaled(newton::NewtonMethod, scale) = NewtonMethod(newton.ad, newton.abstol * scale, newton.maxiters, newton.linesearch)

module EquationsGeometricIntegratorsExt

using Equations: Equations, InitialValueProblem, Trajectory, ishamiltonian, islagrangian, vector_field
using GeometricIntegrators: GeometricIntegrators, GeometricMethod, ODEProblem, HODEProblem, LODEProblem, integrate
using CommonSolve: CommonSolve

# Integrate with any method of GeometricIntegrators.jl: Hamiltonian systems as HODEs (for the
# symplectic methods), Lagrangian systems as LODEs (for the variational methods, e.g. VPRKGauss),
# other evolution equations as ODEs.
function CommonSolve.solve(ivp::InitialValueProblem, method::GeometricMethod)
    f = vector_field(ivp)
    x0 = Equations._state(ivp)
    tspan, dt = ivp.tspan, ivp.dt
    # GeometricIntegrators takes whole steps of dt, so dt must divide the time span to end at t1
    steps = (tspan[2] - tspan[1]) / dt
    abs(steps - round(steps)) <= 1e-8 * max(1, steps) || throw(ArgumentError(
        "GeometricIntegrators takes whole time steps: dt = $dt must divide the time span $tspan"))
    if islagrangian(ivp)
        xs = _integrate_lode(ivp, method)
        ts = collect(range(tspan[1], tspan[2]; length=length(xs)))
        return Trajectory(ts, [Equations._unstate(x, ivp) for x in xs], :Success, method)
    elseif ishamiltonian(ivp)
        n = length(ivp.u0.q)
        rhs = ivp.equation.rhs
        scalar = ivp.u0.q isa Number
        v!(v, t, q, p, params) = (v .= f(t, vcat(q, p))[1:n])
        f!(g, t, q, p, params) = (g .= f(t, vcat(q, p))[n+1:end])
        H(t, q, p, params) = scalar ? rhs(t, q[1], p[1]) : rhs(t, q, p)
        prob = HODEProblem(v!, f!, H, tspan, dt, x0[1:n], x0[n+1:end])
        sol = integrate(prob, method)
        xs = [vcat(sol.q[i], sol.p[i]) for i in _indices(sol.q)]
    else
        prob = ODEProblem((v, t, x, params) -> (v .= f(t, x)), tspan, dt, x0)
        sol = integrate(prob, method)
        xs = [copy(sol.q[i]) for i in _indices(sol.q)]
    end
    ts = [sol.t[i] for i in _indices(sol.t)]
    return Trajectory(ts, [Equations._unstate(x, ivp) for x in xs], :Success, method)
end

# A Lagrangian system as an LODE in (q, p), with the momenta p = ϑ(t, q, v) = ∂L/∂v and the forces
# f = ∂L/∂q; the velocities of the result are recovered from the momenta.
function _integrate_lode(ivp::InitialValueProblem, method)
    L = Equations._lagrangian(ivp)
    n = length(ivp.u0.q)
    x0 = Equations._state(ivp)
    t0 = ivp.tspan[1]
    # GeometricIntegrators differentiates ϑ and f with its own dual numbers; for those, finite
    # differences (which pass dual numbers through) replace the backend of the problem, since
    # ForwardDiff cannot nest inside untagged dual numbers. At plain floats, the backend is used.
    backend(x) = eltype(x) <: AbstractFloat ? ivp.ad : Equations.AutoFiniteDiff()
    momentum(t, q, v) = Equations._gradient(w -> L(t, q, w), v, backend(v))
    velocity(t, q, p, guess) = Equations.solve(Equations.Equation(w -> momentum(t, q, w), p), guess).u
    ϑ(p, t, q, v, params) = (p .= momentum(t, q, v))
    f(g, t, q, v, params) = (g .= Equations._gradient(y -> L(t, y, v), q, backend(q)))
    # the two-form on (q, v): [∂ϑᵢ/∂qⱼ - ∂ϑⱼ/∂qᵢ  -Mᵀ; M  0], with M = ∂ϑ/∂v = ∂²L/∂v²
    function ω(Ω, t, q, v, params)
        K = Equations._hessian(x -> L(t, x[1:n], x[n+1:end]), vcat(q, v), backend(q))
        A, M = K[n+1:end, 1:n], K[n+1:end, n+1:end]
        Ω .= [A-A' -M'; M zero(M)]
    end
    l(t, q, v, params) = L(t, q, v)
    v̄(v, t, q, p, params) = (v .= velocity(t, q, p, collect(v)))
    q0, v0 = x0[1:n], x0[n+1:end]
    prob = LODEProblem(ϑ, f, ω, l, ivp.tspan, ivp.dt, q0, momentum(t0, q0, v0); v̄=v̄)
    # finite-difference derivatives leave a residual of about 1e-11, above the default tolerance
    options = ivp.ad isa Equations.AutoFiniteDiff ? (f_abstol=1e-10,) : (;)
    sol = integrate(prob, method; options...)
    qs = [copy(sol.q[i]) for i in _indices(sol.q)]
    ps = [copy(sol.p[i]) for i in _indices(sol.p)]
    ts = [sol.t[i] for i in _indices(sol.t)]
    vs = [v0]
    for i in 2:length(qs)
        push!(vs, velocity(ts[i], qs[i], ps[i], vs[end]))
    end
    return [vcat(q, v) for (q, v) in zip(qs, vs)]
end

# The data series of GeometricIntegrators are indexed from 0.
_indices(series) = firstindex(series):lastindex(series)

end

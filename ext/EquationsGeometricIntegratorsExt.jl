module EquationsGeometricIntegratorsExt

using Equations: Equations, InitialValueProblem, Trajectory, ishamiltonian, vector_field
using GeometricIntegrators: GeometricIntegrators, GeometricMethod, ODEProblem, HODEProblem, integrate
using CommonSolve: CommonSolve

# Integrate with any method of GeometricIntegrators.jl: Hamiltonian systems as HODEs (for the
# symplectic and variational methods), other evolution equations as ODEs.
function CommonSolve.solve(ivp::InitialValueProblem, method::GeometricMethod)
    f = vector_field(ivp)
    x0 = Equations._state(ivp)
    tspan, dt = ivp.tspan, ivp.dt
    # GeometricIntegrators takes whole steps of dt, so dt must divide the time span to end at t1
    steps = (tspan[2] - tspan[1]) / dt
    abs(steps - round(steps)) <= 1e-8 * max(1, steps) || throw(ArgumentError(
        "GeometricIntegrators takes whole time steps: dt = $dt must divide the time span $tspan"))
    if ishamiltonian(ivp)
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

# The data series of GeometricIntegrators are indexed from 0.
_indices(series) = firstindex(series):lastindex(series)

end

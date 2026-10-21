@testset "Evolution equations" begin
    decay = Equation(∂ₜ, (t, u) -> -u)
    oscillator = Equation(∂ₜ, Hamiltonian((t, q, p) -> p^2 / 2 + q^2 / 2))
    energy(u) = u.p^2 / 2 + u.q^2 / 2

    @testset "Problems" begin
        ivp = InitialValueProblem(decay, 1.0, (0, 1); dt=0.1)
        @test ivp.tspan === (0.0, 1.0) && ivp.dt === 0.1
        @test default_algorithm(ivp) isa RungeKutta4
        @test default_algorithm(InitialValueProblem(oscillator, (q=1.0, p=0.0), (0, 1); dt=0.1)) isa MidpointRule
        @test vector_field(ivp)(0.0, [2.0]) == [-2.0]
        @test vector_field(InitialValueProblem(oscillator, (q=1.0, p=0.0), (0, 1); dt=0.1))(0.0, [1.0, 0.0]) ≈ [0.0, -1.0] atol = 1e-8
        @test_throws ArgumentError InitialValueProblem(Equation(x -> x, 1), 1.0, (0, 1); dt=0.1)
        @test_throws ArgumentError InitialValueProblem(oscillator, 1.0, (0, 1); dt=0.1)
        @test_throws DimensionMismatch InitialValueProblem(oscillator, (q=[1.0, 0.0], p=[0.0]), (0, 1); dt=0.1)
        @test_throws ArgumentError InitialValueProblem(decay, 1.0, (1, 0); dt=0.1)
        @test_throws ArgumentError InitialValueProblem(decay, 1.0, (0, 1); dt=-0.1)
        @test_throws ArgumentError InitialValueProblem(decay, (0, 1), (0, 1); dt=0.1)
        @test sprint(show, decay) == "∂ₜu = f(t, u)"
        @test sprint(show, Equation(∂ₜ, hypot)) == "∂ₜu = hypot(t, u)"
        @test sprint(show, oscillator) == "∂ₜu = J∇H(q, p)"
        @test startswith(sprint(show, MIME"text/plain"(), ivp), "InitialValueProblem from t = 0.0 to 1.0 with dt = 0.1")
    end

    @testset "RungeKutta4" begin
        sol = solve(decay, 1.0, (0.0, 1.0); dt=0.1)
        @test sol isa Trajectory
        @test sol.retcode === :Success && sol.alg isa RungeKutta4
        @test sol.t ≈ 0:0.1:1
        @test sol.u[end] ≈ exp(-1) rtol = 1e-6
        # fourth order: halving the step divides the error by about 16
        e1 = abs(solve(decay, 1.0, (0.0, 1.0); dt=0.2).u[end] - exp(-1))
        e2 = abs(solve(decay, 1.0, (0.0, 1.0); dt=0.1).u[end] - exp(-1))
        @test 12 < e1 / e2 < 20
        # the last step is shortened to end at t1
        @test solve(decay, 1.0, (0.0, 1.0); dt=0.3).t ≈ [0, 0.3, 0.6, 0.9, 1.0]
        # vectors and named unknowns, time-dependent fields
        rot = solve(Equation(∂ₜ, (t, u) -> [u[2], -u[1]]), [1.0, 0.0], (0.0, π); dt=0.01)
        @test rot.u[end] ≈ [-1, 0] atol = 1e-8
        named = solve(Equation(∂ₜ, (t, u) -> (x=u.y, y=-u.x)), (x=1.0, y=0.0), (0.0, π); dt=0.01)
        @test named.u[end] isa NamedTuple{(:x, :y)}
        @test named.u[end].x ≈ -1 atol = 1e-8
        @test solve(Equation(∂ₜ, (t, u) -> t), 0.0, (0.0, 2.0); dt=0.5).u[end] ≈ 2
        @test startswith(sprint(show, MIME"text/plain"(), sol), "Trajectory (RungeKutta4, retcode: Success, 10 steps")
    end

    @testset "MidpointRule" begin
        sol = solve(oscillator, (q=1.0, p=0.0), (0.0, 2π); dt=0.05)
        @test sol.alg isa MidpointRule
        @test sol.u[end].q ≈ 1 atol = 1e-2
        # the midpoint rule conserves quadratic energies; RK4 slowly loses them
        long = (0.0, 500.0)
        mid = solve(oscillator, (q=1.0, p=0.0), long; dt=0.5)
        rk = solve(oscillator, (q=1.0, p=0.0), long, RungeKutta4(); dt=0.5)
        @test maximum(u -> abs(energy(u) - 0.5), mid.u) < 1e-6
        @test abs(energy(rk.u[end]) - 0.5) > 1e-2
        # vector unknowns: the Kepler problem keeps its angular momentum
        kepler = Equation(∂ₜ, Hamiltonian((t, q, p) -> sum(abs2, p) / 2 - 1 / sqrt(sum(abs2, q))))
        orbit = solve(kepler, (q=[1.0, 0.0], p=[0.0, 1.2]), (0.0, 20.0); dt=0.01)
        L(u) = u.q[1] * u.p[2] - u.q[2] * u.p[1]
        @test maximum(u -> abs(L(u) - 1.2), orbit.u) < 1e-6
        # ODEs too
        @test solve(decay, 1.0, (0.0, 1.0), MidpointRule(); dt=0.01).u[end] ≈ exp(-1) rtol = 1e-4
    end

    @testset "Lagrangian systems" begin
        harmonic = Equation(∂ₜ, Lagrangian((t, q, v) -> v^2 / 2 - q^2 / 2))
        @test sprint(show, harmonic) == "d/dt ∂L/∂v = ∂L/∂q"
        prob = InitialValueProblem(harmonic, (q=1.0, v=0.0), (0.0, 2π); dt=0.01)
        @test default_algorithm(prob) isa VariationalMidpoint
        @test_throws ArgumentError InitialValueProblem(harmonic, (q=1.0, p=0.0), (0.0, 1.0); dt=0.1)
        @test_throws DimensionMismatch InitialValueProblem(harmonic, (q=[1.0], v=[0.0, 1.0]), (0.0, 1.0); dt=0.1)
        @test_throws ArgumentError solve(oscillator, (q=1.0, p=0.0), (0.0, 1.0), VariationalMidpoint(); dt=0.1)

        # the variational integrator, the default: one period of the harmonic oscillator, order 2
        sol = solve(prob)
        @test sol.alg isa VariationalMidpoint
        @test sol.retcode === :Success
        @test sol.u[1] == (q=1.0, v=0.0)
        @test sol.u[end].q ≈ 1 atol = 1e-6
        @test sol.u[end].v ≈ 0 atol = 1e-4
        errors = [abs(solve(harmonic, (q=1.0, v=0.0), (0.0, 1.0); dt).u[end].q - cos(1)) for dt in (0.1, 0.05)]
        @test 3.5 < errors[1] / errors[2] < 4.5

        # the Euler–Lagrange equations as a first-order system: RK4 and the midpoint rule on them
        @test vector_field(prob)(0.0, [0.3, 0.5]) ≈ [0.5, -0.3] atol = 1e-7
        @test solve(prob, RungeKutta4()).u[end].q ≈ 1 atol = 1e-7
        @test solve(prob, MidpointRule()).u[end].q ≈ 1 atol = 1e-5

        # a time-dependent Lagrangian: e^{γt}(v²/2 - q²/2) is the damped oscillator q̈ + γq̇ + q = 0
        γ = 0.2
        ω = sqrt(1 - γ^2 / 4)
        damped = Equation(∂ₜ, Lagrangian((t, q, v) -> exp(γ * t) * (v^2 / 2 - q^2 / 2)))
        exact = exp(-γ * 5 / 2) * (cos(5ω) + γ / 2ω * sin(5ω))
        @test solve(damped, (q=1.0, v=0.0), (0.0, 5.0); dt=0.01).u[end].q ≈ exact atol = 1e-4
        @test solve(damped, (q=1.0, v=0.0), (0.0, 5.0), RungeKutta4(); dt=0.01).u[end].q ≈ exact atol = 1e-7

        # vector unknowns: a central force conserves the angular momentum, exactly for the
        # variational integrator (Noether's theorem holds for the discrete equations)
        central = Equation(∂ₜ, Lagrangian((t, q, v) -> sum(abs2, v) / 2 + 1 / sqrt(sum(abs2, q))))
        orbit = solve(central, (q=[1.0, 0.0], v=[0.0, 1.2]), (0.0, 50.0); dt=0.05)
        @test orbit.u[end] isa NamedTuple{(:q, :v)}
        Lz(u) = u.q[1] * u.v[2] - u.q[2] * u.v[1]
        @test maximum(u -> abs(Lz(u) - 1.2), orbit.u) < 1e-8

        # a bounded energy error over a long time
        pendulum = Equation(∂ₜ, Lagrangian((t, q, v) -> v^2 / 2 + cos(q)))
        E(u) = u.v^2 / 2 - cos(u.q)
        long = solve(pendulum, (q=1.0, v=0.0), (0.0, 500.0); dt=0.1)
        @test maximum(u -> abs(E(u) - E(long.u[1])), long.u) < 1e-3
    end
end

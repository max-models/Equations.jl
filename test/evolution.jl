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
end

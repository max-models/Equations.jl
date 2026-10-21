module GeometricIntegratorsExtTests

using Equations, GeometricIntegrators, ForwardDiff, Test

@testset "GeometricIntegrators" begin
    oscillator = Equation(∂ₜ, Hamiltonian((t, q, p) -> p^2 / 2 + q^2 / 2))
    energy(u) = u.p^2 / 2 + u.q^2 / 2
    for method in (Gauss(2), ImplicitMidpoint(), SymplecticEulerA(), LobattoIIIAIIIB(2), RK4())
        sol = solve(oscillator, (q=1.0, p=0.0), (0.0, 10.0), method; dt=0.1, ad=AutoForwardDiff())
        @test sol isa Trajectory
        @test sol.alg === method
        @test sol.t ≈ 0:0.1:10
        @test length(sol.u) == length(sol.t)
        @test sol.u[1] == (q=1.0, p=0.0)
        @test sol.u[end].q ≈ cos(10) atol = 0.05
    end
    # Gauss–Legendre with 2 stages has order 4
    @test solve(oscillator, (q=1.0, p=0.0), (0.0, 10.0), Gauss(2); dt=0.1, ad=AutoForwardDiff()).u[end].q ≈ cos(10) atol = 1e-5
    # symplectic: bounded energy error over a long time
    long = solve(oscillator, (q=1.0, p=0.0), (0.0, 1000.0), SymplecticEulerA(); dt=0.1, ad=AutoForwardDiff())
    @test maximum(u -> abs(energy(u) - 0.5), long.u) < 0.06
    # vector unknowns
    kepler = Equation(∂ₜ, Hamiltonian((t, q, p) -> sum(abs2, p) / 2 - 1 / sqrt(sum(abs2, q))))
    orbit = solve(kepler, (q=[1.0, 0.0], p=[0.0, 1.0]), (0.0, 2π), Gauss(2); dt=2π / 600, ad=AutoForwardDiff())
    @test orbit.u[end].q ≈ [1, 0] atol = 1e-4
    # GeometricIntegrators takes whole steps, so dt must divide the time span
    @test_throws ArgumentError solve(oscillator, (q=1.0, p=0.0), (0.0, 1.0), Gauss(2); dt=0.3)
    # ODEs
    @test solve(Equation(∂ₜ, (t, u) -> -u), 1.0, (0.0, 1.0), RK4(); dt=0.1).u[end] ≈ exp(-1) rtol = 1e-6
    named = solve(Equation(∂ₜ, (t, u) -> (x=u.y, y=-u.x)), (x=1.0, y=0.0), (0.0, π), Gauss(2); dt=π / 300)
    @test named.u[end] isa NamedTuple{(:x, :y)}
    @test named.u[end].x ≈ -1 atol = 1e-8

    # Lagrangian systems as LODEs, for the variational integrators
    harmonic = Equation(∂ₜ, Lagrangian((t, q, v) -> v^2 / 2 - q^2 / 2))
    for ad in (AutoFiniteDiff(), AutoForwardDiff()), method in (VPRKGauss(1), VPRKGauss(2), Gauss(2))
        sol = solve(harmonic, (q=1.0, v=0.0), (0.0, 2π), method; dt=2π / 600, ad)
        @test sol.alg === method
        @test length(sol.t) == length(sol.u) == 601
        @test sol.u[1] == (q=1.0, v=0.0)
        @test sol.u[end].q ≈ 1 atol = 1e-8
        @test sol.u[end].v ≈ 0 atol = 1e-4
    end
    # order 4 with two stages, to rounding with exact derivatives
    @test solve(harmonic, (q=1.0, v=0.0), (0.0, 2π), VPRKGauss(2); dt=2π / 600, ad=AutoForwardDiff()).u[end].v ≈ 0 atol = 1e-9
    # vector unknowns: the angular momentum of a central force
    central = Equation(∂ₜ, Lagrangian((t, q, v) -> sum(abs2, v) / 2 + 1 / sqrt(sum(abs2, q))))
    orbit = solve(central, (q=[1.0, 0.0], v=[0.0, 1.2]), (0.0, 20.0), VPRKGauss(2); dt=0.05, ad=AutoForwardDiff())
    Lz(u) = u.q[1] * u.v[2] - u.q[2] * u.v[1]
    @test maximum(u -> abs(Lz(u) - 1.2), orbit.u) < 1e-8
end

end

@testset "solve" begin
    sol = solve(Equation(x -> x^2, 2), 1.0)
    @test sol.retcode === :Success
    @test sol.u ≈ √2
    @test sol.u isa Float64
    @test sol.residual_norm <= 1e-10

    sys = EquationSystem(Equation(x -> x[1]^2 + x[2]^2, 1), Equation(x -> x[1], x -> x[2]))
    sol = solve(sys, [1.0, 0.5])
    @test sol.retcode === :Success
    @test sol.u ≈ [1, 1] / √2

    # integer starting points are promoted
    @test solve(Equation(x -> x^3, 8), 1).u ≈ 2

    # overdetermined but consistent: Gauss-Newton
    over = EquationSystem(Equation(x -> x[1], 1), Equation(x -> 2x[1], 2))
    @test solve(over, [0.0]).u ≈ [1.0]

    # no real root
    sol = solve(Equation(x -> x^2, -1), 1.0, NewtonMethod(maxiters=5))
    @test sol.retcode === :MaxIters
    @test sol.iterations == 5

    @test_throws ArgumentError solve(Relation(<=, x -> x, 1), 0.0)

    J = Equations.jacobian(x -> [x[1]^2, x[1] * x[2]], [2.0, 3.0], AutoFiniteDiff())
    @test J ≈ [4 0; 3 2] atol = 1e-6
end

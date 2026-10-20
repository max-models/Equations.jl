module NonlinearSolveExtTests

using Equations, NonlinearSolve, Test

@testset "NonlinearSolve" begin
    sys = EquationSystem(Equation(x -> x[1]^2 + x[2]^2, 1), Equation(x -> x[1], x -> x[2]))
    for alg in (NewtonRaphson(), TrustRegion())
        sol = solve(sys, [1.0, 0.5], alg)
        @test sol isa Solution
        @test sol.retcode === :Success
        @test sol.u ≈ [1, 1] / √2
        @test sol.iterations > 0
    end
    sol = solve(Equation(x -> x^2, 2), 1.0, NewtonRaphson())
    @test sol.u isa Float64 && sol.u ≈ √2

    over = EquationSystem(Equation(x -> x[1], 1), Equation(x -> 2x[1], 2))
    @test solve(over, [0.0], GaussNewton()).u ≈ [1.0]

    @test_throws ArgumentError solve(Relation(<=, x -> x, 1), 0.0, NewtonRaphson())
end

end

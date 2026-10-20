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

    named = solve(EquationSystem(Equation(u -> u.a + u.b, 3), Equation(u -> u.a - u.b, 1)), (a=0.0, b=0.0), NewtonRaphson())
    @test named.u.a ≈ 2 && named.u.b ≈ 1
    @test named.alg isa NonlinearSolve.SciMLBase.AbstractNonlinearAlgorithm
    @test_throws ArgumentError solve(Relation(<=, x -> x, 1), 0.0, NewtonRaphson())
    @test_throws ArgumentError solve(Equation(x -> x, 1), (0, 2), NewtonRaphson())
end

end

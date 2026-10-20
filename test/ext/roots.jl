module RootsExtTests

using Equations, Roots, Test

@testset "Roots" begin
    for alg in (Roots.Brent(), Roots.A42(), Roots.ITP(), Roots.Bisection())
        sol = solve(Equation(cos, 0), (0, 2), alg)
        @test sol.retcode === :Success
        @test sol.u ≈ π / 2
        @test sol.alg === alg
    end
    @test solve(Equation(cos, 0), (0, 2), Roots.Brent()).iterations < solve(Equation(cos, 0), (0, 2)).iterations
    sol = solve(Equation(x -> x^3, 2), 1.0, Roots.Order1())
    @test sol.u ≈ cbrt(2)
    @test solve(Equation(x -> x^2, -1), 1.0, Roots.Order1()).retcode === :Failure
    @test_throws ArgumentError solve(Equation(u -> u.x, 1), (x=0.0,), Roots.Order1())
end

end

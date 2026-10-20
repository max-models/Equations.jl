module ForwardDiffExtTests

using Equations, ForwardDiff, Test

@testset "ForwardDiff" begin
    J = Equations.jacobian(x -> [x[1]^2, x[1] * x[2]], [2.0, 3.0], AutoForwardDiff())
    @test J == [4 0; 3 2]
    sys = EquationSystem(Equation(x -> x[1]^2 + x[2]^2, 1), Equation(x -> x[1], x -> x[2]))
    sol = solve(sys, [1.0, 0.5], NewtonMethod(ad=AutoForwardDiff()))
    @test sol.retcode === :Success
    @test sol.u ≈ [1, 1] / √2
    @test solve(Equation(exp, 2), 0.0, NewtonMethod(ad=AutoForwardDiff())).u ≈ log(2)
end

end

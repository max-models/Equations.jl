module PolynomialsExtTests

using Equations, Polynomials, Test

@testset "Polynomials" begin
    p = Polynomial([-2, 0, 1])                       # x² - 2
    sol = solve(Equation(p, 0), AllRoots())
    @test sort(sol.u) ≈ [-√2, √2]
    @test sol.alg isa AllRoots
    @test sol.residual_norm < 1e-12
    # complex roots, and real=true
    q = Polynomial([1, 0, 1])                        # x² + 1
    @test sort(solve(Equation(q, 0), AllRoots()).u, by=imag) ≈ [-im, im]
    @test isempty(solve(Equation(q, 0), AllRoots(real=true)).u)
    cubic = Polynomial([0, -1, 0, 1])                # x³ - x
    @test sort(solve(Equation(cubic, 0), AllRoots(real=true)).u) ≈ [-1, 0, 1] atol = 1e-12
    # number on the left, polynomials on both sides
    @test sort(solve(Equation(2, p), AllRoots()).u) ≈ [-2, 2]
    @test sort(solve(Equation(p, Polynomial([0, 1])), AllRoots()).u) ≈ [-1, 2]
    # a polynomial side is evaluated, so the other algorithms work too
    @test residual(Equation(p, 0), 3.0) == 7
    @test solve(Equation(p, 0), 1.0).u ≈ √2
    @test solve(Equation(p, 0), (0, 2)).u ≈ √2
end

end

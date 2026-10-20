module HomotopyContinuationExtTests

# HomotopyContinuation exports its own `solve`, so Equations' is qualified here.
using Equations, HomotopyContinuation, Test

@testset "HomotopyContinuation" begin
    # circle and line: two real solutions
    sys = EquationSystem(Equation(u -> u.x^2 + u.y^2, 1), Equation(u -> u.y, u -> u.x / 2))
    sol = Equations.solve(sys, (x=0.0, y=0.0), AllRoots(real=true))
    @test sol.alg isa AllRoots
    @test length(sol.u) == 2
    @test all(s -> s isa NamedTuple{(:x, :y)}, sol.u)
    @test sort([s.x for s in sol.u]) ≈ [-2, 2] / √5
    @test sol.residual_norm < 1e-10
    # a scalar polynomial written as a function: all three complex roots
    roots = Equations.solve(Equation(x -> x^3, 8), 0.0, AllRoots()).u
    @test length(roots) == 3
    @test all(z -> z^3 ≈ 8, roots)
    @test count(z -> abs(imag(z)) < 1e-10, roots) == 1
    # vector unknowns
    vsys = EquationSystem(Equation(x -> x[1] * x[2], 1), Equation(x -> x[1] + x[2], 3))
    vs = Equations.solve(vsys, zeros(2), AllRoots(real=true)).u
    @test length(vs) == 2 && all(v -> v isa AbstractVector && v[1] * v[2] ≈ 1, vs)
end

end

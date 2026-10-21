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

    # exact gradients for feasibility and optimization
    disc = EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5))
    feasible = solve(disc, (x=-2.0, y=2.0), Feasibility(ad=AutoForwardDiff()))
    @test feasible.retcode === :Success && issatisfied(disc, feasible.u; atol=1e-10)
    opt = minimize(u -> (u.x - 2)^2 + (u.y - 1)^2, (x=0.0, y=1.0), AugmentedLagrangian(ad=AutoForwardDiff());
                   subject_to=Equation(u -> u.x^2 + u.y^2, 1))
    @test opt.retcode === :Success
    @test [opt.u.x, opt.u.y] ≈ [2, 1] / √5 atol = 1e-8

    # exact second derivatives for the Euler–Lagrange equations of a Lagrangian
    γ = 0.2
    ω = sqrt(1 - γ^2 / 4)
    damped = Equation(∂ₜ, Lagrangian((t, q, v) -> exp(γ * t) * (v^2 / 2 - q^2 / 2)))
    exact = exp(-γ * 5 / 2) * (cos(5ω) + γ / 2ω * sin(5ω))
    @test solve(damped, (q=1.0, v=0.0), (0.0, 5.0), RungeKutta4(); dt=0.01, ad=AutoForwardDiff()).u[end].q ≈ exact atol = 1e-9
    @test solve(damped, (q=1.0, v=0.0), (0.0, 5.0); dt=0.01, ad=AutoForwardDiff()).u[end].q ≈ exact atol = 1e-4
end

end

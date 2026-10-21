@testset "Feasibility" begin
    # the default for systems with inequalities
    disc = EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5))
    @test default_algorithm(EquationProblem(disc, (x=0.0, y=0.0))) isa Feasibility
    sol = solve(disc, (x=-2.0, y=2.0))
    @test sol.alg isa Feasibility
    @test sol.retcode === :Success
    @test sol.u isa NamedTuple{(:x, :y)}
    @test issatisfied(disc, sol.u; atol=1e-10)
    @test sol.residual_norm <= 1e-10

    # a feasible start is returned as it is
    start = solve(disc, (x=0.6, y=0.0))
    @test start.u == (x=0.6, y=0.0) && start.iterations == 0

    # equations and inequalities together
    mixed = EquationSystem(Equation(u -> u.x + u.y, 3), Relation(<=, u -> u.x^2 + u.y^2, 5), Relation(>=, u -> u.y, u -> u.x))
    sol = solve(mixed, (x=5.0, y=-5.0))
    @test sol.retcode === :Success
    @test issatisfied(mixed, sol.u; atol=1e-10)

    # strict inequalities hold strictly; non-strict ones may be tight
    strict = EquationSystem(Relation(>, x -> x, 2), Relation(<, x -> x, 3))
    sol = solve(strict, 0.0)
    @test sol.retcode === :Success && 2 < sol.u < 3
    tight = solve(EquationSystem(Relation(<=, x -> x, 1), Relation(>=, x -> x, 1)), 5.0)
    @test tight.retcode === :Success && tight.u ≈ 1

    # vector unknowns and Linear sides
    region = EquationSystem(Relation(<=, Linear([1.0 1.0; 1.0 3.0]), [4.0, 6.0]), Relation(>=, x -> x, 0))
    sol = solve(region, [10.0, 10.0])
    @test sol.retcode === :Success
    @test issatisfied(region, sol.u; atol=1e-10)

    # where one direction has (almost) no curvature, damping must still bound the steps
    region = EquationSystem(Relation(<=, u -> u.x^2 + 4u.y^2, 4), Relation(>=, u -> u.y, u -> u.x^2 - 1),
                            Relation(>=, u -> u.x + u.y, 1))
    sol = solve(region, (x=-3.0, y=3.0))
    @test sol.retcode === :Success && issatisfied(region, sol.u; atol=1e-10)

    # no solution
    @test solve(EquationSystem(Relation(<=, x -> x, 0), Relation(>=, x -> x, 1)), 0.5).retcode === :Infeasible
    @test solve(EquationSystem(Relation(<, x -> x, 1), Relation(>, x -> x, 1)), 0.0).retcode === :Infeasible
    # a local method: a local minimum of the violation is reported as infeasible
    @test solve(EquationSystem(Relation(>=, x -> x^2, 4), Relation(<=, x -> x, 0)), 1.0).retcode === :Infeasible
    @test solve(EquationSystem(Relation(>=, x -> x^2, 4), Relation(<=, x -> x, 0)), -1.0).retcode === :Success

    @test_throws ArgumentError solve(EquationSystem(Relation(!=, x -> x, 1), Relation(<=, x -> x, 2)), 0.0)
    @test_throws ArgumentError solve(disc, (0, 1))
    # algorithms for equations reject inequalities
    @test_throws ArgumentError solve(disc, (x=0.0, y=0.0), NewtonMethod())
end

@testset "minimize and maximize" begin
    # unconstrained: the Rosenbrock function
    opt = minimize(u -> (1 - u[1])^2 + 100 * (u[2] - u[1]^2)^2, [-1.2, 1.0])
    @test opt isa Optimum
    @test opt.alg isa AugmentedLagrangian
    @test opt.retcode === :Success
    @test opt.u ≈ [1, 1] atol = 1e-6
    @test opt.violation == 0

    # an inequality constraint that is active at the optimum
    opt = minimize(u -> (u.x - 1)^2 + (u.y - 2)^2, (x=0.0, y=0.0); subject_to=Relation(<=, u -> u.x + u.y, 1))
    @test opt.retcode === :Success
    @test opt.u.x ≈ 0 atol = 1e-6
    @test opt.u.y ≈ 1 atol = 1e-6
    @test opt.objective ≈ 2 atol = 1e-6
    @test opt.violation <= 1e-8

    # an inactive one: the unconstrained minimum
    opt = minimize(u -> (u.x - 1)^2 + (u.y - 2)^2, (x=0.0, y=0.0); subject_to=Relation(<=, u -> u.x + u.y, 10))
    @test opt.u.x ≈ 1 atol = 1e-6
    @test opt.u.y ≈ 2 atol = 1e-6

    # an equation: the closest point on the unit circle to (2, 1)
    opt = minimize(u -> (u.x - 2)^2 + (u.y - 1)^2, (x=0.0, y=1.0); subject_to=Equation(u -> u.x^2 + u.y^2, 1))
    @test [opt.u.x, opt.u.y] ≈ [2, 1] / √5 atol = 1e-6

    # an equation and an active inequality on different scales: the can of least metal with r ≤ 3
    can = minimize(u -> 2π * u.r^2 + 2π * u.r * u.h, (r=3.0, h=10.0);
                   subject_to=[Equation(u -> π * u.r^2 * u.h, 330), Relation(<=, u -> u.r, 3)])
    @test can.retcode === :Success
    @test can.u.r ≈ 3 atol = 1e-6
    @test can.u.h ≈ 330 / 9π rtol = 1e-6

    # maximize, with constraints given as a vector
    opt = maximize(u -> u.x * u.y, (x=1.0, y=1.0); subject_to=[Equation(u -> 2u.x + 2u.y, 20), Relation(>=, u -> u.x, 0)])
    @test opt.retcode === :Success
    @test opt.u.x ≈ 5 atol = 1e-6
    @test opt.objective ≈ 25 atol = 1e-6
    @test maximize(x -> x * (10 - x), 1.0).u ≈ 5 atol = 1e-6

    @test_throws ArgumentError minimize(x -> x^2, 1.0; subject_to=Relation(<, x -> x, 0))
    @test_throws ArgumentError minimize(x -> x^2, (0, 1))
    @test_throws ArgumentError minimize(x -> x^2, 1.0, NewtonMethod())
end

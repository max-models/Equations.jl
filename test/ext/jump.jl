module JuMPExtTests

using Equations, JuMP, Test
import HiGHS, Ipopt

@testset "JuMP" begin
    model = Model()
    @variable(model, x[1:2])
    c1 = add_constraint!(model, Relation(<=, x[1] + x[2], 1))
    c2 = add_constraint!(model, Relation(>=, 2x[1], x[2]))
    c3 = add_constraint!(model, Equation(x[1], 0.5))
    @test num_constraints(model; count_variable_in_set_constraints=true) == 3
    @test constraint_object(c1).set == MOI.LessThan(1.0)
    @test constraint_object(c2).set == MOI.GreaterThan(0.0)
    @test constraint_object(c3).set == MOI.EqualTo(0.5)

    cs = add_constraint!(model, EquationSystem(Relation(<=, x, [1, 2]), Equation(x[2], 1)))
    @test length(cs) == 2
    @test length(cs[1]) == 2
    @test_throws ArgumentError add_constraint!(model, Relation(<, x[1], 1))
    @test_throws ArgumentError add_constraint!(model, Relation(!=, x[1], 1))

    # constraints survive canonicalization
    c4 = add_constraint!(model, canonicalize(Relation(>=, x[1], 3)))
    @test constraint_object(c4).set == MOI.LessThan(-3.0)
end

@testset "JuMPSolver" begin
    # a linear program with HiGHS
    lp = maximize(u -> 3u.x + 2u.y, (x=0.0, y=0.0), JuMPSolver(HiGHS.Optimizer);
                  subject_to=[Relation(<=, u -> u.x + u.y, 4), Relation(<=, u -> u.x + 3u.y, 6),
                              Relation(>=, u -> u.x, 0), Relation(>=, u -> u.y, 0)])
    @test lp isa Optimum
    @test lp.retcode === :Success
    @test lp.u.x ≈ 4 && abs(lp.u.y) < 1e-9
    @test lp.objective ≈ 12
    @test lp.violation < 1e-9

    # vector unknowns and Linear sides
    v = minimize(x -> sum(x), zeros(2), JuMPSolver(HiGHS.Optimizer); subject_to=Relation(>=, Linear([1.0 2.0; 3.0 1.0]), [4.0, 3.0]))
    @test v.retcode === :Success
    @test v.u ≈ [0.4, 1.8]

    # nonlinear, with Ipopt: the closest point on the unit circle to (2, 1)
    nl = minimize(u -> (u.x - 2)^2 + (u.y - 1)^2, (x=0.0, y=1.0), JuMPSolver(Ipopt.Optimizer);
                  subject_to=Equation(u -> u.x^2 + u.y^2, 1))
    @test nl.retcode === :Success
    @test [nl.u.x, nl.u.y] ≈ [2, 1] / √5 atol = 1e-6
    trig = minimize(x -> sin(x), 4.0, JuMPSolver(Ipopt.Optimizer); subject_to=[Relation(>=, x -> x, 0), Relation(<=, x -> x, 6)])
    @test trig.u ≈ 3π / 2 atol = 1e-6

    # feasibility with solve
    disc = EquationSystem(Relation(<=, u -> u.x^2 + u.y^2, 1), Relation(>=, u -> u.x, 0.5))
    sol = solve(disc, (x=-2.0, y=2.0), JuMPSolver(Ipopt.Optimizer))
    @test sol isa Solution
    @test sol.retcode === :Success
    @test issatisfied(disc, sol.u; atol=1e-7)

    # infeasible and unbounded problems
    @test solve(EquationSystem(Relation(<=, x -> x, 0), Relation(>=, x -> x, 1)), 0.5, JuMPSolver(HiGHS.Optimizer)).retcode === :Infeasible
    @test minimize(x -> x, 0.0, JuMPSolver(HiGHS.Optimizer)).retcode in (:Unbounded, :Infeasible)

    @test_throws ArgumentError solve(EquationSystem(Relation(<, x -> x, 1)), 0.0, JuMPSolver(HiGHS.Optimizer))
end

end

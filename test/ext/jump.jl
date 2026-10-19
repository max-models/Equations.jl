module JuMPExtTests

using Equations, JuMP, Test

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

end

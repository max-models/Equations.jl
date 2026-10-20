@testset "EquationSystem" begin
    e1 = Equation(x -> x[1] + x[2], 3)
    e2 = Equation(x -> x[1] * x[2], 2)
    i1 = Relation(>=, x -> x[1], 0)
    sys = EquationSystem(e1, i1, e2)

    @test length(sys) == 3
    @test sys[1] === e1 && sys[end] === e2
    @test sys[[1, 3]] == EquationSystem(e1, e2)
    @test collect(sys) == [e1, i1, e2]
    @test eltype(EquationSystem) == AbstractRelation
    @test EquationSystem([e1, i1]) == EquationSystem(e1, i1)
    @test equalities(sys) == EquationSystem(e1, e2)
    @test inequalities(sys) == EquationSystem(i1)
    @test hash(EquationSystem(e1)) == hash(EquationSystem(e1))

    @test residual(sys, [1.0, 2.0]) == [0.0, 1.0, 0.0]
    @test issatisfied(sys, [1.0, 2.0])
    @test !issatisfied(sys, [-1.0, 4.0])
    @test issatisfied(sys, [1.0 + 1e-12, 2.0]; atol=1e-10)

    vsys = EquationSystem(Equation([1, 2], [1, 1]), Relation(<=, 3, 4))
    @test residual(vsys) == [0, 1, -1]
    @test !issatisfied(vsys)
    @test residual(EquationSystem()) == []

    c = canonicalize(sys)
    @test all(r -> rhs(r) == 0, c)
    @test comparison(c[2]) === LessEqual()
    @test issatisfied(c, [1.0, 2.0])

    s = EquationSystem()
    push!(s, e1, i1)
    @test length(s) == 2
end

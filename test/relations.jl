@testset "Relations" begin
    @testset "Construction" begin
        r = Relation(<=, 1, 2)
        @test r isa Relation{LessEqual}
        @test lhs(r) == 1 && rhs(r) == 2
        @test comparison(r) === LessEqual()
        @test Relation(LessEqual(), 1, 2) == r
        @test Equation(1, 2) isa Relation{EqualTo,Int,Int}
        @test Relation(≠, 1, 2) isa Relation{NotEqualTo}
        for (op, C) in ((==, EqualTo), (!=, NotEqualTo), (<, LessThan), (<=, LessEqual), (>, GreaterThan), (>=, GreaterEqual))
            @test comparison(Relation(op, 0, 0)) === C()
            @test Equations.basefunction(C()) === op
        end
    end

    @testset "Classification" begin
        @test isequality(Equation(1, 1))
        @test !isinequality(Equation(1, 1))
        @test isinequality(Relation(>, 1, 0))
        @test !isequality(Relation(!=, 1, 0)) && !isinequality(Relation(!=, 1, 0))
        @test Relation(<, 1, 2) isa Inequality
        @test !(Equation(1, 2) isa Inequality)
    end

    @testset "Equality and hashing" begin
        @test Relation(<, 1, 2) == Relation(<, 1, 2)
        @test Relation(<, 1, 2) != Relation(<=, 1, 2)
        @test Relation(<, 1, 2) != Relation(<, 2, 1)
        @test hash(Relation(<, 1, 2)) == hash(Relation(<, 1, 2))
        @test length(Set([Equation(1, 2), Equation(1, 2), Equation(2, 1)])) == 2
    end

    @testset "@relation" begin
        x = 3
        @test @relation(x^2 >= 2x) == Relation(>=, 9, 6)
        @test @relation(x ≤ 1) == Relation(<=, 3, 1)
        @test @relation(x ≠ 1) == Relation(!=, 3, 1)
        @test @relation(x == 3) isa Equation
        @test_throws Exception macroexpand(@__MODULE__, :(@relation 1 < 2 < 3))
        @test_throws Exception macroexpand(@__MODULE__, :(@relation x + 1))
    end
end

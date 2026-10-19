@testset "Operations" begin
    @testset "residual and issatisfied" begin
        @test residual(Equation(5, 3)) == 2
        @test residual(Equation([1, 2], [1, 1])) == [0, 1]
        @test residual(Relation(<=, x -> 2x, 1), 3) == 5
        @test issatisfied(Equation(1.0, 1.0 + 1e-12); atol=1e-10)
        @test !issatisfied(Equation(1.0, 1.1); atol=1e-10)
        @test issatisfied(Relation(!=, 1, 2))
        @test issatisfied(Relation(<, 1, 2)) && !issatisfied(Relation(<, 2, 2))
        @test issatisfied(Relation(<=, 2, 2)) && !issatisfied(Relation(<=, 3, 2))
        @test issatisfied(Relation(>, 3, 2)) && !issatisfied(Relation(>, 2, 2))
        @test issatisfied(Relation(>=, 2, 2)) && !issatisfied(Relation(>=, 1, 2))
        @test issatisfied(Relation(>=, 2 - 1e-12, 2); atol=1e-10)
        @test issatisfied(Relation(<=, [1, 2], [2, 2]))
        @test !issatisfied(Relation(<=, [1, 3], [2, 2]))
        circle = Relation(<=, x -> x[1]^2 + x[2]^2, 1)
        @test issatisfied(circle, [0.5, 0.5])
        @test !issatisfied(circle, [1.0, 1.0])
        @test issatisfied(Equation(sin, cos), π / 4; atol=1e-12)
    end

    @testset "reverse" begin
        @test reverse(Relation(<, 1, 2)) == Relation(>, 2, 1)
        @test reverse(Relation(>=, 1, 2)) == Relation(<=, 2, 1)
        @test reverse(Equation(1, 2)) == Equation(2, 1)
        @test reverse(Relation(!=, 1, 2)) == Relation(!=, 2, 1)
    end

    @testset "canonicalize" begin
        @test canonicalize(Equation(5, 3)) == Equation(2, 0)
        @test canonicalize(Relation(<, 1, 3)) == Relation(<, -2, 0)
        @test canonicalize(Relation(>=, 1, 3)) == Relation(<=, 2, 0)
        @test canonicalize(Relation(>, 1, 3)) == Relation(<, 2, 0)
        @test canonicalize(Relation(!=, 1, 3)) == Relation(!=, -2, 0)
        c = canonicalize(Relation(>=, x -> x^2, 4))
        @test c isa Relation{LessEqual}
        @test c.lhs(3) == 4 - 9
        @test issatisfied(c, 3) && !issatisfied(c, 1)
        v = canonicalize(Relation(<=, x -> x, [1, 2]))
        @test residual(v, [0, 0]) == [-1, -2]
    end

    @testset "Arithmetic with constants" begin
        r = Relation(<=, 1, 2)
        @test r + 1 == Relation(<=, 2, 3)
        @test 1 + r == Relation(<=, 2, 3)
        @test r - 1 == Relation(<=, 0, 1)
        @test 5 - r == Relation(>=, 4, 3)
        @test -r == Relation(>=, -1, -2)
        @test 2r == Relation(<=, 2, 4)
        @test r * -2 == Relation(>=, -2, -4)
        @test r / 2 == Relation(<=, 0.5, 1.0)
        @test r / -2 == Relation(>=, -0.5, -1.0)
        @test 0 * Equation(1, 2) == Equation(0, 0)
        @test_throws DomainError 0 * r
        @test_throws DomainError Relation(!=, 1, 2) * 0
        @test_throws DomainError Equation(1, 2) / 0
        @test Relation(!=, 1, 2) * -1 == Relation(!=, -1, -2)
        @test Equation([1, 2], [3, 4]) + 1 == Equation([2, 3], [4, 5])
        f = Relation(<=, x -> x^2, 4) * 2 + 1
        @test f isa Relation{LessEqual}
        @test residual(f, 3) == (2 * 9 + 1) - (2 * 4 + 1)
        g = Relation(<=, 1, 2) + sin
        @test residual(g, 0.3) ≈ -1
    end

    @testset "Adding relations" begin
        @test Equation(1, 2) + Equation(3, 4) == Equation(4, 6)
        @test Equation(1, 2) + Relation(<, 3, 4) == Relation(<, 4, 6)
        @test Relation(<, 3, 4) + Equation(1, 2) == Relation(<, 4, 6)
        @test Relation(<=, 1, 2) + Relation(<=, 3, 4) == Relation(<=, 4, 6)
        @test Relation(<=, 1, 2) + Relation(<, 3, 4) == Relation(<, 4, 6)
        @test Relation(>=, 1, 2) + Relation(>=, 3, 4) == Relation(>=, 4, 6)
        @test Relation(>, 1, 2) + Relation(>=, 3, 4) == Relation(>, 4, 6)
        # opposite directions: the second relation is reversed first
        @test Relation(<=, 1, 2) + Relation(>=, 4, 3) == Relation(<=, 4, 6)
        @test Relation(<=, 1, 2) - Relation(<=, 3, 4) == Relation(<=, -3, -1)
        @test_throws ArgumentError Relation(!=, 1, 2) + Equation(1, 2)
        @test_throws ArgumentError Relation(!=, 1, 2) + Relation(!=, 1, 2)
        h = Relation(<=, x -> x, 1) + Relation(<=, x -> 2x, 1)
        @test residual(h, 1) == 3 - 2
    end
end

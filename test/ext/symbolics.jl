module SymbolicsExtTests

# Symbolics also exports `Equation` and `Inequality`, so they are qualified here.
using Equations, Symbolics, Test

@testset "Symbolics" begin
    @variables x y
    r = Relation(<=, x^2 + y, 1)
    @test issatisfied(r, Dict(x => 0.5, y => 0.5))
    @test !issatisfied(r, Dict(x => 1.0, y => 0.5))
    @test residual(r, Dict(x => 1.0, y => 1.0)) == 1.0
    @test isequal(residual(Equations.Equation(x, y)), x - y)
    @test isequal(lhs(canonicalize(Relation(>=, x, y))), y - x)
    @test r == Relation(<=, x^2 + y, 1)
    @test r != Relation(<=, x^2 + y, 2)
    @test isequal(lhs(2r), 2(x^2 + y))

    eq = Symbolics.Equation(Equations.Equation(x^2, 2))
    @test eq isa Symbolics.Equation
    @test isequal(eq, x^2 ~ 2)
    @test Relation(x^2 ~ 2) == Equations.Equation(x^2, 2)

    le = Symbolics.Inequality(Relation(<=, x, 1))
    @test le isa Symbolics.Inequality && le.relational_op === Symbolics.leq
    ge = Symbolics.Inequality(Relation(>=, x, 1))
    @test ge.relational_op === Symbolics.geq
    @test Relation(x ≲ 1) == Relation(<=, x, 1)
    @test Relation(x ≳ 1) == Relation(>=, x, 1)

    @test sprint(show, Relation(<=, x^2, 1)) == "x^2 ≤ 1"
end

end

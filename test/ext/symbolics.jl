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

module ClosedFormTests

using Equations, Symbolics, Test
# Nemo and Groebner export their own `solve`; loading them is enough for symbolic_solve.
import Nemo, Groebner

@testset "ClosedForm" begin
    @variables x y
    # symbolic sides
    sol = solve(Equations.Equation(x^2, 2), x, ClosedForm())
    @test sol.alg isa ClosedForm
    @test sol.retcode === :Success
    @test isnan(sol.residual_norm)
    @test all(s -> s isa Num, sol.u)
    @test sort(Symbolics.symbolic_to_float.(sol.u)) ≈ [-√2, √2]
    @test !any(s -> Symbolics.value(s) isa AbstractFloat, sol.u)   # exact, not floating point
    @test Symbolics.symbolic_to_float.(solve(Equations.Equation(exp(x), 3), x, ClosedForm()).u) ≈ [log(3)]
    # a system with symbolic sides: one dictionary per solution
    lin = solve(EquationSystem(Equations.Equation(x + y, 3), Equations.Equation(x - y, 1)), [x, y], ClosedForm())
    @test length(lin.u) == 1
    @test isequal(lin.u[1][x], 2) && isequal(lin.u[1][y], 1)
    # function sides: the starting values name the unknowns
    @test sort(Symbolics.symbolic_to_float.(solve(Equations.Equation(z -> z^2, 2), ClosedForm()).u)) ≈ [-√2, √2]
    @test sort(Symbolics.symbolic_to_float.(solve(Equations.Equation(z -> z^3 - 2z, 0), 1.0, ClosedForm()).u)) ≈ [-√2, 0, √2]
    rect = EquationSystem(Equations.Equation(u -> u.w + u.h, 7), Equations.Equation(u -> u.w - u.h, 1))
    named = solve(rect, (w=0.0, h=0.0), ClosedForm()).u
    @test length(named) == 1 && named[1] isa NamedTuple{(:w, :h)}
    @test isequal(named[1].w, 4) && isequal(named[1].h, 3)
    vec = solve(EquationSystem(Equations.Equation(v -> v[1] + v[2], 3), Equations.Equation(v -> v[1] - v[2], 1)), zeros(2), ClosedForm()).u
    @test length(vec) == 1 && isequal(vec[1], [2, 1])
    # complex roots, and no solution at all
    @test length(solve(Equations.Equation(z -> z^2, -1), ClosedForm()).u) == 2
    @test_throws ArgumentError solve(Relation(<=, x, 1), x, ClosedForm())
    @test_throws ArgumentError solve(Equations.Equation(z -> z, 1), (0, 1), ClosedForm())
end

end

module LeanSymbolicsTests

using Equations, Symbolics, Test

@testset "Lean 4 from Symbolics" begin
    @variables x y
    @test lean(Relation(<=, x^2 + y^2, 1)) == "(x ^ 2 + y ^ 2 : ℝ) ≤ 1"
    @test lean(sin(x)^2) == "Real.sin x ^ 2"
    @test leanvariables(Relation(<=, x^2 + y^2, 1)) == [:x, :y]
    sys = EquationSystem(Equations.Equation(x + y, 3), Equations.Equation(x - y, 1))
    @test occursin("(2 + 1 : ℝ) = 3", lean_check(sys, Dict(x => 2, y => 1)))
    @test occursin("(Real.sqrt 2 ^ 2 : ℝ) = 2", lean_check(Equations.Equation(x^2, 2), Dict(x => sqrt(Num(2)))))
end

end

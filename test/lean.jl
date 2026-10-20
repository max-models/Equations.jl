@testset "Lean 4" begin
    @testset "Terms" begin
        @test lean(2) == "2"
        @test lean(-3) == "-3"
        @test lean(1 // 3) == "1 / 3"
        @test lean(4 // 2) == "2"
        @test lean(0.1) == "0.1"
        @test lean(1.0e-5) == "0.00001"
        @test lean(-2.5e10) == "-25000000000.0"
        @test lean(π) == "Real.pi"
        @test lean(:x) == "x"
        @test lean(:(x^2 + y^2)) == "x ^ 2 + y ^ 2"
        @test lean(:(sqrt(2) * exp(-t / 2))) == "Real.sqrt 2 * Real.exp (-t / 2)"
        @test lean(:(a - (b - c))) == "a - (b - c)"
        @test lean(:((a - b) - c)) == "a - b - c"
        @test lean(:(a / (b * c))) == "a / (b * c)"
        @test lean(:(x * (y + z))) == "x * (y + z)"
        @test lean(:(-(a + b))) == "-(a + b)"
        @test lean(:((-x)^2)) == "(-x) ^ 2"
        @test lean(:(-x^2)) == "-(x ^ 2)"
        @test lean(:(2^3^2)) == "2 ^ (3 ^ 2 : ℝ)"   # a computed exponent is real
        @test lean(:((2^3)^2)) == "(2 ^ 3) ^ 2"
        @test lean(:(abs(x - 1) + π)) == "|x - 1| + Real.pi"
        @test lean(:(sin(x)^2 + cos(x)^2)) == "Real.sin x ^ 2 + Real.cos x ^ 2"
        @test lean(:(log(sqrt(x)))) == "Real.log (Real.sqrt x)"
        @test lean(:(ℯ * x)) == "Real.exp 1 * x"
        # exponents: natural numbers as they are, negative integers in ℤ, everything else in ℝ
        @test lean(:(x^-1)) == "x ^ (-1 : ℤ)"
        @test lean(:(x^0.5)) == "x ^ (0.5 : ℝ)"
        @test lean(:(x^(1 // 2))) == "x ^ (1 / 2 : ℝ)"
        @test lean(:(x^(n + 1))) == "x ^ (n + 1 : ℝ)"
        @test lean(:(x^y)) == "x ^ y"
        # Base.literal_pow, as in lowered or generated code
        @test lean(Expr(:call, Base.literal_pow, ^, :x, Val(3))) == "x ^ 3"
        @test lean(Expr(:call, +, :x, 1)) == "x + 1"
        @test_throws ArgumentError lean(:(f(x)))
        @test_throws ArgumentError lean(x -> x)
        @test_throws ArgumentError lean(NaN)
        @test_throws ArgumentError lean(1 + 2im)
        @test_throws ArgumentError lean(Symbol("not a name"))
    end

    @testset "Relations" begin
        @test Relation(:(x^2 == 2)) == Relation(==, :(x^2), 2)
        @test Relation(:(x ≤ 1)) isa Relation{LessEqual}
        @test_throws ArgumentError Relation(:(x + 1))
        @test lean(Relation(:(x^2 + y^2 <= 1))) == "(x ^ 2 + y ^ 2 : ℝ) ≤ 1"
        for (op, s) in ((:(==), "="), (:!=, "≠"), (:<, "<"), (:<=, "≤"), (:>, ">"), (:>=, "≥"))
            @test lean(Relation(Expr(:call, op, :x, 0))) == "(x : ℝ) $s 0"
        end
        sys = EquationSystem(Relation(:(x + y == 3)), Relation(:(x - y == 1)))
        @test lean(sys) == "((x + y : ℝ) = 3) ∧ ((x - y : ℝ) = 1)"
        @test lean(EquationSystem()) == "True"
        @test leanvariables(EquationSystem(Relation(:(x^2 + sin(y) == π)), Relation(:(z >= 0)))) == [:x, :y, :z]
        @test leanvariables(:(exp(t) + ℯ)) == [:t]
    end

    @testset "Theorems" begin
        @test lean_theorem(Relation(:(x == 2)); name="solve_linear", hypotheses=[Relation(:(3x + 1 == 7))]) ==
              "theorem solve_linear (x : ℝ) (h₁ : (3 * x + 1 : ℝ) = 7) :\n    (x : ℝ) = 2 := by\n  sorry\n"
        many = lean_theorem(Relation(:(x == 0)); hypotheses=[Relation(Expr(:call, :(==), :x, i)) for i in 1:12])
        @test occursin("(h₁₂ : (x : ℝ) = 12)", many)
        @test startswith(lean_theorem(Relation(:(x > 0)); variables=[:x, :y]), "theorem equations (x y : ℝ) :")
        @test_throws ArgumentError lean_theorem(Relation(:(x > 0)); name="not valid")
        sys = EquationSystem(Relation(:(x + y == 3)), Relation(:(x - y == 1)))
        @test lean_check(sys, (x=2, y=1)) ==
              "theorem solution_check :\n    ((2 + 1 : ℝ) = 3) ∧ ((2 - 1 : ℝ) = 1) := by\n  norm_num\n"
        @test occursin("(Real.sqrt 2 ^ 2 : ℝ) = 2", lean_check(Relation(:(x^2 == 2)), Dict(:x => :(sqrt(2)))))
        @test occursin("(3 * (1 / 2) - 1 : ℝ)", lean_check(Relation(:(3x - 1 == 1 / 2)), (x=1 // 2,)))
        @test_throws ArgumentError lean_check(sys, (x=2,))
        file = lean_file(lean_check(sys, (x=2, y=1)))
        @test startswith(file, "import Mathlib\n\ntheorem solution_check")
        @test startswith(lean_file("theorem a : True := trivial"; imports=["Mathlib.Data.Real.Basic"]), "import Mathlib.Data.Real.Basic\n")
    end
end

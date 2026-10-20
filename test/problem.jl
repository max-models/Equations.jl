@testset "EquationProblem and algorithms" begin
    @testset "Problems" begin
        prob = EquationProblem(Equation(u -> u.x * u.y, 2), (x=1.0, y=1.0))
        @test unknowns(prob) == (:x, :y)
        @test unknowns(EquationProblem(Equation(x -> x, 1), [1.0, 2.0, 3.0])) == 3
        @test prob.system isa EquationSystem
        @test residual_function(prob)([1.0, 2.0]) == [0.0]
        @test_throws ArgumentError EquationProblem(Equation(x -> x, 1), (2, 1))
        @test_throws ArgumentError EquationProblem(Equation(x -> x, 1), (x="a",))
        @test_throws ArgumentError EquationProblem(Equation(x -> x, 1), "start")
        @test_throws ArgumentError residual_function(EquationProblem(Relation(<=, x -> x, 1), 0.0))
    end

    @testset "default_algorithm" begin
        @test default_algorithm(EquationProblem(Equation(x -> x^2, 2), (0, 2))) isa Bisection
        @test default_algorithm(EquationProblem(Equation(Linear([1 2; 3 4]), [1, 2]), zeros(2))) isa DirectLinear
        @test default_algorithm(EquationProblem(Equation(x -> x^2, 2), 1.0)) isa NewtonMethod
        # linear maps need vector unknowns, constants alone are not linear in anything
        @test default_algorithm(EquationProblem(Equation(1, 2), 1.0)) isa NewtonMethod
        @test default_algorithm(EquationProblem(Equation(Linear([1 2; 3 4]), [1, 2]), (a=0.0, b=0.0))) isa NewtonMethod
    end

    @testset "Named unknowns" begin
        circle = EquationSystem(Equation(u -> u.x^2 + u.y^2, 1), Equation(u -> u.y, u -> u.x / 2))
        sol = solve(circle, (x=1.0, y=0.0))
        @test sol.retcode === :Success
        @test sol.u isa NamedTuple{(:x, :y)}
        @test [sol.u.x, sol.u.y] ≈ [2, 1] / √5
        @test sol.alg isa NewtonMethod
    end

    @testset "Bisection" begin
        sol = solve(Equation(x -> x^2, 2), (0, 2))
        @test sol.retcode === :Success
        @test sol.alg isa Bisection
        @test abs(sol.u - √2) <= 2eps()
        @test solve(Equation(x -> x^3, 8), (0, 2)).u == 2   # root on the bracket
        @test solve(Equation(x -> x, 0), (0, 1)).u == 0
        @test solve(Equation(cos, 0), (0, 2), Bisection(abstol=1e-3)).u ≈ π / 2 atol = 1e-3
        @test solve(Equation(cos, 0), (0, 2), Bisection(maxiters=3)).retcode === :MaxIters
        @test_throws ArgumentError solve(Equation(x -> x^2, 2), (2, 3))
        @test_throws ArgumentError solve(Equation(x -> x^2, 2), 1.0, Bisection())
        @test_throws ArgumentError solve(EquationSystem(Equation(x -> x, 0), Equation(x -> x, 0)), (-1, 1))
        @test_throws ArgumentError solve(Equation(x -> x^2, 2), (0, 2), NewtonMethod())
    end

    @testset "Linear equations" begin
        A = [2.0 1.0; 1.0 3.0]
        b = [3.0, 5.0]
        sol = solve(Equation(Linear(A), b), zeros(2))
        @test sol.alg isa DirectLinear
        @test sol.u ≈ A \ b
        @test sol.iterations == 1
        @test Linear(A)([1.0, 1.0]) == A * [1.0, 1.0]
        # least squares for an overdetermined system
        C = [1.0 0.0; 0.0 1.0; 1.0 1.0]
        @test solve(Equation(Linear(C), [1.0, 1.0, 2.0]), zeros(2)).u ≈ [1, 1]
        # linear maps on both sides
        @test solve(Equation(Linear(A), Linear([1.0 0.0; 0.0 1.0])), ones(2)).u ≈ zeros(2) atol = 1e-12
        # explicitly requested for an affine function
        @test solve(Equation(x -> 2x .+ 1, [5.0]), [0.0], DirectLinear()).u ≈ [2.0]
        @test_throws ArgumentError solve(Equation(Linear(A), b), (0, 1), DirectLinear())
        # Newton solves linear equations in one step too
        @test solve(Equation(Linear(A), b), zeros(2), NewtonMethod()).u ≈ A \ b
    end

    @testset "linear_system" begin
        A = [2.0 1.0; 1.0 3.0]
        M, b = linear_system(EquationProblem(Equation(Linear(A), [3.0, 5.0]), zeros(2)))
        @test M == A && b == [3.0, 5.0]
        # both sides, constants on the left, and several equations stacked
        sys = EquationSystem(Equation(Linear([1.0 0.0]), Linear([0.0 1.0])), Equation(1.0, Linear([1.0 1.0])))
        M, b = linear_system(EquationProblem(sys, zeros(2)))
        @test M == [1.0 -1.0; -1.0 -1.0] && b == [0.0, -1.0]
        @test solve(sys, zeros(2)).u ≈ [0.5, 0.5]
        # a scalar right-hand side is applied to every row
        @test linear_system(EquationProblem(Equation(Linear([1.0 0.0; 0.0 1.0]), 2.0), zeros(2)))[2] == [2.0, 2.0]
        @test_throws ArgumentError linear_system(EquationProblem(Equation(x -> x, 1.0), 0.0))
        @test_throws DimensionMismatch linear_system(EquationProblem(Equation(Linear(A), [1.0, 2.0]), zeros(3)))
        @test_throws DimensionMismatch linear_system(EquationProblem(Equation(Linear(A), [1.0, 2.0, 3.0]), zeros(2)))
    end

    @testset "AllRoots on a bracket" begin
        sol = solve(Equation(sin, 0), (-1, 7), AllRoots())
        @test sol.u ≈ [0, π, 2π] atol = 1e-12
        @test sol.alg isa AllRoots
        @test solve(Equation(x -> (x - 1) * (x - 2) * (x - 3), 0), (0, 4), AllRoots()).u ≈ [1, 2, 3]
        @test isempty(solve(Equation(x -> x^2, -1), (-2, 2), AllRoots()).u)
        # a root exactly on a sample point
        @test solve(Equation(x -> x, 0), (-1, 1), AllRoots(samples=2)).u == [0.0]
        @test_throws ArgumentError solve(Equation(x -> x^2, 2), 1.0, AllRoots())
        @test_throws ArgumentError solve(EquationSystem(Equation(x -> x, 0), Equation(x -> x, 0)), (-1, 1), AllRoots())
    end

    @testset "ClosedForm without Symbolics" begin
        @test_throws ArgumentError Equations._closed_form(EquationProblem(Equation(x -> x, 1), 0.0), ClosedForm())
    end

    @testset "Singular Jacobian" begin
        sol = solve(Equation(x -> x^2, -1), 0.0)
        @test sol.retcode === :Failure
        @test sol.iterations == 0
    end

    @testset "Line search" begin
        # plain Newton on atan(x) = 0 diverges for |x0| > 1.39
        plain = solve(Equation(atan, 0), 3.0, NewtonMethod(linesearch=false, maxiters=20))
        @test plain.retcode !== :Success
        @test abs(plain.u) > 1
        damped = solve(Equation(atan, 0), 3.0)
        @test damped.retcode === :Success
        @test abs(damped.u) < 1e-9
    end
end

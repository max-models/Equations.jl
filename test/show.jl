@testset "show" begin
    @test sprint(show, Relation(<=, 1, 2)) == "1 ≤ 2"
    @test sprint(show, Equation(:x, 2)) == "x = 2"
    @test sprint(show, Relation(!=, 1, 2)) == "1 ≠ 2"
    @test sprint(show, Relation(>, 1, 2)) == "1 > 2"
    @test sprint(show, MIME"text/latex"(), Relation(>=, 1, 2)) == "\$1 \\geq 2\$"
    @test sprint(show, MIME"text/latex"(), Relation(!=, 1, 2)) == "\$1 \\neq 2\$"
    @test sprint(show, LessThan()) == "<"
    @test sprint(show, Equation(x -> x^2, 2)) == "f(x) = 2"
    @test sprint(show, Equation(sin, x -> x)) == "sin(x) = g(x)"
    @test sprint(show, MIME"text/latex"(), Relation(<=, cos, 1)) == "\$cos(x) \\leq 1\$"
    @test sprint(show, MIME"text/plain"(), EquationSystem(Equation(1, 2), Relation(<, 3, 4))) ==
          "EquationSystem with 2 relations:\n  1 = 2\n  3 < 4"
    @test sprint(show, MIME"text/plain"(), EquationSystem()) == "EquationSystem with 0 relations"
    @test startswith(sprint(show, MIME"text/plain"(), solve(Equation(x -> x, 1), 0.0)), "Solution (NewtonMethod, retcode: Success")
    @test sprint(show, Bisection()) == "Bisection(abstol=0.0, maxiters=1000)"
    @test sprint(show, DirectLinear()) == "DirectLinear()"
    @test sprint(show, NewtonMethod()) == "NewtonMethod(ad=AutoFiniteDiff(), abstol=1.0e-10, maxiters=100, linesearch=true)"
    @test sprint(show, Equation(Linear([1 0; 0 1]), [1, 2])) == "A*x = [1, 2]"
    @test sprint(show, MIME"text/plain"(), EquationProblem(Equation(u -> u.x, 1), (x=0.0,))) ==
          "EquationProblem with unknowns (:x,) and starting values (x = 0.0,)\nEquationSystem with 1 relation:\n  f(x) = 1"
end

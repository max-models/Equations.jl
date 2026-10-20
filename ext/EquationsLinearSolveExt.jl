module EquationsLinearSolveExt

using Equations: Equations, EquationProblem, Solution, linear_system
using LinearSolve: LinearSolve, LinearProblem
using CommonSolve: CommonSolve
using LinearAlgebra: norm

function CommonSolve.solve(prob::EquationProblem, alg::LinearSolve.SciMLLinearSolveAlgorithm; kwargs...)
    prob.u0 isa Equations.Bracket && throw(ArgumentError("LinearSolve algorithms need a starting point, not a bracket"))
    A, b = linear_system(prob)
    sol = CommonSolve.solve(LinearProblem(A, b), alg; kwargs...)
    return Solution(Equations._rebuild(sol.u, prob.u0), Symbol(sol.retcode), sol.iters, float(norm(A * sol.u - b)), alg)
end

end

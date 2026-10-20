module EquationsNonlinearSolveExt

using Equations: Equations, EquationProblem, Solution, residual_function
using NonlinearSolve: NonlinearSolve, NonlinearProblem, NonlinearLeastSquaresProblem, SciMLBase
using CommonSolve: CommonSolve
using LinearAlgebra: norm

function CommonSolve.solve(prob::EquationProblem, alg::SciMLBase.AbstractNonlinearAlgorithm; kwargs...)
    prob.u0 isa Equations.Bracket && throw(ArgumentError("NonlinearSolve algorithms need a starting point, not a bracket"))
    f = residual_function(prob)
    u0 = Equations._vector(prob.u0)
    g = (u, _) -> f(u)
    nlprob = length(f(u0)) == length(u0) ? NonlinearProblem(g, u0) : NonlinearLeastSquaresProblem(g, u0)
    sol = CommonSolve.solve(nlprob, alg; kwargs...)
    iterations = sol.stats === nothing ? -1 : Int(sol.stats.nsteps)
    return Solution(Equations._rebuild(sol.u, prob.u0), Symbol(sol.retcode), iterations, float(norm(f(sol.u))), alg)
end

end

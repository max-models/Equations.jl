module EquationsNonlinearSolveExt

using Equations: Equations, EquationSystem, Solution
using NonlinearSolve: NonlinearSolve, NonlinearProblem, NonlinearLeastSquaresProblem, SciMLBase
using CommonSolve: CommonSolve
using LinearAlgebra: norm

function CommonSolve.solve(sys::EquationSystem, x0, alg::SciMLBase.AbstractNonlinearAlgorithm; kwargs...)
    f = Equations._residual_function(sys, x0)
    u0 = x0 isa Number ? [float(x0)] : float.(collect(x0))
    g = (u, _) -> f(u)
    prob = length(f(u0)) == length(u0) ? NonlinearProblem(g, u0) : NonlinearLeastSquaresProblem(g, u0)
    sol = CommonSolve.solve(prob, alg; kwargs...)
    iterations = sol.stats === nothing ? -1 : Int(sol.stats.nsteps)
    return Solution(Equations._unwrap(sol.u, x0), Symbol(sol.retcode), iterations, float(norm(f(sol.u))))
end

end

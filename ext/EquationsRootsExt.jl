module EquationsRootsExt

using Equations: Equations, EquationProblem, Solution, residual_function
using Roots: Roots, find_zero
using CommonSolve: CommonSolve

function CommonSolve.solve(prob::EquationProblem, alg::Roots.AbstractUnivariateZeroMethod; kwargs...)
    length(prob.system) == 1 && prob.u0 isa Union{Number,Equations.Bracket} ||
        throw(ArgumentError("Roots.jl methods solve a single scalar equation from a number or a bracket (a, b)"))
    f = residual_function(prob)
    g(x) = only(f([x]))
    x0 = prob.u0 isa Number ? float(prob.u0) : float.(prob.u0)
    tracks = Roots.Tracks()
    x, retcode = try
        find_zero(g, x0, alg; tracks, kwargs...), :Success
    catch err
        err isa Roots.ConvergenceFailed || rethrow()
        NaN, :Failure
    end
    return Solution(x, retcode, tracks.steps, float(abs(g(x))), alg)
end

end

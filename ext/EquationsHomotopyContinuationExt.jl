module EquationsHomotopyContinuationExt

using Equations: Equations, EquationProblem, AllRoots, Solution, residual_function
using HomotopyContinuation: HomotopyContinuation
using LinearAlgebra: norm

const HC = HomotopyContinuation

# The function sides are evaluated on HomotopyContinuation variables, which turns polynomial
# equations written as ordinary Julia functions into a polynomial system.
function Equations._homotopy_roots(prob::EquationProblem, alg::AllRoots)
    u0 = prob.u0
    vars = u0 isa NamedTuple ? [HC.Variable(k) for k in keys(u0)] :
           u0 isa Number ? [HC.Variable(:x)] : [HC.Variable(:x, i) for i in eachindex(u0)]
    f = residual_function(prob)
    result = HC.solve(HC.System(f(vars); variables=vars); show_progress=false)
    solutions = alg.real ? HC.real_solutions(result) : HC.solutions(result)
    residual_norm = maximum(s -> norm(f(s)), solutions; init=0.0)
    return Solution([Equations._rebuild(s, u0) for s in solutions], :Success, HC.nresults(result), float(residual_norm), alg)
end

end

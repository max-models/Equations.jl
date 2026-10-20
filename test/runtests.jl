using Equations
using Test

@testset "Equations.jl" begin
    include("relations.jl")
    include("operations.jl")
    include("system.jl")
    include("problem.jl")
    include("solve.jl")
    include("evolution.jl")
    include("show.jl")
    include("doctests.jl")
    include("guide.jl")
    @testset "Extensions" begin
        include("ext/forwarddiff.jl")
        include("ext/geometricintegrators.jl")
        include("ext/jump.jl")
        include("ext/symbolics.jl")
        include("ext/nonlinearsolve.jl")
        include("ext/linearsolve.jl")
        include("ext/roots.jl")
        include("ext/polynomials.jl")
        include("ext/homotopycontinuation.jl")
    end
    include("quality.jl")
end

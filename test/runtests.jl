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
        # HomotopyContinuation runs in its own Julia process. On Julia 1.10, compiling its solver
        # after the other test packages (GeometricIntegrators, Nemo, ...) are loaded crashes LLVM
        # ("Do not know how to split the result of this operator"), which a session with only
        # Equations and HomotopyContinuation, as a user has it, never runs into.
        @testset "HomotopyContinuation (separate process)" begin
            script = joinpath(@__DIR__, "ext", "homotopycontinuation.jl")
            cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script`
            @test success(pipeline(cmd; stdout, stderr))
        end
    end
    include("quality.jl")
end

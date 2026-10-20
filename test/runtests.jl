using Equations
using Test

@testset "Equations.jl" begin
    include("relations.jl")
    include("operations.jl")
    include("system.jl")
    include("problem.jl")
    include("solve.jl")
    include("show.jl")
    include("doctests.jl")
    include("guide.jl")
    @testset "Extensions" begin
        include("ext/forwarddiff.jl")
        include("ext/jump.jl")
        include("ext/symbolics.jl")
        include("ext/nonlinearsolve.jl")
        include("ext/linearsolve.jl")
        include("ext/roots.jl")
        include("ext/polynomials.jl")
        # HomotopyContinuation runs in its own Julia process, which on Julia 1.10 compiles for
        # Haswell (AVX2) instead of the host CPU: on some GitHub runners (AVX-512 with
        # VP2INTERSECT), Julia 1.10's LLVM aborts compiling its solver for the host ("Do not know
        # how to split the result of this operator").
        @testset "HomotopyContinuation (separate process)" begin
            script = joinpath(@__DIR__, "ext", "homotopycontinuation.jl")
            cpu = VERSION < v"1.11" && Sys.ARCH === :x86_64 ? `-C haswell` : ``
            cmd = `$(Base.julia_cmd()) $cpu --startup-file=no --project=$(Base.active_project()) $script`
            @test success(pipeline(cmd; stdout, stderr))
        end
    end
    include("quality.jl")
end

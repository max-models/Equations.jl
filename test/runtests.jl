using Equations
using Test

@testset "Equations.jl" begin
    include("relations.jl")
    include("operations.jl")
    include("system.jl")
    include("solve.jl")
    include("show.jl")
    @testset "Extensions" begin
        include("ext/forwarddiff.jl")
        include("ext/jump.jl")
        include("ext/symbolics.jl")
        include("ext/nonlinearsolve.jl")
    end
    include("quality.jl")
end

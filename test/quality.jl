using Aqua
using JET

@testset "Code quality" begin
    @testset "Aqua" Aqua.test_all(Equations)
    @testset "JET" JET.test_package(Equations; target_modules=(Equations,))
end

using Aqua
using JET

@testset "Code quality" begin
    # The persistent-tasks check reads the Project.toml of every package in the test environment
    # and fails on TreeViews (a dependency of HomotopyContinuation that has none), so it is marked
    # broken: it reports as Broken, and as an error once that is fixed upstream.
    @testset "Aqua" Aqua.test_all(Equations; persistent_tasks=(; broken=true))
    @testset "JET" JET.test_package(Equations; target_modules=(Equations,))
end

using Documenter

@testset "Doctests" begin
    DocMeta.setdocmeta!(Equations, :DocTestSetup, :(using Equations); recursive=true)
    doctest(Equations; manual=false)
end

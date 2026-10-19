using Documenter
using Equations

DocMeta.setdocmeta!(Equations, :DocTestSetup, :(using Equations); recursive=true)

makedocs(;
    modules=[Equations],
    sitename="Equations.jl",
    format=Documenter.HTML(; prettyurls=get(ENV, "CI", "false") == "true"),
    pages=["Home" => "index.md", "Guide" => "guide.md", "API" => "api.md"],
)

deploydocs(; repo="github.com/max-models/Equations.jl", devbranch="main")

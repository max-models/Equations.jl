# Generate the example gallery and the API reference of the Equations.jl site, in the format of
# the max-models starlight-theme (the same components as its `starlight-gallery` tool):
#
#     src/content/docs/examples/index.mdx       grid of cards, one per example
#     src/content/docs/examples/<slug>.mdx      code and output of one example
#     public/examples/<slug>/<file>.jl          the script, for download
#     src/content/docs/api.mdx                  the docstrings
#
# Run in docs/: julia --project=. generate.jl
#
# The examples are plain Julia scripts in ../examples (subdirectories become groups). Comment
# lines starting with "# " (or a bare "#") are Markdown, everything else is code, run in order in a
# fresh module; each code chunk is shown with what it printed and its value (end a chunk with `;`
# to hide the value). The first comment block is the header:
#
#     # # Title
#     #
#     # One paragraph for the card.
#     #
#     # thumbnail: x² = 2          (optional: the text on the card)
#     # order: 3                   (optional: position in the gallery and the sidebar)
#     #
#     # More Markdown for the page.
#
# Any error in an example fails the script, so a broken example fails the build.

using Equations

const DOCS = @__DIR__
const REPO = dirname(DOCS)
const SOURCE = joinpath(REPO, "examples")
const CONTENT = joinpath(DOCS, "src", "content", "docs")
const PUBLIC = joinpath(DOCS, "public", "examples")
const PACKAGE = "@max-models/starlight-theme"

# --- MDX helpers ---------------------------------------------------------------------------------

const PROTECTED = r"(```.*?```|`[^`\n]+`|\$\$.*?\$\$|\$[^$\n]+\$)"s

"Escape the characters MDX would read as JSX or expressions, outside code and math."
function mdx_escape(text::AbstractString)
    out = IOBuffer()
    position = 1
    for m in eachmatch(PROTECTED, text)
        print(out, _escape_plain(text[position:prevind(text, m.offset)]))
        print(out, m.match)
        position = m.offset + ncodeunits(m.match)
    end
    print(out, _escape_plain(text[position:end]))
    return String(take!(out))
end
_escape_plain(s) = replace(s, "{" => "\\{", "}" => "\\}", "<" => "&lt;")

yaml_string(s) = repr(String(s))  # a double-quoted string is valid YAML

function fence(code::AbstractString, lang::AbstractString="text"; title=nothing)
    ticks = "```"
    while occursin(ticks, code)
        ticks *= "`"
    end
    meta = title === nothing ? "" : " title=$(repr(String(title)))"
    return "$ticks$lang$meta\n$(rstrip(code))\n$ticks"
end

plain(s) = strip(replace(s, r"[`*_#{}$]" => "", r"\[([^\]]+)\]\([^)]*\)" => s"\1", r"\s+" => " "))

# --- examples ------------------------------------------------------------------------------------

struct Block
    kind::Symbol  # :markdown or :code
    text::String
end

struct Example
    path::String
    slug::String
    group::String
    title::String
    summary::String
    thumbnail::Union{Nothing,String}
    order::Int
    intro::String
    blocks::Vector{Block}
end

iscomment(line) = line == "#" || startswith(line, "# ")
uncomment(line) = line == "#" ? "" : line[3:end]

function split_blocks(source::AbstractString)
    blocks = Block[]
    lines = split(chomp(source), '\n')
    i = 1
    while i <= length(lines)
        kind = iscomment(lines[i]) ? :markdown : :code
        j = i
        while j < length(lines) && (iscomment(lines[j+1]) ? :markdown : :code) == kind
            j += 1
        end
        chunk = kind === :markdown ? join(uncomment.(lines[i:j]), '\n') : join(lines[i:j], '\n')
        isempty(strip(chunk)) || push!(blocks, Block(kind, strip(chunk, '\n')))
        i = j + 1
    end
    return blocks
end

function parse_example(path)
    blocks = split_blocks(read(path, String))
    file = basename(path)
    (isempty(blocks) || blocks[1].kind !== :markdown) && error("$file: the script must start with a comment header")
    header = blocks[1].text
    m = match(r"^# (.+)$"m, header)
    m === nothing && error("$file: the header must start with a `# # Title` line")
    title = strip(m.captures[1])
    rest = strip(header[m.offset+ncodeunits(m.match):end])
    keys = Dict{String,String}()
    for k in match.(r"^(thumbnail|order):\s*(.+)$"m, split(rest, '\n'))
        k === nothing || (keys[k.captures[1]] = strip(k.captures[2]))
    end
    rest = strip(replace(rest, r"^(thumbnail|order):.*(\n|$)"m => ""))
    thumbnail = get(keys, "thumbnail", nothing)
    order = parse(Int, get(keys, "order", "1000"))
    paragraphs = split(rest, r"\n\s*\n")
    summary = plain(first(paragraphs))
    intro = strip(join(paragraphs[2:end], "\n\n"))
    dir = relpath(dirname(path), SOURCE)
    group = dir == "." ? "" : uppercasefirst(replace(dir, '_' => ' ', '-' => ' '))
    slug = replace(splitext(file)[1], '_' => '-')
    return Example(path, slug, group, title, summary, thumbnail, order, intro, blocks[2:end])
end

"Run the code chunks of `ex` in a fresh module; return (code, printed, shown value) per chunk."
function run_example(ex::Example)
    mod = Module(Symbol("Example_", replace(ex.slug, '-' => '_')))
    Core.eval(mod, :(include(path) = Base.include($mod, path)))
    results = Dict{Int,Tuple{String,String}}()
    for (i, block) in enumerate(ex.blocks)
        block.kind === :code || continue
        printed, value = mktemp() do tmp, io
            value = redirect_stdout(io) do
                include_string(mod, block.text, ex.path)
            end
            close(io)
            read(tmp, String), value
        end
        shown = if value === nothing || endswith(rstrip(block.text), ';')
            ""
        else
            # invokelatest: the example may have loaded packages that define `show` for its values
            Base.invokelatest(sprint, show, MIME"text/plain"(), value; context=(:limit => true, :displaysize => (30, 92)))
        end
        results[i] = (printed, shown)
    end
    return results
end

function write_example(ex::Example, order::Int)
    println("[examples] running ", relpath(ex.path, REPO))
    results = run_example(ex)
    public = joinpath(PUBLIC, ex.slug)
    rm(public; force=true, recursive=true)
    mkpath(public)
    cp(ex.path, joinpath(public, basename(ex.path)))
    base = "/examples/$(ex.slug)"

    parts = String[]
    isempty(ex.intro) || push!(parts, mdx_escape(ex.intro))
    for (i, block) in enumerate(ex.blocks)
        if block.kind === :markdown
            push!(parts, mdx_escape(block.text))
        else
            push!(parts, fence(block.text, "julia"))
            printed, shown = results[i]
            output = strip(join(filter(!isempty, [rstrip(printed), shown]), "\n"), '\n')
            isempty(output) || push!(parts, fence(output, "text"; title="Output"))
        end
    end
    push!(parts, "## Source code")
    push!(parts, fence(read(ex.path, String), "julia"; title=basename(ex.path)))

    text = """
    ---
    title: $(yaml_string(ex.title))
    description: $(yaml_string(ex.summary))
    sidebar:
      order: $order
    ---

    import GalleryHeader from '$PACKAGE/components/GalleryHeader.astro';

    <GalleryHeader download="$base/$(basename(ex.path))" source="$(relpath(ex.path, REPO))" status="run" />

    $(join(parts, "\n\n"))
    """
    write(joinpath(CONTENT, "examples", "$(ex.slug).mdx"), text)
    return (; title=ex.title, summary=ex.summary, href="$base/", group=ex.group, thumbnail=nothing,
        placeholder=something(ex.thumbnail, ex.title))
end

json(s::AbstractString) = "\"" * escape_string(s) * "\""
json(::Nothing) = "null"
json(x::NamedTuple) = "{" * join(("$(json(string(k))): $(json(v))" for (k, v) in pairs(x)), ", ") * "}"
json(v::AbstractVector) = "[" * join(json.(v), ", ") * "]"

function write_examples()
    paths = sort!([joinpath(root, f) for (root, _, files) in walkdir(SOURCE) for f in files if endswith(f, ".jl")])
    examples = sort!(parse_example.(paths); by=ex -> (ex.order, ex.path))
    slugs = [ex.slug for ex in examples]
    allunique(slugs) || error("example slugs must be unique: $slugs")
    mkpath(joinpath(CONTENT, "examples"))
    for stale in readdir(joinpath(CONTENT, "examples"); join=true)
        endswith(stale, ".mdx") && rm(stale)
    end
    cards = [write_example(ex, i) for (i, ex) in enumerate(examples)]
    readme = joinpath(SOURCE, "README.md")
    intro = isfile(readme) ? mdx_escape(strip(read(readme, String))) : "Examples of Equations.jl."
    write(joinpath(CONTENT, "examples", "index.mdx"), """
    ---
    title: "Examples"
    description: "Scripts that show Equations.jl at work, run when the site was built."
    tableOfContents: false
    sidebar:
      order: 0
    ---

    import GalleryGrid from '$PACKAGE/components/GalleryGrid.astro';

    $intro

    <GalleryGrid items={$(json(cards))} />
    """)
    println("[examples] wrote $(length(examples)) pages")
end

# --- API reference -------------------------------------------------------------------------------

const API_SECTIONS = [
    "Relations" => [:AbstractRelation, :Relation, :Equation, :Inequality, Symbol("@relation"),
        :Comparison, :EqualTo, :NotEqualTo, :LessThan, :LessEqual, :GreaterThan, :GreaterEqual,
        :lhs, :rhs, :comparison, :isequality, :isinequality],
    "Checking and manipulating" => [:residual, :issatisfied, :canonicalize, :reverse, :+, :*],
    "Systems" => [:EquationSystem, :equalities, :inequalities],
    "Problems" => [:EquationProblem, :unknowns, :residual_function, :Linear, :linear_system],
    "Solving" => [:solve, :default_algorithm, :Solution, :AbstractEquationAlgorithm, :NewtonMethod,
        :Bisection, :DirectLinear, :AllRoots, :ClosedForm],
    "Inequalities and optimization" => [:Feasibility, :minimize, :maximize, :Optimum, :AugmentedLagrangian,
        :JuMPSolver],
    "Evolution equations" => [:TimeDerivative, :∂ₜ, :Hamiltonian, :InitialValueProblem, :vector_field,
        :Trajectory, :AbstractTimeStepper, :RungeKutta4, :MidpointRule],
    "Integrations" => [:add_constraint!],
    "Lean 4" => [:lean, :leanvariables, :lean_theorem, :lean_check, :lean_file],
    "Internals" => [:evaluate, :jacobian, :basefunction, :flip],
]

slugify(s) = replace(lowercase(s), r"[^\p{L}\p{N}\s_-]" => "", r"\s" => "-")

# Docstrings of Base functions document only the methods for Equations' types.
const OWN_METHODS = Dict(:reverse => Base.reverse, :+ => Base.:+, :* => Base.:*)

function docstring(name::Symbol)
    f = get(OWN_METHODS, name, nothing)
    binding = f === nothing ? Docs.Binding(Equations, name) : Docs.Binding(Base, nameof(f))
    multi = get(Docs.meta(Equations), binding, nothing)
    multi === nothing && error("no docstring for $binding in Equations")
    texts = [signature_block(join(string.(multi.docs[sig].text))) for sig in multi.order]
    return join(texts, "\n\n")
end

"The indented signature lines that open a docstring, as a Julia code block."
function signature_block(text::AbstractString)
    m = match(r"^((?: {4}.*(?:\n|$))+)", text)
    m === nothing && return strip(text)
    signatures = join((line[5:end] for line in split(rstrip(m.captures[1]), '\n')), '\n')
    return fence(signatures, "julia") * "\n\n" * strip(text[ncodeunits(m.match)+1:end])
end

function api_markdown(text::AbstractString, anchors::Dict{String,String})
    text = replace(text, r"```jldoctest[^\n]*" => "```julia")
    # Documenter-style cross references: [`name`](@ref) and [text](@ref target)
    text = replace(text, r"\[([^\]]+)\]\(@ref(?:\s+([^)]+))?\)" => function (s)
        m = match(r"\[([^\]]+)\]\(@ref(?:\s+([^)]+))?\)", s)
        target = strip(something(m.captures[2], strip(m.captures[1], '`')))
        target = replace(target, r"^Equations\." => "")
        anchor = get(anchors, target, nothing)
        anchor === nothing ? m.captures[1] : "[$(m.captures[1])](#$anchor)"
    end)
    # demote headings so they sit below the entry's own heading
    text = replace(text, r"^(#+) "m => s"\1### ")
    return mdx_escape(text)
end

function write_api()
    names = [n for (_, ns) in API_SECTIONS for n in ns]
    heading(n) = n in keys(OWN_METHODS) ? "Base.$n" : string(n)
    anchors = Dict(string(n) => slugify(heading(n)) for n in names)
    exported = Set(filter(n -> n !== :Equations, Base.names(Equations)))
    missing_names = setdiff(exported, names, [:AutoFiniteDiff, :AutoForwardDiff])
    isempty(missing_names) || error("exported names missing from the API page: $(collect(missing_names))")
    parts = String[]
    for (section, ns) in API_SECTIONS
        push!(parts, "## $section")
        for n in ns
            push!(parts, "### `$(heading(n))`")
            push!(parts, api_markdown(docstring(n), anchors))
        end
    end
    write(joinpath(CONTENT, "api.mdx"), """
    ---
    title: "API reference"
    description: "The docstrings of Equations.jl."
    ---

    Everything listed under the first sections is exported; the internals are reached as
    `Equations.name` and are the extension points for other packages. `AutoFiniteDiff` and
    `AutoForwardDiff` are re-exported from [ADTypes.jl](https://github.com/SciML/ADTypes.jl).

    $(join(parts, "\n\n"))
    """)
    println("[api] wrote api.mdx")
end

write_examples()
write_api()

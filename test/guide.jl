# The `julia>` sessions in the guide pages of the site must reproduce: each input is run in a
# fresh module per page and its displayed value compared with the text below it (numbers
# approximately).

const GUIDE = joinpath(dirname(@__DIR__), "docs", "src", "content", "docs", "guide")

function repl_sessions(text)
    sessions = Tuple{String,String}[]
    for block in eachmatch(r"```julia\n(.*?)```"s, text)
        lines = split(chomp(block.captures[1]), '\n')
        startswith(first(lines), "julia> ") || continue
        i = 1
        while i <= length(lines)
            input = [lines[i][8:end]]
            i += 1
            while i <= length(lines) && startswith(lines[i], "       ")
                push!(input, lines[i][8:end])
                i += 1
            end
            output = String[]
            while i <= length(lines) && !startswith(lines[i], "julia> ")
                push!(output, lines[i])
                i += 1
            end
            push!(sessions, (join(input, '\n'), strip(join(output, '\n'))))
        end
    end
    return sessions
end

# Equal up to the numbers in them, which may differ in the last digits between platforms
# (residual norms below 1e-8 count as equal).
const NUMBER = r"-?\d+\.\d+(?:e[-+]?\d+)?"
function matches(shown, expected)
    shown == expected && return true
    replace(shown, NUMBER => "#") == replace(expected, NUMBER => "#") || return false
    a = [parse(Float64, m.match) for m in eachmatch(NUMBER, shown)]
    b = [parse(Float64, m.match) for m in eachmatch(NUMBER, expected)]
    return all(isapprox(x, y; rtol=1e-6) || max(abs(x), abs(y)) < 1e-8 for (x, y) in zip(a, b))
end

@testset "Guide sessions" begin
    for file in readdir(GUIDE; join=true)
        sessions = repl_sessions(read(file, String))
        isempty(sessions) && continue
        mod = Module()
        Core.eval(mod, :(using Equations))
        @testset "$(basename(file))" begin
            for (input, expected) in sessions
                # what the REPL would show: the printed output, then the value
                printed, value = mktemp() do path, io
                    value = redirect_stdout(() -> Core.eval(mod, Meta.parseall(input)), io)
                    close(io)
                    read(path, String), value
                end
                shown = endswith(input, ';') || value === nothing ? "" : sprint(show, MIME"text/plain"(), value)
                shown = strip(printed * shown)
                @test matches(shown, expected)
                matches(shown, expected) || println("in $(basename(file)):\n", input, "\nexpected:\n", expected, "\ngot:\n", shown)
            end
        end
    end
end

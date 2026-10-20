symbol(::EqualTo) = "="
symbol(::NotEqualTo) = "≠"
symbol(::LessThan) = "<"
symbol(::LessEqual) = "≤"
symbol(::GreaterThan) = ">"
symbol(::GreaterEqual) = "≥"

latexsymbol(::EqualTo) = "="
latexsymbol(::NotEqualTo) = "\\neq"
latexsymbol(::LessThan) = "<"
latexsymbol(::LessEqual) = "\\leq"
latexsymbol(::GreaterThan) = ">"
latexsymbol(::GreaterEqual) = "\\geq"

Base.show(io::IO, c::Comparison) = print(io, symbol(c))

# Function sides print as calls: named functions by name, anonymous ones as `f(x)` (lhs) and `g(x)` (rhs).
_side(side, _) = side
_side(f::Function, default::Symbol) = string(startswith(string(nameof(f)), '#') ? default : nameof(f), "(x)")

function Base.show(io::IO, r::Relation)
    print(io, _side(r.lhs, :f), " ", symbol(comparison(r)), " ", _side(r.rhs, :g))
end

function Base.show(io::IO, ::MIME"text/latex", r::Relation)
    print(io, "\$", _side(r.lhs, :f), " ", latexsymbol(comparison(r)), " ", _side(r.rhs, :g), "\$")
end

function Base.show(io::IO, ::MIME"text/plain", sys::EquationSystem)
    n = length(sys)
    print(io, "EquationSystem with ", n, n == 1 ? " relation" : " relations", n == 0 ? "" : ":")
    for r in sys
        print(io, "\n  ", r)
    end
end

function Base.show(io::IO, ::MIME"text/plain", sol::Solution)
    println(io, "Solution (retcode: ", sol.retcode, ", iterations: ", sol.iterations,
        ", residual norm: ", sol.residual_norm, ")")
    print(io, "u: ", sol.u)
end

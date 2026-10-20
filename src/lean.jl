# Lean 4 code generation: relations as statements about real numbers in Lean 4 with Mathlib.

"""
    Relation(ex::Expr)

The relation written by the comparison expression `ex`, with the two sides kept as unevaluated
expressions: `Relation(:(x^2 + y == 1))`. Such relations can be translated to Lean 4 with
[`lean`](@ref).
"""
function Relation(ex::Expr)
    Meta.isexpr(ex, :call, 3) && ex.args[1] in _COMPARISON_OPS ||
        throw(ArgumentError("expected a comparison `lhs op rhs`, got `$ex`"))
    op, l, r = ex.args
    return Relation(comparison(_BASE_COMPARISONS[op]), l, r)
end

const _BASE_COMPARISONS = Dict(:(==) => (==), :!= => (!=), :≠ => (!=), :< => (<), :<= => (<=), :≤ => (<=),
    :> => (>), :>= => (>=), :≥ => (>=))

leansymbol(::EqualTo) = "="
leansymbol(::NotEqualTo) = "≠"
leansymbol(::LessThan) = "<"
leansymbol(::LessEqual) = "≤"
leansymbol(::GreaterThan) = ">"
leansymbol(::GreaterEqual) = "≥"

# Julia functions and the Mathlib functions on ℝ they become.
const _LEAN_FUNCTIONS = Dict(
    :sqrt => "Real.sqrt", :exp => "Real.exp", :log => "Real.log",
    :sin => "Real.sin", :cos => "Real.cos", :tan => "Real.tan",
    :asin => "Real.arcsin", :acos => "Real.arccos", :atan => "Real.arctan",
    :sinh => "Real.sinh", :cosh => "Real.cosh", :tanh => "Real.tanh",
)
const _LEAN_CONSTANTS = Dict(:π => "Real.pi", :pi => "Real.pi", :ℯ => "Real.exp 1")

"""
    lean(x) -> String

The Lean 4 (Mathlib) term or proposition for `x`: a number, a variable name (`Symbol`), a Julia
expression (`Expr`) built from `+`, `-`, `*`, `/`, `^`, `sqrt`, `exp`, `log`, the trigonometric and
hyperbolic functions, `abs` and `π`, or a [`Relation`](@ref) or [`EquationSystem`](@ref) of them
(a system becomes a conjunction). With Symbolics.jl loaded, symbolic expressions work too.

Integers and rationals are exact; a floating-point number is written in its shortest decimal form,
which Lean reads as that exact decimal. Each relation types its left-hand side as `ℝ`, so that
numerals are real numbers. Function sides cannot be translated: write the sides as expressions.

# Examples
```jldoctest
julia> lean(Relation(:(x^2 + y^2 <= 1)))
"(x ^ 2 + y ^ 2 : ℝ) ≤ 1"

julia> lean(:(sqrt(2) * exp(-t / 2)))
"Real.sqrt 2 * Real.exp (-t / 2)"
```
"""
lean(x) = _lean(x, 0)
lean(r::Relation) = "(" * _lean(r.lhs, 0) * " : ℝ) " * leansymbol(comparison(r)) * " " * _lean(r.rhs, 0)
lean(sys::EquationSystem) = isempty(sys) ? "True" : join((length(sys) > 1 ? "(" * lean(r) * ")" : lean(r) for r in sys), " ∧ ")

# Precedences as in Lean: + and - 65, * and / 70, unary minus 75, ^ 75 (right associative),
# function application 1024. A term is parenthesized when its precedence is below `context`.
_paren(s, p, context) = p < context ? "(" * s * ")" : s

_lean(x::Integer, context) = x < 0 ? _paren(string(x), 75, context) : string(x)
_lean(x::Rational, context) = denominator(x) == 1 ? _lean(numerator(x), context) :
                              _paren(_lean(numerator(x), 70) * " / " * string(denominator(x)), 70, context)
function _lean(x::AbstractFloat, context)
    isfinite(x) || throw(ArgumentError("Lean has no real number $x"))
    s = repr(Float64(x))
    occursin('e', s) && (s = _decimal(x))
    return x < 0 ? _paren(s, 75, context) : s
end
_lean(x::Irrational{:π}, context) = "Real.pi"
_lean(x::Irrational{:ℯ}, context) = _paren("Real.exp 1", 1024, context)
_lean(x::Bool, context) = throw(ArgumentError("Lean output is for real numbers, got $x"))
_lean(x::Number, context) = throw(ArgumentError("cannot write the number $x ($(typeof(x))) in Lean"))
_lean(f::Function, context) = throw(ArgumentError(
    "function sides cannot be written in Lean; write the sides as expressions, e.g. Relation(:(x^2 == 2))"))

function _lean(s::Symbol, context)
    haskey(_LEAN_CONSTANTS, s) && return _paren(_LEAN_CONSTANTS[s], s === :ℯ ? 1024 : 2000, context)
    Base.isidentifier(s) || throw(ArgumentError("`$s` is not a valid variable name"))
    return string(s)
end

# A decimal without exponent, e.g. 1.0e-5 → 0.00001, so that Lean reads it as written.
function _decimal(x)
    s = repr(Float64(x))
    m = match(r"^(-?)(\d+)(?:\.(\d+))?e([-+]?\d+)$", s)
    m === nothing && return s
    sign, int, frac = something(m.captures[1], ""), something(m.captures[2], "0"), something(m.captures[3], "")
    ex = parse(Int, something(m.captures[4], "0"))
    digits = int * rstrip(frac, '0')
    point = length(int) + ex
    body = point <= 0 ? "0." * "0"^(-point) * digits :
           point >= length(digits) ? digits * "0"^(point - length(digits)) * ".0" :
           digits[1:point] * "." * digits[point+1:end]
    return sign * body
end

function _lean(ex::Expr, context)
    Meta.isexpr(ex, :call) || throw(ArgumentError("cannot write `$ex` in Lean"))
    f = ex.args[1]
    f isa Function && (f = nameof(f))
    args = ex.args[2:end]
    # Base.literal_pow(^, x, Val(n)), as Julia lowers x^n with a literal n
    if f === :literal_pow && length(args) == 3
        n = args[3] isa Val ? typeof(args[3]).parameters[1] :
            Meta.isexpr(args[3], :call, 2) && args[3].args[1] in (Val, :Val) ? args[3].args[2] : nothing
        n === nothing || ((f, args) = (:^, Any[args[2], n]))
    end
    if f === :+ && length(args) >= 1
        return _paren(join((_lean(a, i == 1 ? 65 : 66) for (i, a) in enumerate(args)), " + "), 65, context)
    elseif f === :- && length(args) == 1
        return _paren("-" * _lean(only(args), 76), 75, context)
    elseif f === :- && length(args) == 2
        return _paren(_lean(args[1], 65) * " - " * _lean(args[2], 66), 65, context)
    elseif f === :* && length(args) >= 1
        return _paren(join((_lean(a, i == 1 ? 70 : 71) for (i, a) in enumerate(args)), " * "), 70, context)
    elseif f in (:/, ://) && length(args) == 2
        return _paren(_lean(args[1], 70) * " / " * _lean(args[2], 71), 70, context)
    elseif f === :^ && length(args) == 2
        return _paren(_lean(args[1], 76) * " ^ " * _exponent(args[2]), 75, context)
    elseif f === :abs && length(args) == 1
        return "|" * _lean(only(args), 0) * "|"
    elseif haskey(_LEAN_FUNCTIONS, f) && length(args) == 1
        return _paren(_LEAN_FUNCTIONS[f] * " " * _lean(only(args), 1025), 1024, context)
    elseif f in keys(_BASE_COMPARISONS)
        return _paren(lean(Relation(ex)), 50, context)
    end
    throw(ArgumentError("cannot write `$ex` in Lean: unsupported function `$f`"))
end

# Exponents: natural numbers stay as they are (x ^ 2, a power in any monoid), negative integers
# are integers (x ^ (-1 : ℤ)) and everything else is real (x ^ (1 / 2 : ℝ)). Without the
# annotation Lean would compute 1 / 2 in ℕ, which is 0, and read a decimal as a Float.
_exponent(n::Integer) = n >= 0 ? string(n) : "(" * string(n) * " : ℤ)"
_exponent(s::Symbol) = _lean(s, 76)
_exponent(x) = "(" * _lean(x, 0) * " : ℝ)"

"""
    leanvariables(x) -> Vector{Symbol}

The free variables of an expression, relation or system, sorted, as they appear in its Lean
translation (function names and constants such as `π` excluded).
"""
leanvariables(x) = sort!(collect(_variables!(Set{Symbol}(), x)))
leanvariables(sys::EquationSystem) = sort!(collect(foldl((s, r) -> _variables!(s, r), sys; init=Set{Symbol}())))
_variables!(vars, r::Relation) = (_variables!(vars, r.lhs); _variables!(vars, r.rhs))
_variables!(vars, s::Symbol) = haskey(_LEAN_CONSTANTS, s) ? vars : push!(vars, s)
function _variables!(vars, ex::Expr)
    for a in (Meta.isexpr(ex, :call) ? ex.args[2:end] : ex.args)
        a isa Function && continue
        _variables!(vars, a)
    end
    return vars
end
_variables!(vars, _) = vars

"""
    lean_theorem(conclusion; name="equations", hypotheses=(), variables=leanvariables(...), proof="sorry")

A Lean 4 theorem stating that the hypotheses (relations) imply the conclusion (a relation or
system), for all real values of the variables. The proof is `proof`, by default `sorry`, which
Lean accepts with a warning, so that the statement can be checked and the proof filled in later.

# Examples
```jldoctest
julia> print(lean_theorem(Relation(:(x == 2)); name="solve_linear", hypotheses=[Relation(:(3x + 1 == 7))]))
theorem solve_linear (x : ℝ) (h₁ : (3 * x + 1 : ℝ) = 7) :
    (x : ℝ) = 2 := by
  sorry
```
"""
function lean_theorem(conclusion; name::AbstractString="equations", hypotheses=AbstractRelation[],
    variables=nothing, proof::AbstractString="sorry")
    hyps = EquationSystem(collect(AbstractRelation, hypotheses))
    goal = conclusion isa EquationSystem ? conclusion : EquationSystem(conclusion)
    vars = variables === nothing ? leanvariables(EquationSystem(vcat(hyps.relations, goal.relations))) : collect(variables)
    _check_lean_name(name)
    binders = isempty(vars) ? "" : " (" * join(string.(vars), " ") * " : ℝ)"
    hypbinders = join((" (h" * _subscript(i) * " : " * lean(r) * ")" for (i, r) in enumerate(hyps)), "")
    return "theorem $name$binders$hypbinders :\n    $(lean(goal)) := by\n  $proof\n"
end

_subscript(i) = join(Char(0x2080 + d) for d in reverse(digits(i)))

function _check_lean_name(name)
    occursin(r"^[A-Za-z_][A-Za-z0-9_'.]*$", name) || throw(ArgumentError("`$name` is not a valid Lean theorem name"))
    return nothing
end

"""
    lean_check(relations, solution; name="solution_check", proof="norm_num")

A Lean 4 theorem stating that `solution` satisfies the relations: the values of the `NamedTuple`
or `Dict` `solution` (variable name => value) are substituted for the variables, and the result is
a statement about numbers alone, which `norm_num` proves for rational values. Values can be
numbers or expressions such as `:(sqrt(2))`.

# Examples
```jldoctest
julia> sys = EquationSystem(Relation(:(x + y == 3)), Relation(:(x - y == 1)));

julia> print(lean_check(sys, (x=2, y=1)))
theorem solution_check :
    ((2 + 1 : ℝ) = 3) ∧ ((2 - 1 : ℝ) = 1) := by
  norm_num
```
"""
function lean_check(relations, solution; name::AbstractString="solution_check", proof::AbstractString="norm_num")
    sys = relations isa EquationSystem ? relations : EquationSystem(relations)
    values = Dict{Symbol,Any}(_lean_key(k) => v for (k, v) in pairs(solution))
    substituted = EquationSystem([Relation(comparison(r), _substitute(r.lhs, values), _substitute(r.rhs, values)) for r in sys])
    missing_vars = leanvariables(substituted)
    isempty(missing_vars) || throw(ArgumentError("the solution has no values for $(join(missing_vars, ", "))"))
    return lean_theorem(substituted; name, variables=Symbol[], proof)
end

_lean_key(k) = Symbol(k)
_substitute(s::Symbol, values) = get(values, s, s)
_substitute(ex::Expr, values) = Meta.isexpr(ex, :call) ?
    Expr(:call, ex.args[1], (_substitute(a, values) for a in ex.args[2:end])...) : ex
_substitute(x, values) = x

"""
    lean_file(theorems...; imports=["Mathlib"])

A Lean 4 source file with the given theorems (strings, e.g. from [`lean_theorem`](@ref) and
[`lean_check`](@ref)), preceded by the imports.
"""
lean_file(theorems::AbstractString...; imports=["Mathlib"]) =
    join(("import " * i for i in imports), "\n") * "\n\n" * join(theorems, "\n")

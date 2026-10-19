module EquationsForwardDiffExt

using Equations: Equations, AutoForwardDiff
using ForwardDiff: ForwardDiff

Equations.jacobian(f, x::AbstractVector, ::AutoForwardDiff) = ForwardDiff.jacobian(f, x)

end

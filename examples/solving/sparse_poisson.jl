# # A sparse linear system
#
# Discretise a boundary value problem and solve it with sparse direct and iterative solvers.
#
# thumbnail: −u″ = 1, u(0) = u(1) = 0
# order: 8
#
# The boundary value problem $-u''(x) = 1$ on $(0, 1)$ with $u(0) = u(1) = 0$ has the solution
# $u(x) = x(1 - x)/2$. Central differences on $n$ interior points turn it into the linear system
# $A u = h^2 \mathbf{1}$ with the tridiagonal matrix $A = \mathrm{tridiag}(-1, 2, -1)$.

using Equations
using SparseArrays

n = 200
h = 1 / (n + 1)
x = h .* (1:n)
A = spdiagm(-1 => -ones(n - 1), 0 => 2ones(n), 1 => -ones(n - 1))
poisson = Equation(Linear(A), h^2 * ones(n));

# `Linear(A)` keeps the matrix as it is, so `linear_system` hands the sparse matrix to the
# solver:

M, b = linear_system(EquationProblem(poisson, zeros(n)))
typeof(M), nnz(M)

# The default `DirectLinear` uses the sparse `\`:

sol = solve(poisson, zeros(n))
maximum(abs, sol.u - x .* (1 .- x) ./ 2)

# ## LinearSolve.jl
#
# With LinearSolve.jl loaded, any of its algorithms can be passed: sparse factorizations, or
# Krylov methods such as conjugate gradients for this symmetric positive definite matrix:

using LinearSolve

for (name, alg) in ("sparse LU (KLU)" => KLUFactorization(), "conjugate gradients" => KrylovJL_CG(),
                    "GMRES" => KrylovJL_GMRES())
    s = solve(poisson, zeros(n), alg)
    println(rpad(name, 21), s.retcode, "  error ", maximum(abs, s.u - x .* (1 .- x) ./ 2))
end

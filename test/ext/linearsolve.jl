module LinearSolveExtTests

using Equations, LinearSolve, SparseArrays, LinearAlgebra, Test

@testset "LinearSolve" begin
    # the 1D Poisson matrix: sparse, and it stays sparse
    n = 50
    A = spdiagm(-1 => -ones(n - 1), 0 => 2ones(n), 1 => -ones(n - 1))
    b = ones(n)
    eq = Equation(Linear(A), b)
    @test linear_system(EquationProblem(eq, zeros(n)))[1] isa SparseMatrixCSC
    exact = Matrix(A) \ b
    for alg in (KLUFactorization(), KrylovJL_CG(), KrylovJL_GMRES())
        sol = solve(eq, zeros(n), alg)
        @test sol isa Solution
        @test sol.retcode === :Success
        @test sol.u ≈ exact rtol = 1e-6
        @test sol.alg === alg
    end
    @test solve(eq, zeros(n)).u ≈ exact          # DirectLinear with the sparse \
    @test_throws ArgumentError solve(Equation(x -> 2x, 1.0), 0.0, KLUFactorization())
    @test_throws ArgumentError solve(Equation(Linear(A), b), (0, 1), KLUFactorization())
end

end

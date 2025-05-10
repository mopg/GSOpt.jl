using GSOpt
using Test
using Documenter

@testset "GSOpt.jl" begin
    # Include all test files
    @testset "Variable Tests" begin
        include("test_variables.jl")
    end

    @testset "Expression Tests" begin
        include("test_expressions.jl")
    end

    @testset "Constraint Tests" begin
        include("test_constraints.jl")
    end

    # Include transformation tests
    @testset "Transformation Tests" begin
        include("test_transformations.jl")
    end

    # Include optimization tests
    @testset "Optimization Tests" begin
        include("test_optimize.jl")
    end

    # Include display tests
    @testset "Display Tests" begin
        include("test_display.jl")
    end

    @testset "Documentation Tests" begin
        doctest(GSOpt)
    end
end

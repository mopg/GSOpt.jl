using GSOpt
using Test

@testset "Expressions" begin

    models = [(:GP, GPModel()), (:SP, SPModel())]

    @testset "GP Expression Types for $model_type" for (model_type, model) in models
        # Create a geometric programming model and variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)
        @variable(model, z ≥ 0.1)

        # Test that variables are recognized as monomials and posynomials
        @test GSOpt.is_monomial(x)
        @test GSOpt.is_posynomial(x)

        # Test MonomialExpression creation
        @testset "Monomial Creation" begin
            # Test exponentiation
            expr1 = x^2
            @test expr1 isa GSOpt.MonomialExpression

            # Test negative exponent
            expr2 = x^(-2)
            @test expr2 isa GSOpt.MonomialExpression

            # Test multiplication
            expr3 = x * y
            @test expr3 isa GSOpt.MonomialExpression

            # Test multiplication with constant
            expr4 = 3 * x
            @test expr4 isa GSOpt.MonomialExpression

            # Test division
            expr5 = x / y
            @test expr5 isa GSOpt.MonomialExpression

            # Test division with constant
            expr6 = 3 / x
            @test expr6 isa GSOpt.MonomialExpression

            # Test combined operations
            expr7 = x^(-2) * y^2
            @test expr7 isa GSOpt.MonomialExpression

            # Test combined operations with constants
            expr8 = 5 * x^(-1) * y^2 / z
            @test expr8 isa GSOpt.MonomialExpression
        end

        # Test PosynomialExpression creation
        @testset "Posynomial Creation" begin
            # Test addition
            expr1 = x + y
            @test expr1 isa GSOpt.PosynomialExpression

            # Test addition with constant
            expr2 = x + 3
            @test expr2 isa GSOpt.PosynomialExpression

            # Test sum of monomials
            expr3 = x^2 + y^3
            @test expr3 isa GSOpt.PosynomialExpression

            # Test more complex addition
            expr4 = x^3 + y^2 + 5
            @test expr4 isa GSOpt.PosynomialExpression

            # Test addition of monomials created through multiplication
            expr5 = x * y + x * z
            @test expr5 isa GSOpt.PosynomialExpression

            # Test division
            expr6 = (x + y^2) / sqrt(x) * inv(z)
            @test expr6 isa GSOpt.PosynomialExpression

            # Test division with constant
            expr7 = (x + y) / 5.0
            @test expr7 isa GSOpt.PosynomialExpression
        end

        # Test SignomialExpression creation
        @testset "Signomial Creation" begin
            # Test subtraction
            expr1 = x - y
            @test expr1 isa GSOpt.SignomialExpression

            # Test subtraction with constant
            expr2 = x - 3
            @test expr2 isa GSOpt.SignomialExpression

            # Test negation
            expr3 = -x
            @test expr3 isa GSOpt.SignomialExpression

            # Test more complex expressions
            expr4 = -x^4 + y^7
            @test expr4 isa GSOpt.SignomialExpression

            # Test mixed operations
            expr5 = 2 * x^2 - 3 * y + z / x
            @test expr5 isa GSOpt.SignomialExpression
        end

        # Test specific cases from the requirements
        @testset "Required Examples" begin
            # Example 1: x^-2*y^2 should create a MonomialExpression
            expr1 = x^(-2) * y^2
            @test expr1 isa GSOpt.MonomialExpression

            # Example 2: x^3 + y^2 should create a PosynomialExpression
            expr2 = x^3 + y^2
            @test expr2 isa GSOpt.PosynomialExpression

            # Example 3: -x^4 + y^7 should create a SignomialExpression
            expr3 = -x^4 + y^7
            @test expr3 isa GSOpt.SignomialExpression
        end

        # Testing for GSOpt.is_monomial and GSOpt.is_posynomial functions
        @testset "Is Monomial and Is Posynomial" begin
            # Create a model for testing
            model = GPModel()

            @variable(model, x ≥ 0.1)
            @variable(model, y ≥ 0.1)
            @variable(model, z ≥ 0.1)

            # Test monomial detection
            @test GSOpt.is_monomial(x)
            @test GSOpt.is_monomial(2.5 * x)
            @test GSOpt.is_monomial(x * y)
            @test GSOpt.is_monomial(x^-1)
            @test GSOpt.is_monomial(x / y)
            @test !GSOpt.is_monomial(-x)
            @test !GSOpt.is_monomial(x + y)

            # Test posynomial detection
            @test GSOpt.is_posynomial(x)
            @test GSOpt.is_posynomial(x + y)
            @test GSOpt.is_posynomial(2x + 3y)
            @test !GSOpt.is_posynomial(-x + y)
            @test GSOpt.is_posynomial(x^-1 * y^-1 * z^-1 + x * y * z)
        end
    end

    @testset "Posynomial Approximation" begin

        model = SPModel()

        @variable(model, x, start = 2.0)
        @variable(model, y, start = 2.0)

        p = x^2 + y^2

        q = GSOpt.approximate_posynomial_as_monomial(p)

        @test q isa GSOpt.MonomialExpression
        @test q == 2 * x * y

    end

end

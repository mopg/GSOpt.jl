using GSOpt
using Test

@testset "GP Expression Types" begin
    # Create a geometric programming model and variables
    model = GPModel()
    @variable(model, x ≥ 0.1)
    @variable(model, y ≥ 0.1)
    @variable(model, z ≥ 0.1)

    # Test that variables are recognized as monomials and posynomials
    @test is_monomial(x)
    @test is_posynomial(x)

    # Test MonomialExpression creation
    @testset "Monomial Creation" begin
        # Test exponentiation
        expr1 = x^2
        @test expr1 isa MonomialExpression

        # Test negative exponent
        expr2 = x^(-2)
        @test expr2 isa MonomialExpression

        # Test multiplication
        expr3 = x * y
        @test expr3 isa MonomialExpression

        # Test multiplication with constant
        expr4 = 3 * x
        @test expr4 isa MonomialExpression

        # Test division
        expr5 = x / y
        @test expr5 isa MonomialExpression

        # Test division with constant
        expr6 = 3 / x
        @test expr6 isa MonomialExpression

        # Test combined operations
        expr7 = x^(-2) * y^2
        @test expr7 isa MonomialExpression

        # Test combined operations with constants
        expr8 = 5 * x^(-1) * y^2 / z
        @test expr8 isa MonomialExpression
    end

    # Test PosynomialExpression creation
    @testset "Posynomial Creation" begin
        # Test addition
        expr1 = x + y
        @test expr1 isa PosynomialExpression

        # Test addition with constant
        expr2 = x + 3
        @test expr2 isa PosynomialExpression

        # Test sum of monomials
        expr3 = x^2 + y^3
        @test expr3 isa PosynomialExpression

        # Test more complex addition
        expr4 = x^3 + y^2 + 5
        @test expr4 isa PosynomialExpression

        # Test addition of monomials created through multiplication
        expr5 = x * y + x * z
        @test expr5 isa PosynomialExpression

        # Test division
        expr6 = (x + y^2) / sqrt(x) * inv(z)
        @test expr6 isa PosynomialExpression

        # Test division with constant
        expr7 = (x + y) / 5.0
        @test expr7 isa PosynomialExpression
    end

    # Test SignomialExpression creation
    @testset "Signomial Creation" begin
        # Test subtraction
        expr1 = x - y
        @test expr1 isa SignomialExpression

        # Test subtraction with constant
        expr2 = x - 3
        @test expr2 isa SignomialExpression

        # Test negation
        expr3 = -x
        @test expr3 isa SignomialExpression

        # Test more complex expressions
        expr4 = -x^4 + y^7
        @test expr4 isa SignomialExpression

        # Test mixed operations
        expr5 = 2 * x^2 - 3 * y + z / x
        @test expr5 isa SignomialExpression
    end

    # Test specific cases from the requirements
    @testset "Required Examples" begin
        # Example 1: x^-2*y^2 should create a MonomialExpression
        expr1 = x^(-2) * y^2
        @test expr1 isa MonomialExpression

        # Example 2: x^3 + y^2 should create a PosynomialExpression
        expr2 = x^3 + y^2
        @test expr2 isa PosynomialExpression

        # Example 3: -x^4 + y^7 should create a SignomialExpression
        expr3 = -x^4 + y^7
        @test expr3 isa SignomialExpression
    end

    # Testing for is_monomial and is_posynomial functions
    @testset "Is Monomial and Is Posynomial" begin
        # Create a model for testing
        model = GPModel()

        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)
        @variable(model, z ≥ 0.1)

        # Test monomial detection
        @test is_monomial(x)
        @test is_monomial(2.5 * x)
        @test is_monomial(x * y)
        @test is_monomial(x^-1)
        @test is_monomial(x / y)
        @test !is_monomial(-x)
        @test !is_monomial(x + y)

        # Test posynomial detection
        @test is_posynomial(x)
        @test is_posynomial(x + y)
        @test is_posynomial(2x + 3y)
        @test !is_posynomial(-x + y)
        @test is_posynomial(x^-1 * y^-1 * z^-1 + x * y * z)
    end
end

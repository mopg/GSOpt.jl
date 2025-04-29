using GSOpt
using Test

@testset "GP Constraints" begin
    # Create a model for testing
    model = GPModel()

    # Create some variables
    @variable(model, x ≥ 0.1)
    @variable(model, y ≥ 0.1)
    @variable(model, z ≥ 0.1)

    # Test monomial equality constraints
    @testset "Monomial Equality Constraints" begin
        # Simple monomial equality constraint
        constr1 = @constraint(model, x * y == z)
        @test constr1 isa GPConstraintRef
        @test is_valid(model, constr1)

        # Simple monomial equality constraint with non-zero constant
        constr2 = @constraint(model, x * y == 4.5)
        @test constr2 isa GPConstraintRef
        @test is_valid(model, constr2)

        # More complex monomial equality constraint
        constr3 = @constraint(model, x^2 * y^(-1) == z^3)
        @test constr3 isa GPConstraintRef
        @test is_valid(model, constr3)

        # Should fail: not a monomial equality
        @test_throws Exception @constraint(model, x + y == z)

        # Should fail: monomial equality equal to 0
        @test_throws Exception @constraint(model, x + y == 0)
    end

    # Test posynomial inequality constraints
    @testset "Posynomial Inequality Constraints" begin
        # Simple posynomial inequality constraint
        constr4 = @constraint(model, x + y <= z)
        @test constr4 isa GPConstraintRef
        @test is_valid(model, constr4)

        # More complex posynomial inequality constraint
        constr5 = @constraint(model, 2x^2 + 3y^(-1) <= 4z^3)
        @test constr5 isa GPConstraintRef
        @test is_valid(model, constr5)

        # Single monomial (which is also a posynomial)
        constr6 = @constraint(model, x * y <= z)
        @test constr6 isa GPConstraintRef
        @test is_valid(model, constr6)

        # Should fail: not a posynomial inequality
        @test_throws Exception @constraint(model, -x + y <= z)

        # Should fail: posynomial equality (with monomial rhs)
        @test_throws Exception @constraint(model, -x + y == z)

        # Should fail: posynomial equality (with posynomial rhs)
        @test_throws Exception @constraint(model, -x + y == z + y^2)
    end

    # Test named constraints
    @testset "Named Constraints" begin
        constr7 = @constraint(model, con_name, x * y * z == 1)
        @test name(constr7) == "con_name"

        constr8 = @constraint(model, ineq_name, x + y + z <= 10)
        @test name(constr8) == "ineq_name"
    end
end

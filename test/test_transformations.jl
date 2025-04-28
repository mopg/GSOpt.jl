using GSOpt
using Test

# Test the log transformation functionality
@testset "Log Transformations" begin
    @testset "Variable Transformation" begin
        # Create a test model
        model = GPModel()

        # Add some variables with different bounds
        @variable(model, x ≥ 1)
        @variable(model, 2 ≤ y ≤ 10)
        @variable(model, z == 5)  # fixed variable

        # Create a log-transformed model
        log_model, var_map = GSOpt.create_log_model(model)

        # Test that the correct number of variables were created
        @test length(var_map) == 3

        # Test that bounds were correctly transformed to log space
        @test JuMP.has_lower_bound(var_map[x])
        @test JuMP.lower_bound(var_map[x]) ≈ log(1.0)

        @test JuMP.has_lower_bound(var_map[y])
        @test JuMP.has_upper_bound(var_map[y])
        @test JuMP.lower_bound(var_map[y]) ≈ log(2.0)
        @test JuMP.upper_bound(var_map[y]) ≈ log(10.0)

        @test JuMP.is_fixed(var_map[z])
        @test JuMP.fix_value(var_map[z]) ≈ log(5.0)
    end

    @testset "Monomial Equality Transformation" begin
        # Create a test model
        model = GPModel()

        # Add variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)

        # Add a monomial equality constraint
        @constraint(model, x * y^2 == 3)

        # Create a log-transformed model
        log_model, var_map = GSOpt.create_log_model(model)

        # There should be one constraint in the log model
        @test num_constraints(log_model, AffExpr, MOI.EqualTo{Float64}) == 1

        # Check that the constraint coefficient is approximately log(3)
        log_constr = first(all_constraints(log_model, AffExpr, MOI.EqualTo{Float64}))
        @test JuMP.constraint_object(log_constr).set.value ≈ log(3.0)
    end

    @testset "Posynomial Inequality Transformation" begin
        # Create a test model
        model = GPModel()

        # Add variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)

        # Add a posynomial inequality constraint
        @constraint(model, 2x + 3y ≤ 5x)

        # Create a log-transformed model
        log_model, var_map = GSOpt.create_log_model(model)
    end

    @testset "Objective Transformation" begin
        # Test minimization objective (posynomial)
        model1 = GPModel()
        @variable(model1, x ≥ 0.1)
        @variable(model1, y ≥ 0.1)
        @objective(model1, Min, 2x + 3y)

        log_model1, var_map1 = GSOpt.create_log_model(model1)

        # The minimization of a posynomial should become a nonlinear objective in log-space
        @test JuMP.objective_sense(log_model1) == MOI.MIN_SENSE

        # Test maximization objective (monomial)
        model2 = GPModel()
        @variable(model2, x ≥ 0.1)
        @variable(model2, y ≥ 0.1)
        @objective(model2, Max, 2 * x * y^0.5)

        log_model2, var_map2 = GSOpt.create_log_model(model2)

        # The maximization of a monomial should become a linear objective in log-space
        @test JuMP.objective_sense(log_model2) == MOI.MAX_SENSE
    end

end

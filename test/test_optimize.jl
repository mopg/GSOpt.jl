using GSOpt
using Test
using SCS

@testset "Geometric Programming Optimization" begin
    @testset "Simple Minimization Problem" begin
        # Create a simple GP model
        model = GPModel(optimizer = SCS.Optimizer)
        JuMP.set_silent(model)

        # Create variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)
        @variable(model, z ≥ 0.1)

        # Set objective (minimize posynomial)
        @objective(model, Min, x + y + z)

        # Add constraints
        @constraint(model, x * y * z ≥ 1)    # monomial inequality
        @constraint(model, x / y ≤ 1)        # ratio constraint

        # Solve the model
        optimize!(model)

        # Check if we got a solution
        @test termination_status(model) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]

        # Check solution values
        @test isapprox(value(x), 1.0, rtol = 1e-2)
        @test isapprox(value(y), 1.0, rtol = 1e-2)
        @test isapprox(value(z), 1.0, rtol = 1e-2)
        @test isapprox(objective_value(model), 3.0, rtol = 1e-2)
    end

    @testset "Rectangle Area Minimization" begin
        # Test a geometric programming formulation of the rectangle area minimization problem
        model = GPModel(optimizer = SCS.Optimizer)
        JuMP.set_silent(model)

        # Variables
        @variable(model, w ≥ 0.1)  # width
        @variable(model, h ≥ 0.1)  # height

        # Objective: minimize area
        @objective(model, Min, w * h)

        # Constraints
        @constraint(model, 2(w + h) ≤ 10)  # perimeter constraint
        @constraint(model, w * h ≥ 2)      # area constraint

        # Solve
        optimize!(model)

        # Check solution
        @test termination_status(model) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]

        # Optimal solution should be w = h = sqrt(2)
        @test isapprox(value(w), sqrt(2), rtol = 1e-2)
        @test isapprox(value(h), sqrt(2), rtol = 1e-2)
        @test isapprox(objective_value(model), 2.0, rtol = 1e-2)
    end

    @testset "Complex Posynomial Objective" begin
        # Create a GP model with a more complex objective
        model = GPModel(optimizer = SCS.Optimizer)
        JuMP.set_silent(model)

        # Define variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)
        @variable(model, z ≥ 0.1)

        # Define objective (minimize a posynomial)
        @objective(model, Min, x^-1 * y^-1 * z^-1 + x * y * z)

        # Add constraints
        @constraint(model, x * y * z == 1)  # monomial equality constraint
        @constraint(model, 2x + 3y + 4z ≤ 10)  # posynomial inequality constraint

        # Solve the problem
        optimize!(model)

        # Check if the model was solved successfully
        @test termination_status(model) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]

        # Get the solution
        x_val = value(x)
        y_val = value(y)
        z_val = value(z)

        # Check the solution validity
        @test x_val > 0 && y_val > 0 && z_val > 0
        @test isapprox(x_val * y_val * z_val, 1.0, rtol = 1e-4)  # Equality constraint
        @test 2 * x_val + 3 * y_val + 4 * z_val <= 10.0 + 1e-6  # Inequality constraint
    end

    @testset "Maximization Problem" begin
        # Create a geometric programming model with maximization objective
        model = GPModel(optimizer = SCS.Optimizer)
        JuMP.set_silent(model)

        # Define variables
        @variable(model, x ≥ 0.1)
        @variable(model, y ≥ 0.1)

        # Define objective (maximize a monomial)
        @objective(model, Max, x * y)

        # Add constraints
        @constraint(model, 3x + 4y ≤ 10)  # posynomial constraint
        @constraint(model, x ≤ 5)         # upper bound
        @constraint(model, y ≤ 5)         # upper bound

        # Solve the problem
        optimize!(model)

        # Check if the model was solved successfully
        @test termination_status(model) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]

        # The optimal solution should be at the boundary of the constraint 3x + 4y = 10
        x_val = value(x)
        y_val = value(y)

        @test isapprox(3 * x_val + 4 * y_val, 10.0, rtol = 1e-3)
        @test x_val <= 5.0 + 1e-6
        @test y_val <= 5.0 + 1e-6
    end
end

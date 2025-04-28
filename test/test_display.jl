using Test
using GSOpt

@testset "Display functionality" begin
    # Test GPModel display
    model = GPModel()

    # Capture the string representation of the model
    model_str = sprint(show, model)

    # Check that the model display contains expected elements
    @test occursin("Geometric Programming Model", model_str)
    @test occursin("Optimization sense", model_str)
    @test occursin("Number of variables", model_str)
    @test occursin("Number of constraints", model_str)

    # Test with variables
    x = @variable(model, x >= 1)
    y = @variable(model, y >= 2, upper_bound = 10)
    z = @variable(model, z == 5)

    # Test that model display updates with variables
    model_str = sprint(show, model)
    @test occursin("Number of variables: 3", model_str)

    # Test GPVariable display
    x_str = sprint(show, x)
    y_str = sprint(show, y)
    z_str = sprint(show, z)

    @test occursin("x", x_str)
    @test occursin("≥ 1", x_str)

    @test occursin("y", y_str)
    @test occursin("≥ 2", y_str)
    @test occursin("≤ 10", y_str)

    @test occursin("z = 5", z_str)

    # Test with objective and constraints
    @objective(model, Min, x + y)
    @constraint(model, x * y <= 10)

    # Test that model display updates with constraints
    model_str = sprint(show, model)
    @test occursin("Number of constraints: 1", model_str)

    # Test that we can display the model without errors
    @test_nowarn show(IOBuffer(), model)
    @test_nowarn show(IOBuffer(), x)
    @test_nowarn show(IOBuffer(), y)
    @test_nowarn show(IOBuffer(), z)
end

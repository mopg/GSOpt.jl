using GSOpt
using Test

@testset "GPModel Variable Creation" begin
    # Create a geometric programming model
    model = GPModel()

    # Test basic variable creation with positive lower bound
    @variable(model, x ≥ 0.1)
    @test x isa GSOpt.GPVariable
    @test JuMP.has_lower_bound(x)
    @test JuMP.lower_bound(x) == 0.1

    # Test variable creation without explicit bounds
    # (should automatically add a small positive lower bound)
    @variable(model, y)
    @test y isa GSOpt.GPVariable
    @test JuMP.has_lower_bound(y)
    @test JuMP.lower_bound(y) >= 1e-6
    @test JuMP.start_value(y) === nothing
    @test !JuMP.has_start_value(y)

    # Test variable creation with explicit positive value
    @variable(model, z == 5.0)
    @test z isa GSOpt.GPVariable
    @test JuMP.is_fixed(z)
    @test JuMP.fix_value(z) == 5.0

    # Test that trying to create a variable with non-positive lower bound throws an error
    @test_throws ErrorException @variable(model, w ≥ 0)
    @test_throws ErrorException @variable(model, v ≥ -1)

    # Test array of variables
    @variable(model, a[1:3] ≥ 0.1)
    for i = 1:3
        @test a[i] isa GSOpt.GPVariable
        @test JuMP.has_lower_bound(a[i])
        @test JuMP.lower_bound(a[i]) == 0.1
    end

    # Test that our model is storing the variables
    @test length(model.variables) == 6  # x, y, z, a[1], a[2], a[3]

    # Test that value() works for GPVariable
    @test JuMP.value(x) == 0.0

end

@testset "SPModel Variable Creation" begin
    # Create a signomial programming model
    model = SPModel()

    # Test basic variable creation with positive lower bound
    @variable(model, x ≥ 0.1)
    @test x isa GSOpt.SPVariable
    @test JuMP.has_lower_bound(x)
    @test JuMP.lower_bound(x) == 0.1

    # Test variable creation without explicit bounds
    # (should automatically add a small positive lower bound)
    @variable(model, y)
    @test y isa GSOpt.SPVariable
    @test JuMP.has_lower_bound(y)
    @test JuMP.lower_bound(y) >= 1e-6
    @test JuMP.start_value(y) === nothing
    @test !JuMP.has_start_value(y)

    # Test variable creation with initial value
    @variable(model, yy, start = 2.0)
    @test yy isa GSOpt.SPVariable
    @test JuMP.has_start_value(yy)
    @test JuMP.start_value(yy) === 2.0

    # Test variable creation with explicit positive value
    @variable(model, z == 5.0)
    @test z isa GSOpt.SPVariable
    @test JuMP.is_fixed(z)
    @test JuMP.fix_value(z) == 5.0

    # Test that trying to create a variable with non-positive lower bound throws an error
    @test_throws ErrorException @variable(model, w ≥ 0)
    @test_throws ErrorException @variable(model, v ≥ -1)

    # Test array of variables
    @variable(model, a[1:3] ≥ 0.1)
    for i = 1:3
        @test a[i] isa GSOpt.SPVariable
        @test JuMP.has_lower_bound(a[i])
        @test JuMP.lower_bound(a[i]) == 0.1
    end

    # Test that our model is storing the variables
    @test length(model.variables) == 7  # x, y, yy, z, a[1], a[2], a[3]

    # Test that value() works for SPVariable
    @test JuMP.value(x) == 0.0

end
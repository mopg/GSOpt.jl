
"""
    JuMP.termination_status(model::AbstractSpGpModel) -> MOI.TerminationStatusCode

Returns the termination status of the optimization.
"""
function JuMP.termination_status(model::AbstractSpGpModel)
    return model.solution_info.termination_status
end

"""
    JuMP.objective_value(model::AbstractSpGpModel) -> Float64

Returns the objective value after optimization.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.objective_value(model::AbstractSpGpModel)
    if isnothing(model.solution_info.objective_value)
        error("Model has not been solved yet")
    end
    return model.solution_info.objective_value
end

"""
    JuMP.solve_time(model::AbstractSpGpModel) -> Float64

Returns the time (in seconds) it took to solve the model.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.solve_time(model::AbstractSpGpModel)
    if isnothing(model.solution_info.solve_time)
        error("Model has not been solved yet")
    end
    return model.solution_info.solve_time
end

"""
    JuMP.objective_sense(model::AbstractSpGpModel) -> MOI.OptimizationSense

Returns the optimization sense of the model (minimization or maximization).
"""
function JuMP.objective_sense(model::AbstractSpGpModel)
    return model.objective_sense
end

"""
    JuMP.num_variables(model::AbstractSpGpModel) -> Int

Returns the number of variables in the model.
"""
function JuMP.num_variables(model::AbstractSpGpModel)
    return length(model.variables)
end

"""
    JuMP.num_constraints(model::AbstractSpGpModel, function_type=nothing, set_type=nothing; 
                         count_variable_in_set_constraints::Bool = true) -> Int

Returns the number of constraints in the model.

# Arguments
- `model::AbstractSpGpModel`: The geometric programming model
- `function_type`: Optional type of constraint function to count
- `set_type`: Optional type of constraint set to count
- `count_variable_in_set_constraints::Bool`: Whether to count variable bounds as constraints

# Returns
- The number of constraints matching the specified types, or all constraints if no types specified
"""
function JuMP.num_constraints(
    model::AbstractSpGpModel,
    function_type = nothing,
    set_type = nothing;
    count_variable_in_set_constraints::Bool = true,
)
    # If specific function and set types are requested, filter constraints
    if function_type !== nothing && set_type !== nothing
        # For now, we don't track constraint types in detail
        # This could be enhanced in the future
        return 0
    end

    # Otherwise return the total number of constraints
    return length(model.constraints)
end

"""
    JuMP.list_of_constraint_types(model::AbstractSpGpModel) -> Vector{Tuple{DataType,DataType}}

Returns a list of constraint types in the model as (function_type, set_type) tuples.

# Returns
- A vector of tuples where each tuple contains the function type and set type of a constraint
"""
function JuMP.list_of_constraint_types(model::AbstractSpGpModel)
    # Return a list of tuples (F, S) where F is the function type and S is the set type
    # For geometric programming, we typically have posynomial <= 1 and monomial == 1 constraints
    # This is a simplified implementation
    return [
        (AbstractGPExpression, MOI.LessThan{Float64}),
        (AbstractGPExpression, MOI.EqualTo{Float64}),
    ]
end

"""
    JuMP.objective_function(model::AbstractSpGpModel) -> AbstractGPExpression

Returns the objective function of the model.
"""
function JuMP.objective_function(model::AbstractSpGpModel)
    return model.objective_function
end

"""
    JuMP.objective_function_type(model::AbstractSpGpModel) -> DataType

Returns the type of the objective function.
"""
function JuMP.objective_function_type(model::AbstractSpGpModel)
    return AbstractGPExpression
end

function JuMP.set_objective_sense(model::AbstractSpGpModel, sense::MOI.OptimizationSense)
    model.objective_sense = sense
end

"""
    JuMP.set_silent(model::AbstractSpGpModel)

Sets the model to silent mode, suppressing solver output.
"""
function JuMP.set_silent(model::AbstractSpGpModel)
    # If we have an optimizer, set it to silent mode
    if !isnothing(model.optimizer_factory)
        # Get the current optimizer constructor
        optimizer = model.optimizer_factory.optimizer_constructor

        # Create a new optimizer with the silent option
        # The MOI.Silent() attribute is the standard way to silence solvers
        model.optimizer_factory =
            MOI.OptimizerWithAttributes(optimizer, MOI.Silent() => true)
    end
    return nothing
end

"""
    JuMP.object_dictionary(model::AbstractSpGpModel) -> Dict{Symbol,Any}

Returns a dictionary of named objects in the model.
This is part of the JuMP interface for models.
"""
JuMP.object_dictionary(model::AbstractSpGpModel) = Dict{Symbol,Any}()


function JuMP.solution_summary(
    model::AbstractSpGpModel;
    result::Int = 1,
    verbose::Bool = false,
)
    # Get the termination status
    term_status = termination_status(model)

    # Get the objective value if available
    obj_value =
        isnothing(model.solution_info.objective_value) ? nothing :
        model.solution_info.objective_value

    # Get the solve time if available
    solve_time =
        isnothing(model.solution_info.solve_time) ? nothing : model.solution_info.solve_time

    # Count variables and constraints
    var_count = num_variables(model)
    con_count = num_constraints(model)

    # Extract variable values if available
    var_values = Dict{String,Float64}()
    if !isnothing(model.solution_info.variable_values) &&
       !isempty(model.solution_info.variable_values)
        for var in model.variables
            if haskey(model.solution_info.variable_values, JuMP.index(var))
                var_values[JuMP.name(var)] =
                    model.solution_info.variable_values[JuMP.index(var)]
            end
        end
    end

    # Extract constraint duals if available
    constraint_duals = Dict{Int,Float64}()
    if !isnothing(model.solution_info.constraint_duals) &&
       !isempty(model.solution_info.constraint_duals)
        constraint_duals = copy(model.solution_info.constraint_duals)
    end

    return _SolutionSummary(
        model isa GPModel,
        term_status,
        obj_value,
        solve_time,
        var_count,
        con_count,
        var_values,
        constraint_duals,
        verbose,
    )
end
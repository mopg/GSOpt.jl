"""
    GPModel <: JuMP.AbstractModel

A model type for geometric programming problems. It extends JuMP's model functionality
to handle geometric programming constraints and transformations.

Geometric programs involve:
- Minimizing posynomials or maximizing monomials
- Subject to monomial equality constraints (= 1)
- And posynomial inequality constraints (≤ 1)

# Example
```julia
using GSOpt

# Create a geometric programming model
model = GPModel()

# Add variables (must be positive in geometric programming)
@variable(model, x >= 1)
@variable(model, y >= 1)

# Set objective (minimize a posynomial)
@objective(model, Min, 2x + 3y + 4x*y)

# Add constraints
@constraint(model, x*y <= 10)  # Posynomial inequality
@constraint(model, x*y^2 == 20)  # Monomial equality

# Solve the model
optimize!(model)

# Get results
value(x)
value(y)
objective_value(model)
```
"""
# Type to store original variable info without creating a JuMP variable yet
struct GPVariableInfo
    name::String
    lower_bound::Float64
    upper_bound::Union{Float64,Nothing}
    fixed_value::Union{Float64,Nothing}
    start::Union{Float64,Nothing}
    binary::Bool
    integer::Bool
end

mutable struct GPModel <: JuMP.AbstractModel
    # The optimizer that will be used when we create the transformed model
    optimizer_factory::Union{Nothing,MOI.OptimizerWithAttributes}

    # Variables in the model
    variables::Vector{AbstractGPVariable}

    # Constraints in the model
    constraints::Vector{GPConstraintData}

    # Objective sense (MIN_SENSE or MAX_SENSE)
    objective_sense::MOI.OptimizationSense

    # Objective function (a posynomial for minimization, a monomial for maximization)
    objective_function::Union{Nothing,AbstractGPExpression}

    # Solution information
    variable_values::Dict{Int,Float64} # Maps variable index to value
    objective_value::Union{Nothing,Float64}
    termination_status::Union{Nothing,MOI.TerminationStatusCode}
    solve_time::Union{Nothing,Float64}
    constraint_duals::Union{Nothing,Dict{Int,Float64}} # Maps constraint index to dual value

    # Constructor
    function GPModel(; optimizer = nothing, add_bridges = true)
        opt_factory = nothing
        if optimizer !== nothing
            opt_factory = MOI.OptimizerWithAttributes(optimizer)
        end

        return new(
            opt_factory,
            GPVariable[], # Variables vector
            GPConstraintData[], # Constraints vector
            MOI.MIN_SENSE, # Default objective sense
            nothing, # No objective function yet
            Dict{Int,Float64}(), # Empty dictionary for variable values
            nothing, # No objective value yet
            nothing, # No termination status yet
            nothing, # No solve time yet
            nothing, # No constraint duals yet
        )
    end
end

GPModel(optimizer) = GPModel(optimizer = optimizer)

# Implement required JuMP interface methods for GPModel

"""
    JuMP.object_dictionary(model::GPModel) -> Dict{Symbol,Any}

Returns a dictionary of named objects in the model.
This is part of the JuMP interface for models.
"""
JuMP.object_dictionary(model::GPModel) = Dict{Symbol,Any}()

"""
    JuMP.set_objective(model::GPModel, sense::MOI.OptimizationSense, func::AbstractGPExpression)

Sets the objective function for the geometric programming model.

# Arguments
- `model::GPModel`: The geometric programming model
- `sense::MOI.OptimizationSense`: The optimization sense (MIN_SENSE or MAX_SENSE)
- `func::AbstractGPExpression`: The objective function (must be a posynomial for minimization or a monomial for maximization)

# Throws
- Error if the objective function is not compatible with the optimization sense
"""
function JuMP.set_objective(
    model::GPModel,
    sense::MOI.OptimizationSense,
    func::AbstractGPExpression,
)
    # Check if the objective function is valid for the given sense
    if sense == MOI.MIN_SENSE
        # For minimization, the objective must be a posynomial
        if !is_posynomial(func)
            error("Minimization objective must be a posynomial")
        end
    elseif sense == MOI.MAX_SENSE
        # For maximization, the objective must be a monomial
        if !is_monomial(func)
            error("Maximization objective must be a monomial")
        end
    else
        error("Unsupported optimization sense: $sense")
    end

    # Store the objective function and sense
    model.objective_sense = sense
    model.objective_function = func

    return
end

"""
    JuMP.optimize!(model::GPModel)

Solves the geometric programming model by transforming it to a convex optimization problem in log space.

# Steps
1. Transforms the model to log space
2. Solves the transformed model using the specified optimizer
3. Maps the solution back to the original variables

# Throws
- Error if no objective function is set
"""
function JuMP.optimize!(model::GPModel)
    # Make sure the model is ready to be solved
    if isnothing(model.objective_function)
        error("No objective function set in the model")
    end

    # Create the log-transformed convex optimization model with constraint mapping
    log_model, var_map, constraint_map = create_log_model(model)

    # Record the start time
    start_time = time()

    # Solve the log-transformed model
    JuMP.optimize!(log_model)

    # Record the end time
    end_time = time()

    # Map the solution back to the original variables
    map_solution(model, log_model, var_map, constraint_map)

    # Return the model
    return model
end

"""
    JuMP.termination_status(model::GPModel) -> MOI.TerminationStatusCode

Returns the termination status of the optimization.
"""
function JuMP.termination_status(model::GPModel)
    return model.termination_status
end

"""
    JuMP.objective_value(model::GPModel) -> Float64

Returns the objective value after optimization.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.objective_value(model::GPModel)
    if isnothing(model.objective_value)
        error("Model has not been solved yet")
    end
    return model.objective_value
end

"""
    JuMP.solve_time(model::GPModel) -> Float64

Returns the time (in seconds) it took to solve the model.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.solve_time(model::GPModel)
    if isnothing(model.solve_time)
        error("Model has not been solved yet")
    end
    return model.solve_time
end

"""
    JuMP.objective_sense(model::GPModel) -> MOI.OptimizationSense

Returns the optimization sense of the model (minimization or maximization).
"""
function JuMP.objective_sense(model::GPModel)
    return model.objective_sense
end

"""
    JuMP.num_variables(model::GPModel) -> Int

Returns the number of variables in the model.
"""
function JuMP.num_variables(model::GPModel)
    return length(model.variables)
end

"""
    JuMP.num_constraints(model::GPModel, function_type=nothing, set_type=nothing; 
                         count_variable_in_set_constraints::Bool = true) -> Int

Returns the number of constraints in the model.

# Arguments
- `model::GPModel`: The geometric programming model
- `function_type`: Optional type of constraint function to count
- `set_type`: Optional type of constraint set to count
- `count_variable_in_set_constraints::Bool`: Whether to count variable bounds as constraints

# Returns
- The number of constraints matching the specified types, or all constraints if no types specified
"""
function JuMP.num_constraints(
    model::GPModel,
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
    JuMP.list_of_constraint_types(model::GPModel) -> Vector{Tuple{DataType,DataType}}

Returns a list of constraint types in the model as (function_type, set_type) tuples.

# Returns
- A vector of tuples where each tuple contains the function type and set type of a constraint
"""
function JuMP.list_of_constraint_types(model::GPModel)
    # Return a list of tuples (F, S) where F is the function type and S is the set type
    # For geometric programming, we typically have posynomial <= 1 and monomial == 1 constraints
    # This is a simplified implementation
    return [
        (AbstractGPExpression, MOI.LessThan{Float64}),
        (AbstractGPExpression, MOI.EqualTo{Float64}),
    ]
end

"""
    JuMP.objective_function(model::GPModel) -> AbstractGPExpression

Returns the objective function of the model.
"""
function JuMP.objective_function(model::GPModel)
    return model.objective_function
end

"""
    JuMP.objective_function_type(model::GPModel) -> DataType

Returns the type of the objective function.
"""
function JuMP.objective_function_type(model::GPModel)
    return AbstractGPExpression
end

"""
    Base.show(io::IO, model::GPModel)

Pretty-prints the geometric programming model, showing key information.
"""
function Base.show(io::IO, model::GPModel)
    print(io, "Geometric Programming Model")
    print(io, "\n ├ Optimization sense: ", model.objective_sense)
    print(io, "\n ├ Number of variables: ", JuMP.num_variables(model))
    print(io, "\n └ Number of constraints: ", JuMP.num_constraints(model))
end

"""
    JuMP.set_silent(model::GPModel)

Sets the model to silent mode, suppressing solver output.
"""
function JuMP.set_silent(model::GPModel)
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

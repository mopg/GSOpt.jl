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
mutable struct GPModel <: AbstractSpGpModel
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

    solution_info::ModelSolutionInfo

    # Constructor
    function GPModel(; optimizer = nothing, add_bridges = true)
        opt_factory =
            optimizer !== nothing ? MOI.OptimizerWithAttributes(optimizer) : nothing

        return new(
            opt_factory,
            GPVariable[], # Variables vector
            GPConstraintData[], # Constraints vector
            MOI.MIN_SENSE, # Default objective sense
            nothing, # No objective function yet
            ModelSolutionInfo(),
        )
    end
end

GPModel(optimizer) = GPModel(optimizer = optimizer)

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
            error("Minimization objective must be a posynomial, or monomial")
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

    # Solve the log-transformed model
    JuMP.optimize!(log_model)

    # Map the solution back to the original variables
    map_solution(model, log_model, var_map, constraint_map)

    # Return the model
    return model
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



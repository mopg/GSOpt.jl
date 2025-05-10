mutable struct SPModel <: AbstractSpGpModel
    # The optimizer that will be used when we create the transformed model
    optimizer_factory::Union{Nothing,MOI.OptimizerWithAttributes}

    # Variables in the model
    variables::Vector{AbstractSPVariable}

    # Constraints in the model
    constraints::Vector{SPConstraintData}

    # Objective sense (MIN_SENSE or MAX_SENSE)
    objective_sense::MOI.OptimizationSense

    # Objective function (a posynomial for minimization, a monomial for maximization)
    objective_function::Union{Nothing,AbstractGPSPExpression}

    solution_info::ModelSolutionInfo

    max_iterations::Int
    reltol::Float64
    abstol::Float64

    # Constructor
    function SPModel(;
        optimizer = nothing,
        add_bridges = true,
        max_iterations = 100,
        reltol = 1e-6,
        abstol = 1e-6,
    )
        opt_factory =
            optimizer !== nothing ? MOI.OptimizerWithAttributes(optimizer) : nothing

        return new(
            opt_factory,
            SPVariable[], # Variables vector
            SPConstraintData[], # Constraints vector
            MOI.MIN_SENSE, # Default objective sense
            nothing, # No objective function yet
            ModelSolutionInfo(),
            max_iterations,
            reltol,
            abstol,
        )
    end
end

SPModel(optimizer; max_iterations = 100, reltol = 1e-6, abstol = 1e-6) = SPModel(
    optimizer = optimizer,
    max_iterations = max_iterations,
    reltol = reltol,
    abstol = abstol,
)

"""
    JuMP.set_objective(model::SPModel, sense::MOI.OptimizationSense, func::AbstractGPExpression)

Sets the objective function for the signomial programming model.

# Arguments
- `model::SPModel`: The signomial programming model
- `sense::MOI.OptimizationSense`: The optimization sense (MIN_SENSE or MAX_SENSE)
- `func::AbstractGPExpression`: The objective function (must be a signomial for minimization or a monomial for maximization)

# Throws
- Error if the objective function is not compatible with the optimization sense
"""
function JuMP.set_objective(
    model::SPModel,
    sense::MOI.OptimizationSense,
    func::AbstractGPExpression,
)
    # Check if the objective function is valid for the given sense
    if sense == MOI.MIN_SENSE
        # For minimization, the objective must be a posynomial
        if !is_signomial(func)
            error("Minimization objective must be a monomial, posynomial, or signomial")
        end
    elseif sense == MOI.MAX_SENSE
        # For maximization, the objective must be a monomial
        if !is_signomial(func)
            error("Maximization objective must be a monomial, posynomial, or signomial")
        end
    else
        error("Unsupported optimization sense: $sense")
    end

    # Store the objective function and sense
    model.objective_sense = sense
    model.objective_function = func

    return
end

function get_relative_error(current_var_values, last_var_values)
    return norm(current_var_values - last_var_values) / norm(current_var_values)
end

function get_absolute_error(current_var_values, last_var_values)
    return norm(current_var_values - last_var_values)
end

function JuMP.optimize!(model::SPModel)
    # Make sure the model is ready to be solved
    if isnothing(model.objective_function)
        error("No objective function set in the model")
    end

    iter = 0
    current_var_values = [latest_linearization_point(var) for var in model.variables]
    last_var_values = zeros(length(model.variables))

    relative_error = Inf
    absolute_error = Inf

    constraint_map = Dict{Int,JuMP.ConstraintRef}()
    var_map = Dict{SPVariable,JuMP.VariableRef}()
    log_model = nothing

    show_verbose = !is_silent(model)

    while iter < model.max_iterations &&
              absolute_error > model.abstol &&
              relative_error > model.reltol

        iter += 1
        last_var_values = copy(current_var_values)

        if show_verbose
            println("\nSignomial Programming Iteration $iter")
        end

        # Create the log-transformed convex optimization model with constraint mapping
        log_model, var_map, constraint_map = create_log_model(model)
        # TODO: check for whether this is actually a geometric program, if so throw warning and return solution

        # Solve the log-transformed model
        JuMP.optimize!(log_model)

        for (i_var, var) in enumerate(model.variables)
            log_var = var_map[var]
            log_value = JuMP.value(log_var)

            # Transform back: x = exp(y)
            new_val = exp(log_value)
            current_var_values[i_var] = new_val

            add_linearization_point(var, new_val)
        end

        relative_error = get_relative_error(current_var_values, last_var_values)
        absolute_error = get_absolute_error(current_var_values, last_var_values)

        if show_verbose
            println("Relative error: $relative_error | Absolute error: $absolute_error")
        end
    end

    # Map the solution back to the original variables
    map_solution(model, log_model, var_map, constraint_map)

    # Return the model
    return model
end

"""
    Base.show(io::IO, model::SPModel)

Pretty-prints the signomial programming model, showing key information.
"""
function Base.show(io::IO, model::SPModel)
    print(io, "Signomial Programming Model")
    print(io, "\n ├ Optimization sense: ", model.objective_sense)
    print(io, "\n ├ Number of variables: ", JuMP.num_variables(model))
    print(io, "\n └ Number of constraints: ", JuMP.num_constraints(model))
end
"""
    Transformations for geometric programming.

This module implements the log transformation for geometric programming models:
- Variables x are transformed to y = log(x)
- Monomial constraints become affine constraints
- Posynomial constraints become log-sum-exp constraints
- Objective function is transformed accordingly

The transformation preserves convexity, allowing the GP to be solved using
standard convex optimization solvers.
"""

function transform_variable!(log_model::JuMP.Model, var::GPVariable, var_map::Dict{GPVariable,JuMP.VariableRef})

    if JuMP.is_fixed(var)
        # Fixed variables are transformed to log-transformed variables
        fixed_value = JuMP.fix_value(var)
        log_var = @variable(log_model, base_name = "log_$(var.name)")
        JuMP.fix(log_var, log(fixed_value))
        var_map[var] = log_var
    else
        # Extract bounds (in original space)
        # All GP variables should have positive lower bounds
        lb = JuMP.has_lower_bound(var) ? var.lower_bound : 1e-10
        ub = JuMP.has_upper_bound(var) ? var.upper_bound : Inf

        # Transform bounds to log space: log(lb) <= y <= log(ub)
        log_lb = log(lb)
        log_ub = ub < Inf ? log(ub) : Inf

        # Create the log-transformed variable
        log_var = @variable(
            log_model,
            base_name = "log_$(var.name)",
            lower_bound = log_lb,
            upper_bound = log_ub,
        )

        # Store the mapping
        var_map[var] = log_var
    end

end

# Create a log-transformed model from a GPModel
function create_log_model(model::GPModel)
    # Create a new JuMP model with the same solver
    log_model = JuMP.Model(model.optimizer_factory)

    # Map from original variables to log-transformed variables
    var_map = Dict{GPVariable,JuMP.VariableRef}()

    # Transform variables: x -> log(x)
    for var in model.variables
        transform_variable!(log_model, var, var_map)
    end

    # Transform constraints
    for constr_data in model.constraints
        constraint = constr_data.constraint

        # Get the constraint function and set
        func = JuMP.jump_function(constraint)
        set = JuMP.moi_set(constraint)

        # Transform the constraint based on its type
        if constr_data.is_equality
            # Monomial equality constraint: m1 == m2 becomes log(m1) == log(m2)
            # In standard form: m1/m2 == 1 becomes log(m1) - log(m2) == 0
            transform_equality!(log_model, func, set, var_map)
        else
            # Posynomial inequality constraint: p <= m becomes log(p) <= log(m)
            # In standard form: p/m <= 1 becomes log-sum-exp(...) <= 0
            transform_inequality!(log_model, func, set, var_map)
        end
    end

    # Transform the objective function
    if !isnothing(model.objective_function)
        transform_objective!(log_model, model, var_map)
    end

    return log_model, var_map
end

# Transform a monomial equality constraint to log space
function transform_equality!(log_model::JuMP.Model,
    func::MonomialExpression,
    set::MOI.EqualTo,
    var_map::Dict{GPVariable,JuMP.VariableRef})
    # In standard form, the constraint is: m/C = 1, or log(m) = log(C)
    # The monomial m = C * x1^a1 * x2^a2 * ... becomes 
    # log(m) = log(C) + a1*log(x1) + a2*log(x2) + ...

    # Initialize with the log of the coefficient
    log_expr::JuMP.AffExpr = log(func.term.coefficient)

    # Add the log-transformed variables with their exponents
    for (var, expon) in func.term.exponents
        log_expr += expon * var_map[var]
    end

    # Add the constraint: log(m) = log(set.value)
    if set.value == 1.0
        @constraint(log_model, log_expr == 0.0)
    else
        @constraint(log_model, log_expr == log(set.value))
    end
end

# Transform a monomial inequality constraint to log space
function transform_inequality!(log_model::JuMP.Model,
    func::MonomialExpression,
    set::MOI.LessThan,
    var_map::Dict{GPVariable,JuMP.VariableRef})
    # In standard form, the constraint is: m/C <= 1, or log(m) <= log(C)
    # The monomial m = C * x1^a1 * x2^a2 * ... becomes 
    # log(m) = log(C) + a1*log(x1) + a2*log(x2) + ...

    # Initialize with the log of the coefficient
    log_expr::JuMP.AffExpr = log(func.term.coefficient)

    # Add the log-transformed variables with their exponents
    for (var, expon) in func.term.exponents
        log_expr += expon * var_map[var]
    end

    # Add the constraint: log(m) <= log(set.upper)
    @constraint(log_model, log_expr <= log(set.upper))
end

# Transform a posynomial inequality constraint to log space
function transform_inequality!(log_model::JuMP.Model,
    func::PosynomialExpression,
    set::MOI.LessThan,
    var_map::Dict{GPVariable,JuMP.VariableRef})
    # In standard form, the constraint is: p/C <= 1, or log(p) <= log(C)
    # For a posynomial p = sum_i (C_i * prod_j x_j^a_ij), we use the fact that:
    # log(sum_i exp(y_i)) is convex, where y_i = log(C_i * prod_j x_j^a_ij)

    # For each term in the posynomial, construct its log-transform
    log_terms = Vector{JuMP.AffExpr}()

    normalized_func = func / set.upper

    for term in normalized_func.terms
        # Start with the log of the coefficient
        log_term::JuMP.AffExpr = log(term.coefficient)

        # Add the log-transformed variables with their exponents
        for (var, expon) in term.exponents
            log_term += expon * var_map[var]
        end

        push!(log_terms, log_term)
    end

    # Create the log-sum-exp constraint: log(sum_i exp(log_terms_i)) <= log(set.upper)
    if length(log_terms) == 1
        # If there's only one term, it simplifies to a linear constraint
        @constraint(log_model, log_terms[1] <= 0.0)
    else
        # Implement the constraint as a log-sum-exp constraint
        # from e.g., https://www.seas.ucla.edu/~vandenbe/236C/lectures/conic.pdf (slide 15-12)
        u_aux_constraint = @variable(log_model, [1:length(log_terms)], lower_bound = 0.0)
        @constraint(log_model, sum(u_aux_constraint) <= 1)
        for kk in 1:length(log_terms)
            @constraint(log_model, [log_terms[kk], 1.0, u_aux_constraint[kk]] in MOI.ExponentialCone())
        end
    end
end

# Transform the objective function
function transform_objective!(log_model::JuMP.Model,
    model::GPModel,
    var_map::Dict{GPVariable,JuMP.VariableRef})
    obj_func = model.objective_function
    sense = model.objective_sense


    if obj_func isa PosynomialExpression

        if sense != MOI.MIN_SENSE
            if length(obj_func.terms) > 1
                error("Maximization objective must be a monomial")
            end
        end
        # Minimizing a posynomial: min p becomes min log(p) in log-space

        if length(obj_func.terms) == 1
            # If there's only one term, it simplifies to a linear objective
            single_log_term::JuMP.AffExpr = log(obj_func.terms[1].coefficient)
            for (var, expon) in obj_func.terms[1].exponents
                single_log_term += expon * var_map[var]
            end

            @objective(log_model, MOI.MIN_SENSE, single_log_term)
        else
            # Use log-sum-exp for the objective (which turns into an exponential cone)
            # from e.g., https://www.seas.ucla.edu/~vandenbe/236C/lectures/conic.pdf (slide 15-12)

            @variable(model, objective_variable) # in original space
            normalized_objective_func = obj_func / objective_variable

            # Transform the objective variable
            transform_variable!(log_model, objective_variable, var_map)

            log_terms = Vector{JuMP.AffExpr}()

            for term in normalized_objective_func.terms
                # Start with the log of the coefficient
                this_log_term::JuMP.AffExpr = log(term.coefficient)

                # Add the log-transformed variables with their exponents
                for (var, expon) in term.exponents
                    this_log_term += expon * var_map[var]
                end

                push!(log_terms, this_log_term)
            end

            u_aux_obj = @variable(log_model, [1:length(log_terms)], lower_bound = 0.0)
            @constraint(log_model, sum(u_aux_obj) <= 1)
            for kk in 1:length(log_terms)
                @constraint(log_model, [log_terms[kk], 1.0, u_aux_obj[kk]] in MOI.ExponentialCone())
            end

            obj_variable_in_logspace = var_map[objective_variable]
            @objective(log_model, sense, obj_variable_in_logspace)
        end
    elseif obj_func isa MonomialExpression

        # Initialize with the log of the coefficient
        log_expr::JuMP.AffExpr = log(obj_func.term.coefficient)

        # Add the log-transformed variables with their exponents
        for (var, expon) in obj_func.term.exponents
            log_expr += expon * var_map[var]
        end

        # Set the objective
        @objective(log_model, sense, log_expr)
    else
        error("Objective function must be a posynomial or monomial")
    end
end

# Map the solution back from log space to original space
function map_solution(model::GPModel, log_model::JuMP.Model, var_map::Dict{GPVariable,JuMP.VariableRef})
    # Check if the model was solved successfully
    term_status = JuMP.termination_status(log_model)
    if term_status != MOI.OPTIMAL && term_status != MOI.LOCALLY_SOLVED && term_status != MOI.ALMOST_OPTIMAL
        @warn "Log-transformed model was not solved to optimality: $term_status"
    end

    # Map the log-space solution back to the original space
    for var in model.variables
        log_var = var_map[var]
        log_value = JuMP.value(log_var)

        # Transform back: x = exp(y)
        original_value = exp(log_value)

        # Store the value in the original model's solution
        model.variable_values[var.index] = original_value
    end

    # Store the objective value
    if !isnothing(model.objective_function)
        # For a minimization problem, we minimized log(p) in log space
        # For a maximization problem, we maximized log(m) in log space
        # Need to transform the objective value back
        log_obj_value = JuMP.objective_value(log_model)

        if model.objective_sense == MOI.MIN_SENSE || model.objective_sense == MOI.MAX_SENSE
            # For both minimization and maximization, we take exp of the log objective value
            model.objective_value = exp(log_obj_value)
        end
    end

    # Store the termination status
    model.termination_status = JuMP.termination_status(log_model)

    # Store the solve time
    model.solve_time = JuMP.solve_time(log_model)
end

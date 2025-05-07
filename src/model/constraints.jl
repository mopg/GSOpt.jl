"""
    Constraints for geometric programming.
    
This module implements constraint handling for geometric programming models:
- Monomial equality constraints (e.g., x * y == z)
- Posynomial inequality constraints (e.g., x + y <= z)

Constraints are validated at creation time to ensure they conform to geometric
programming rules.
"""

abstract type ConstraintRef end


"""
    GPConstraintRef

A reference to a constraint in a geometric programming model.

# Fields
- `model::GPModel`: The geometric programming model
- `index::Int`: The index of the constraint in the model's constraints vector
"""
struct GPConstraintRef <: ConstraintRef
    model::GPModel
    index::Int
end

"""
    SPConstraintRef

A reference to a constraint in a signomial programming model.

# Fields
- `model::SPModel`: The signomial programming model
- `index::Int`: The index of the constraint in the model's constraints vector
"""
struct SPConstraintRef <: ConstraintRef
    model::SPModel
    index::Int
end

function Base.show(io::IO, ref::ConstraintRef)
    # get the constraint data from the model
    model = ref.model
    index = ref.index
    constraint = model.constraints[index]
    return print(io, constraint)
end

struct GPScalarConstraint <: JuMP.AbstractConstraint
    scalar_constraint::JuMP.ScalarConstraint
    negate_dual::Bool
    is_signomial_constraint::Bool
end

function GPScalarConstraint(
    scalar_constraint::JuMP.ScalarConstraint;
    negate_dual::Bool = false,
    is_signomial_constraint::Bool = false,
)
    return GPScalarConstraint(scalar_constraint, negate_dual, is_signomial_constraint)
end

# Make our expression types compatible with JuMP's constraint system
# These methods allow AbstractGPSPExpression types to be used in JuMP constraints
Base.broadcastable(x::AbstractGPSPExpression) = Ref(x)
Base.convert(::Type{JuMP.AbstractJuMPScalar}, x::AbstractGPSPExpression) = x

# Enable JuMP to create ScalarConstraint with our custom types
function JuMP.ScalarConstraint(func::AbstractGPSPExpression, set::MOI.AbstractScalarSet)
    return JuMP.ScalarConstraint{AbstractGPSPExpression,typeof(set)}(func, set)
end

# Extract variables from a constraint function (for AffExpr and QuadExpr functions)
function extract_variables(func::JuMP.GenericAffExpr)
    variables = collect(keys(func.terms))
    return variables
end

function extract_variables(func::Any)
    # For other types (like our GP expressions), we don't have access to the variables directly
    # So we'll just return an empty list
    return GPVariable[]
end

# Store a list of variables involved in a constraint
function constraint_variables(constr::JuMP.AbstractConstraint)
    func = JuMP.jump_function(constr)
    return extract_variables(func)
end

# Check if a constraint is a valid GP constraint
function is_valid_gp_constraint(constr::JuMP.ScalarConstraint)
    func = JuMP.jump_function(constr)
    set = JuMP.moi_set(constr)

    if set isa MOI.EqualTo
        # For equality constraints, both sides must be monomials
        return is_monomial(func)
    elseif set isa MOI.LessThan
        # For inequality (less than) constraints, the expression must be a posynomial
        return is_posynomial(func)
    else
        return false
    end
end

# Check if a constraint is a valid SP constraint
function is_valid_sp_constraint(constr::JuMP.ScalarConstraint)
    func = JuMP.jump_function(constr)
    set = JuMP.moi_set(constr)

    if set isa MOI.EqualTo
        # For equality constraints, both sides must be monomials
        return is_monomial(func)
    elseif set isa MOI.LessThan
        # For inequality (less than) constraints, the expression must be a posynomial
        return is_signomial(func)
    else
        return is_signomial(func)
    end
end

# Add a constraint to the GPModel
function JuMP.add_constraint(model::GPModel, constr::GPScalarConstraint, name::String = "")

    if constr.is_signomial_constraint
        error("Signomial constraints are not supported for geometric programming")
    end

    jump_constr = constr.scalar_constraint

    # Check that all variables in the constraint belong to this model
    vars = constraint_variables(jump_constr)
    for var in vars
        if !(var.model === model)
            error("Variable in constraint does not belong to the model")
        end
    end

    # Check if the constraint is a valid GP constraint
    is_valid = is_valid_gp_constraint(jump_constr)
    if !is_valid
        error("Constraint is not a valid geometric programming constraint")
    end

    # Determine if it's an equality or inequality constraint
    set = JuMP.moi_set(jump_constr)
    is_equality = set isa MOI.EqualTo

    # Create the constraint data
    constr_data =
        GPConstraintData(jump_constr, name, is_equality, is_valid, constr.negate_dual)

    # Add the constraint to the model's constraints list
    push!(model.constraints, constr_data)
    index = length(model.constraints)

    # Return a constraint reference
    return GPConstraintRef(model, index)
end

# Add a constraint to the SPModel
function JuMP.add_constraint(model::SPModel, constr::GPScalarConstraint, name::String = "")

    jump_constr = constr.scalar_constraint

    # Check that all variables in the constraint belong to this model
    vars = constraint_variables(jump_constr)
    for var in vars
        if !(var.model === model)
            error("Variable in constraint does not belong to the model")
        end
    end

    # Check if the constraint is a valid SP constraint
    is_valid = is_valid_sp_constraint(jump_constr)
    if !is_valid
        error("Constraint is not a valid signomial programming constraint")
    end

    # Determine if it's an equality or inequality constraint
    set = JuMP.moi_set(jump_constr)
    is_equality = set isa MOI.EqualTo

    # Create the constraint data
    constr_data = SPConstraintData(
        jump_constr,
        name,
        is_equality,
        is_valid,
        constr.negate_dual,
        constr.is_signomial_constraint,
    )

    # Add the constraint to the model's constraints list
    push!(model.constraints, constr_data)
    index = length(model.constraints)

    # Return a constraint reference
    return SPConstraintRef(model, index)
end

# Helper functions to analyze SignomialExpressions for constraint validation

# Check if a SignomialExpression represents a valid GP equality constraint in normalized form
# This is the case when the expression is of the form m1 - m2 == 0, where m1 and m2 are monomials
function split_lhs_rhs(expr::SignomialExpression)
    # We need exactly one positive term and one negative term
    pos_terms = [t for t in expr.terms if t.coefficient > 0]
    neg_terms = [t for t in expr.terms if t.coefficient < 0]

    # type unstable, but we're ok with that
    p_lhs = 0.0
    p_rhs = 0.0

    if length(pos_terms) == 0
        p_lhs = 0.0
    elseif length(pos_terms) == 1
        p_lhs = MonomialExpression(pos_terms[1])
    else
        p_lhs = PosynomialExpression(pos_terms)
    end
    if length(neg_terms) == 0
        p_rhs = 0.0
    elseif length(neg_terms) == 1
        neg_term = neg_terms[1]
        p_rhs = MonomialExpression(MonomialTerm(-neg_term.coefficient, neg_term.exponents))
    else
        p_rhs = PosynomialExpression([
            MonomialTerm(-t.coefficient, t.exponents) for t in neg_terms
        ])
    end

    return p_lhs, p_rhs
end

# Build a constraint for the GPModel
function JuMP.build_constraint(
    _error::Function,
    func::AbstractGPSPExpression,
    set::Union{MOI.EqualTo,MOI.LessThan,MOI.GreaterThan},
)
    # Special case handling for SignomialExpressions, which may represent valid GP constraints
    # after JuMP's normalization (e.g., x*y - z == 0 representing x*y == z)
    if func isa SignomialExpression
        if set isa MOI.EqualTo
            # Check if this represents a valid monomial == monomial constraint
            lhs, rhs = split_lhs_rhs(func)
            if is_monomial(lhs) && is_monomial(rhs) && !iszero(rhs)
                # Convert to the standard form lhs/rhs == 1 for GP
                return GPScalarConstraint(
                    JuMP.ScalarConstraint(lhs / rhs, MOI.EqualTo(1.0)),
                )
            else
                _error(
                    "Equality constraints in geometric and signomial programming must involve monomials on both sides",
                )
            end
        elseif set isa MOI.GreaterThan
            # Check if this represents a valid monomial > monomial constraint
            lhs, rhs = split_lhs_rhs(func)
            if is_monomial(lhs) && is_monomial(rhs) && !iszero(rhs)
                # Convert to the standard form rhs/lhs < 1 for GP
                return GPScalarConstraint(
                    JuMP.ScalarConstraint(rhs / lhs, MOI.LessThan(1.0)),
                    negate_dual = true,
                )
            else
                return GPScalarConstraint(
                    JuMP.ScalarConstraint(rhs - lhs, MOI.LessThan(0.0)),
                    negate_dual = true,
                    is_signomial_constraint = true,
                )
            end
        elseif set isa MOI.LessThan
            # Check if this represents a valid posynomial <= monomial constraint
            lhs, rhs = split_lhs_rhs(func)
            if is_posynomial(lhs) && is_monomial(rhs) && !iszero(rhs)
                # Convert to the standard form lhs/rhs <= 1 for GP
                return GPScalarConstraint(
                    JuMP.ScalarConstraint(lhs / rhs, MOI.LessThan(1.0)),
                )
            else
                return GPScalarConstraint(
                    JuMP.ScalarConstraint(lhs - rhs, MOI.LessThan(0.0)),
                    is_signomial_constraint = true,
                )
            end
        end
    else
        # For equality constraints (==) with value, we require monomials
        if set isa MOI.EqualTo
            # This is invalid for both GP and SP
            _error("Equality constraints in geometric programming must involve monomials")
        elseif set isa MOI.LessThan
            return GPScalarConstraint(
                JuMP.ScalarConstraint(func, set),
                is_signomial_constraint = true,
            )
        elseif set isa MOI.GreaterThan
            return GPScalarConstraint(
                JuMP.ScalarConstraint(func, set),
                is_signomial_constraint = true,
            )
        end

    end
end

# Handle expressions with variables on both sides by moving all terms to one side
function JuMP.build_constraint(
    _error::Function,
    lhs::AbstractGPSPExpression,
    set::MOI.EqualTo{Float64},
    rhs::AbstractGPSPExpression,
)
    # For equality constraints, check if both sides are monomials
    if !is_monomial(lhs) || !is_monomial(rhs)
        _error(
            "Equality constraints in geometric programming must have monomial expressions on both sides",
        )
    end

    # Handle all combinations of monomial-type expressions
    lhs_mono = lhs isa GPVariable ? as_monomial(lhs) : lhs
    rhs_mono = rhs isa GPVariable ? as_monomial(rhs) : rhs

    # Create lhs/rhs = 1 form which is the standard GP equality constraint form
    return JuMP.ScalarConstraint(lhs_mono / rhs_mono, MOI.EqualTo(1.0))
end

# Handle inequality constraints with expressions on both sides
function JuMP.build_constraint(
    _error::Function,
    lhs::AbstractGPSPExpression,
    set::MOI.LessThan{Float64},
    rhs::AbstractGPSPExpression,
)
    # For inequality constraints in GP, the LHS must be a posynomial or monomial,
    # and the RHS must be a monomial
    lhs_valid = is_posynomial(lhs) || is_monomial(lhs)
    rhs_valid = is_monomial(rhs)

    if !lhs_valid || !rhs_valid
        _error(
            "Inequality constraints in geometric programming must have posynomial or monomial LHS and monomial RHS",
        )
    end

    # Convert the right-hand side to a monomial if it's a variable
    rhs_mono = rhs isa GPVariable ? as_monomial(rhs) : rhs

    # If rhs is a monomial, we can divide by it to get lhs/rhs <= 1 form
    if rhs_mono isa MonomialExpression
        # Return lhs/rhs <= 1 constraint (standard form for GP)
        return GPScalarConstraint(JuMP.ScalarConstraint(lhs / rhs_mono, MOI.LessThan(1.0)))
    elseif rhs isa PosynomialExpression
        # If it looks like a PosynomialExpression but has only one term,
        # we can treat it as a monomial
        if length(rhs.terms) == 1
            rhs_mono = MonomialExpression(rhs.terms[1])
            return GPScalarConstraint(
                JuMP.ScalarConstraint(lhs / rhs_mono, MOI.LessThan(1.0)),
            )
        else
            # A true posynomial on the RHS is not a valid constraint in GP
            _error(
                "Inequality constraints cannot have posynomials on both sides. Try rewriting.",
            )
        end
    else
        _error("Unexpected expression types in inequality constraint")
    end
end

# Constraint name accessor
function JuMP.name(cref::ConstraintRef)
    # Get the constraint data
    constr_data = cref.model.constraints[cref.index]
    return constr_data.name
end

# Check if a constraint is valid
function JuMP.is_valid(model::AbstractSpGpModel, cref::ConstraintRef)
    # Check if the constraint reference matches the model and index is valid
    return (cref.model === model && 1 <= cref.index <= length(model.constraints))
end

# Get the constraint function
function JuMP.constraint_object(cref::ConstraintRef)
    # Return the JuMP constraint object
    return cref.model.constraints[cref.index].constraint
end


"""
    JuMP.dual(cref::GPConstraintRef) -> Float64

Returns the dual value (sensitivity) of the constraint.

# Arguments
- `cref::GPConstraintRef`: The constraint reference

# Returns
- The dual value of the constraint

# Throws
- Error if the model has not been solved yet or if dual values are not available
"""
function JuMP.dual(cref::ConstraintRef)
    model = cref.model

    # Check if the model has been solved
    if isnothing(model.solution_info.termination_status)
        error("Model has not been solved yet")
    end

    # Check if dual values are available
    if isnothing(model.solution_info.constraint_duals)
        error("Dual values not available. Make sure the solver supports dual values.")
    end

    # Get the dual value for this constraint
    if haskey(model.solution_info.constraint_duals, cref.index)
        multiplier = cref.model.constraints[cref.index].negate_dual ? -1.0 : 1.0
        return model.solution_info.constraint_duals[cref.index] * multiplier
    else
        error("Dual value not available for this constraint")
    end
end

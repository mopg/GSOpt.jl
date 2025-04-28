"""
    Constraints for geometric programming.
    
This module implements constraint handling for geometric programming models:
- Monomial equality constraints (e.g., x * y == z)
- Posynomial inequality constraints (e.g., x + y <= z)

Constraints are validated at creation time to ensure they conform to geometric
programming rules.
"""

# Define a constraint reference type for our GPModel
struct GPConstraintRef
    model::GPModel
    index::Int

    # Constructor
    function GPConstraintRef(model::GPModel, index::Int)
        return new(model, index)
    end
end

# Make our expression types compatible with JuMP's constraint system
# These methods allow AbstractGPExpression types to be used in JuMP constraints
Base.broadcastable(x::AbstractGPExpression) = Ref(x)
Base.convert(::Type{JuMP.AbstractJuMPScalar}, x::AbstractGPExpression) = x

# Enable JuMP to create ScalarConstraint with our custom types
function JuMP.ScalarConstraint(func::AbstractGPExpression, set::MOI.AbstractScalarSet)
    return JuMP.ScalarConstraint{AbstractGPExpression,typeof(set)}(func, set)
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

# Add a constraint to the GPModel
function JuMP.add_constraint(
    model::GPModel,
    constr::JuMP.AbstractConstraint,
    name::String=""
)
    # Check that all variables in the constraint belong to this model
    vars = constraint_variables(constr)
    for var in vars
        if !(var.model === model)
            error("Variable in constraint does not belong to the model")
        end
    end

    # Check if the constraint is a valid GP constraint
    is_valid = is_valid_gp_constraint(constr)
    if !is_valid
        error("Constraint is not a valid geometric programming constraint")
    end

    # Determine if it's an equality or inequality constraint
    set = JuMP.moi_set(constr)
    is_equality = set isa MOI.EqualTo

    # Create the constraint data
    constr_data = GPConstraintData(
        constr,
        name,
        is_equality,
        is_valid
    )

    # Add the constraint to the model's constraints list
    push!(model.constraints, constr_data)
    index = length(model.constraints)

    # Return a constraint reference
    return GPConstraintRef(model, index)
end

# Helper functions to analyze SignomialExpressions for constraint validation

# Check if a SignomialExpression represents a valid GP equality constraint in normalized form
# This is the case when the expression is of the form m1 - m2 == 0, where m1 and m2 are monomials
function is_normalized_monomial_constraint(expr::SignomialExpression)
    # We need exactly one positive term and one negative term
    pos_terms = [t for t in expr.terms if t.coefficient > 0]
    neg_terms = [t for t in expr.terms if t.coefficient < 0]

    if length(pos_terms) != 1 || length(neg_terms) != 1
        return false, nothing, nothing
    end

    # Extract the positive and negative terms
    pos_term = pos_terms[1]
    neg_term = neg_terms[1]

    # Create monomial expressions from these terms
    lhs = MonomialExpression(pos_term)
    rhs = MonomialExpression(MonomialTerm(-neg_term.coefficient, neg_term.exponents))

    # Check that both are valid monomials
    return true, lhs, rhs
end

# Check if a SignomialExpression represents a valid GP inequality constraint in normalized form
# This is the case when the expression is of the form p - m <= 0, where p is a posynomial and m is a monomial
function is_normalized_posynomial_inequality(expr::SignomialExpression)
    # Get all positive and negative terms
    pos_terms = [t for t in expr.terms if t.coefficient > 0]
    neg_terms = [t for t in expr.terms if t.coefficient < 0]

    # For a valid posynomial inequality, we need at least one positive term
    # And exactly one negative term (representing the right side monomial)
    if length(neg_terms) != 1
        return false, nothing, nothing
    end

    # The negative term should be a monomial (the right side of the inequality)
    neg_term = neg_terms[1]

    # Create the right-hand side monomial
    rhs = MonomialExpression(MonomialTerm(-neg_term.coefficient, neg_term.exponents))

    # Create the left-hand side posynomial
    lhs = length(pos_terms) == 1 ?
          MonomialExpression(pos_terms[1]) :
          PosynomialExpression(pos_terms)

    return true, lhs, rhs
end

# Build a constraint for the GPModel
function JuMP.build_constraint(
    _error::Function,
    func::AbstractGPExpression,
    set::Union{MOI.EqualTo,MOI.LessThan,MOI.GreaterThan}
)
    # Special case handling for SignomialExpressions, which may represent valid GP constraints
    # after JuMP's normalization (e.g., x*y - z == 0 representing x*y == z)
    if func isa SignomialExpression
        if set isa MOI.EqualTo
            # Check if this represents a valid monomial == monomial constraint
            is_valid, lhs, rhs = is_normalized_monomial_constraint(func)
            if is_valid
                # Convert to the standard form lhs/rhs == 1 for GP
                return JuMP.ScalarConstraint(lhs / rhs, MOI.EqualTo(1.0))
            else
                _error("Equality constraints in geometric programming must involve monomials on both sides")
            end
        elseif set isa MOI.GreaterThan
            # Check if this represents a valid monomial > monomial constraint
            is_valid, lhs, rhs = is_normalized_monomial_constraint(func)
            if is_valid
                # Convert to the standard form rhs/lhs < 1 for GP
                return JuMP.ScalarConstraint(rhs / lhs, MOI.LessThan(1.0))
            else
                _error("Inequality constraints in geometric programming must involve monomials on both sides")
            end
        elseif set isa MOI.LessThan
            # Check if this represents a valid posynomial <= monomial constraint
            is_valid, lhs, rhs = is_normalized_posynomial_inequality(func)
            if is_valid
                # Convert to the standard form lhs/rhs <= 1 for GP
                return JuMP.ScalarConstraint(lhs / rhs, MOI.LessThan(1.0))
            else
                _error("Inequality constraints in geometric programming must have posynomial LHS and monomial RHS")
            end
        end
    else
        # For equality constraints (==) with value, we require monomials
        if set isa MOI.EqualTo
            if !is_monomial(func)
                _error("Equality constraints in geometric programming must involve monomials")
            end
            # Special case: if we're comparing to zero, that's invalid in GP (log(0) = -∞)
            if set.value == 0
                _error("Equality constraints cannot have zero on the right side in geometric programming")
            end
            # For inequality constraints (<=) with value, we require posynomials
        elseif set isa MOI.LessThan
            if !is_posynomial(func)
                _error("Inequality constraints in geometric programming must be posynomials")
            end
            # Special case: if we're comparing to zero, that's invalid in GP (log(0) = -∞)
            if set.value == 0
                _error("Inequality constraints cannot have zero on the right side in geometric programming")
            end
        end

        # If we're not comparing to 0, create the constraint
        return JuMP.ScalarConstraint(func, set)
    end
end

# Handle expressions with variables on both sides by moving all terms to one side
function JuMP.build_constraint(
    _error::Function,
    lhs::AbstractGPExpression,
    set::MOI.EqualTo{Float64},
    rhs::AbstractGPExpression
)
    # For equality constraints, check if both sides are monomials
    if !is_monomial(lhs) || !is_monomial(rhs)
        _error("Equality constraints in geometric programming must have monomial expressions on both sides")
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
    lhs::AbstractGPExpression,
    set::MOI.LessThan{Float64},
    rhs::AbstractGPExpression
)
    # For inequality constraints in GP, the LHS must be a posynomial or monomial,
    # and the RHS must be a monomial
    lhs_valid = is_posynomial(lhs) || is_monomial(lhs)
    rhs_valid = is_monomial(rhs)

    if !lhs_valid || !rhs_valid
        _error("Inequality constraints in geometric programming must have posynomial or monomial LHS and monomial RHS")
    end

    # Convert the right-hand side to a monomial if it's a variable
    rhs_mono = rhs isa GPVariable ? as_monomial(rhs) : rhs

    # If rhs is a monomial, we can divide by it to get lhs/rhs <= 1 form
    if rhs_mono isa MonomialExpression
        # Return lhs/rhs <= 1 constraint (standard form for GP)
        return JuMP.ScalarConstraint(lhs / rhs_mono, MOI.LessThan(1.0))
    elseif rhs isa PosynomialExpression
        # If it looks like a PosynomialExpression but has only one term,
        # we can treat it as a monomial
        if length(rhs.terms) == 1
            rhs_mono = MonomialExpression(rhs.terms[1])
            return JuMP.ScalarConstraint(lhs / rhs_mono, MOI.LessThan(1.0))
        else
            # A true posynomial on the RHS is not a valid constraint in GP
            _error("Inequality constraints cannot have posynomials on both sides. Try rewriting.")
        end
    else
        _error("Unexpected expression types in inequality constraint")
    end
end

# Constraint name accessor
function JuMP.name(cref::GPConstraintRef)
    # Get the constraint data
    constr_data = cref.model.constraints[cref.index]
    return constr_data.name
end

# Check if a constraint is valid
function JuMP.is_valid(model::GPModel, cref::GPConstraintRef)
    # Check if the constraint reference matches the model and index is valid
    return (cref.model === model &&
            1 <= cref.index <= length(model.constraints))
end

# Get the constraint function
function JuMP.constraint_object(cref::GPConstraintRef)
    # Return the JuMP constraint object
    return cref.model.constraints[cref.index].constraint
end

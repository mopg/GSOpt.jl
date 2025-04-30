"""
    Constraint types for geometric programming models.

Constraints in geometric programming are limited to:
- Posynomial inequality constraints (≤ 1)
- Monomial equality constraints (= 1)
"""

"""
    GPConstraintData

A data structure to store constraint information for geometric programming models.

# Fields
- `constraint::JuMP.AbstractConstraint`: The JuMP constraint object
- `name::String`: Constraint name for identification
- `is_equality::Bool`: Whether the constraint is an equality (true) or inequality (false)
- `is_valid_gp::Bool`: Whether the constraint is a valid GP constraint (monomial equality or posynomial inequality)
- `negate_dual::Bool`: Whether the dual of the constraint should be negated (used for inequality constraints)
"""
struct GPConstraintData
    constraint::JuMP.AbstractConstraint
    name::String
    is_equality::Bool
    is_valid_gp::Bool
    negate_dual::Bool
end

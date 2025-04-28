"""
    Variable handling for geometric programming.
    
Extends JuMP's variable functionality to ensure all variables are strictly positive.

Requirements:
- All variables must have positive lower bounds
- Variables can have upper bounds or be fixed to positive values
- Variables cannot have negative bounds
"""

"""
    GPVariable <: AbstractGPVariable

A variable in a geometric programming model. This type stores information about
the variable but doesn't create a JuMP variable until the model is transformed to log space.

# Fields
- `model::GPModel`: The model that owns this variable
- `index::Int`: Unique identifier for the variable within the model
- `name::String`: Variable name
- `lower_bound::Union{Float64,Nothing}`: Lower bound (must be positive if specified)
- `upper_bound::Union{Float64,Nothing}`: Upper bound (must be positive if specified)
- `fixed_value::Union{Float64,Nothing}`: Fixed value (must be positive if specified)

# Example
```julia
using GSOpt

model = GPModel()

# Create variables with positive lower bounds
x = @variable(model, x >= 1)
y = @variable(model, y >= 2, upper_bound=10)
z = @variable(model, z == 5)  # Fixed variable
```
"""
struct GPVariable <: AbstractGPVariable
    model::GPModel
    index::Int  # Used to identify this variable
    name::String
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
    fixed_value::Union{Float64,Nothing}

    # Constructor with mandatory positive lower bound
    function GPVariable(
        model::GPModel,
        name::String,
        index::Int;
        lower_bound::Union{<:Real,Nothing}=nothing,
        upper_bound::Union{<:Real,Nothing}=nothing,
        fixed_value::Union{<:Real,Nothing}=nothing,
    )

        # Validate bounds for GP variables
        if lower_bound !== nothing && lower_bound <= 0
            error("Variables in geometric programming models must have positive lower bounds")
        end

        if upper_bound !== nothing && upper_bound <= 0
            error("Variables in geometric programming models must have positive upper bounds")
        end

        if fixed_value !== nothing && fixed_value <= 0
            error("Fixed variables in geometric programming models must have positive values")
        end

        return new(
            model,
            index,
            name,
            lower_bound === nothing ? nothing : Float64(lower_bound),
            upper_bound === nothing ? nothing : Float64(upper_bound),
            fixed_value === nothing ? nothing : Float64(fixed_value)
        )
    end
end

# Implement required JuMP interface for GPVariable

"""
    JuMP.owner_model(v::GPVariable) -> GPModel

Returns the model that owns this variable.
"""
function JuMP.owner_model(v::GPVariable)
    return v.model
end

"""
    JuMP.name(v::GPVariable) -> String

Returns the name of the variable.
"""
function JuMP.name(v::GPVariable)
    return v.name
end

"""
    JuMP.value(var::GPVariable) -> Float64

Returns the value of the variable after optimization.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.value(var::GPVariable)
    model = var.model
    if isnothing(model.variable_values)
        error("Model has not been solved yet")
    end
    return get(model.variable_values, var.index, 0.0)
end

"""
    JuMP.is_valid(model::GPModel, var::GPVariable) -> Bool

Checks if a variable belongs to the specified model and is still valid.
"""
function JuMP.is_valid(model::GPModel, var::GPVariable)
    return var.model === model && 1 <= var.index <= length(model.variables) && model.variables[var.index] === var
end

JuMP.index(v::GPVariable) = v.index
Base.:(==)(v::GPVariable, w::GPVariable) = v.model === w.model && v.index == w.index
Base.broadcastable(v::GPVariable) = Ref(v)

# Bounds and fixed value accessors
JuMP.has_lower_bound(v::GPVariable) = v.lower_bound !== nothing
JuMP.lower_bound(v::GPVariable) = JuMP.has_lower_bound(v) ? v.lower_bound : error("Variable does not have a lower bound")
JuMP.has_upper_bound(v::GPVariable) = v.upper_bound !== nothing
JuMP.upper_bound(v::GPVariable) = JuMP.has_upper_bound(v) ? v.upper_bound : error("Variable does not have an upper bound")
JuMP.is_fixed(v::GPVariable) = v.fixed_value !== nothing
JuMP.fix_value(v::GPVariable) = JuMP.is_fixed(v) ? v.fixed_value : error("Variable is not fixed")

# Handle variable creation for GPModel
function JuMP.add_variable(model::GPModel, v::JuMP.ScalarVariable, name::String="")
    # Validate that the variable bounds are compatible with GP
    # In geometric programming, all variables must be strictly positive
    if v.info.has_lb && v.info.lower_bound <= 0
        error("Variables in geometric programming models must have positive lower bounds")
    end

    if v.info.has_fix && v.info.fixed_value <= 0
        error("Variables in geometric programming models must have positive fixed values")
    end

    # Extract the relevant information from the variable
    lower_bound = v.info.has_lb ? v.info.lower_bound : 1e-6
    upper_bound = v.info.has_ub ? v.info.upper_bound : nothing
    fixed_value = v.info.has_fix ? v.info.fixed_value : nothing

    # Get a unique index for this variable
    index = length(model.variables) + 1

    # Create a GPVariable with the provided information
    gp_var = GPVariable(
        model,
        name,
        index,
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        fixed_value=fixed_value,
    )

    # Store the variable in our variables list
    push!(model.variables, gp_var)

    return gp_var
end

# Handle constrained variables
function JuMP.add_variable(
    model::GPModel,
    v::JuMP.VariableConstrainedOnCreation{S},
    name::String="",
) where {S<:MOI.AbstractScalarSet}
    # Check the constraint bound for GP compliance
    local lower_bound = 1e-6  # Default positive lower bound
    local upper_bound = nothing
    local fixed_value = nothing

    if v.set isa MOI.GreaterThan
        if v.set.lower <= 0
            error("Variables in geometric programming models must have positive lower bounds")
        end
        lower_bound = v.set.lower
    elseif v.set isa MOI.LessThan
        # For GP, we should only allow lower bounds on variables
        error("Variables in geometric programming models should only use lower bounds (≥), not upper bounds (≤)")
    elseif v.set isa MOI.EqualTo
        if v.set.value <= 0
            error("Variables in geometric programming models must have positive values")
        end
        fixed_value = v.set.value
    elseif v.set isa MOI.Interval
        if v.set.lower <= 0
            error("Variables in geometric programming models must have positive lower bounds")
        end
        lower_bound = v.set.lower
        upper_bound = v.set.upper
    end

    # Get a unique index for this variable
    index = length(model.variables) + 1

    # Create our custom GPVariable
    gp_var = GPVariable(
        model,
        name,
        index,
        lower_bound=lower_bound,
        upper_bound=upper_bound,
        fixed_value=fixed_value
    )

    # Store the variable in our variables list
    push!(model.variables, gp_var)

    return gp_var
end

# Build a variable for the GPModel
function JuMP.build_variable(
    _error::Function,
    info::JuMP.VariableInfo,
    ::Type{GPVariable};
    extra_kw_args...
)
    # Perform GP-specific validation
    if info.has_lb && info.lower_bound <= 0
        _error("Variables in geometric programming models must have positive lower bounds")
    end

    if info.has_fix && info.fixed_value <= 0
        _error("Fixed variables in geometric programming models must have positive values")
    end

    # For GP variables, we always want to ensure a positive lower bound
    # but we'll do this in add_variable, so just pass through the info for now
    # This builds a ScalarVariable that will be interpreted correctly by add_variable
    return JuMP.ScalarVariable(info)
end

# We need this variant to handle the case where a regular VariableRef is requested
# but we're in a GPModel context
function JuMP.build_variable(
    _error::Function,
    info::JuMP.VariableInfo,
    ::Type{JuMP.VariableRef};
    extra_kw_args...
)
    # Delegate to our GPVariable handler
    return JuMP.build_variable(_error, info, GPVariable; extra_kw_args...)
end

"""
    Base.show(io::IO, v::GPVariable)

Pretty-prints the variable, showing its name and bounds or fixed value.
"""
function Base.show(io::IO, v::GPVariable)
    print(io, v.name)
    if JuMP.is_fixed(v)
        print(io, " = ", JuMP.fix_value(v))
    else
        if JuMP.has_lower_bound(v)
            print(io, " ≥ ", JuMP.lower_bound(v))
        end
        if JuMP.has_upper_bound(v)
            print(io, " ≤ ", JuMP.upper_bound(v))
        end
    end
end

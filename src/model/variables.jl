"""
    Variable handling for geometric and signomial programming.
    
Extends JuMP's variable functionality to handle both geometric programming (GP) 
and signomial programming (SP) variables.

Requirements:
- All variables must have positive lower bounds
- Variables can have upper bounds or be fixed to positive values
- Variables cannot have negative bounds
- SP variables can have starting points for optimization
"""

"""
    Variable information structure for GP and SP variables.
    
Contains common fields shared between GPVariable and SPVariable.

# Fields
- `index::Int`: Unique identifier for the variable within the model
- `name::String`: Variable name
- `lower_bound::Union{Float64,Nothing}`: Lower bound (must be positive if specified)
- `upper_bound::Union{Float64,Nothing}`: Upper bound (must be positive if specified)
- `fixed_value::Union{Float64,Nothing}`: Fixed value (must be positive if specified)
"""
struct VariableInfo
    index::Int
    name::String
    lower_bound::Union{Float64,Nothing}
    upper_bound::Union{Float64,Nothing}
    fixed_value::Union{Float64,Nothing}

    # Constructor with validation for GP/SP variable requirements
    function VariableInfo(
        index::Int,
        name::String;
        lower_bound::Union{<:Real,Nothing} = nothing,
        upper_bound::Union{<:Real,Nothing} = nothing,
        fixed_value::Union{<:Real,Nothing} = nothing,
    )
        # Validate bounds for GP/SP variables
        if lower_bound !== nothing && lower_bound <= 0
            error(
                "Variables in geometric/signomial programming models must have positive lower bounds",
            )
        end

        if upper_bound !== nothing && upper_bound <= 0
            error(
                "Variables in geometric/signomial programming models must have positive upper bounds",
            )
        end

        if fixed_value !== nothing && fixed_value <= 0
            error(
                "Fixed variables in geometric/signomial programming models must have positive values",
            )
        end

        return new(
            index,
            name,
            lower_bound === nothing ? nothing : Float64(lower_bound),
            upper_bound === nothing ? nothing : Float64(upper_bound),
            fixed_value === nothing ? nothing : Float64(fixed_value),
        )
    end
end

"""
    GPVariable <: AbstractGPVariable
    
A variable in a geometric programming model. This type uses composition with
VariableInfo to store common variable information.

# Fields
- `model::GPModel`: The model that owns this variable
- `info::VariableInfo`: Common variable information (index, name, bounds, etc.)
"""
struct GPVariable <: AbstractGPVariable
    model::GPModel
    info::VariableInfo

    # Constructor with mandatory positive lower bound
    function GPVariable(
        model::GPModel,
        name::String,
        index::Int;
        lower_bound::Union{<:Real,Nothing} = nothing,
        upper_bound::Union{<:Real,Nothing} = nothing,
        fixed_value::Union{<:Real,Nothing} = nothing,
    )
        # Create VariableInfo for common data
        var_info = VariableInfo(
            index,
            name,
            lower_bound = lower_bound,
            upper_bound = upper_bound,
            fixed_value = fixed_value,
        )

        return new(model, var_info)
    end
end

"""
    SPVariable <: AbstractSPGPVariable
    
A variable in a signomial programming model. Extends variable information
with a starting point for optimization.

# Fields
- `model::SPModel`: The signomial programming model that owns this variable
- `info::VariableInfo`: Common variable information (index, name, bounds, etc.)
- `start_value::Float64`: Starting point for optimization algorithms
"""
struct SPVariable <: AbstractSPVariable
    model::SPModel
    info::VariableInfo
    start_value::Union{Float64,Nothing}
    linearization_points::Vector{Float64}

    # Constructor with starting point
    function SPVariable(
        model::SPModel,
        name::String,
        index::Int;
        lower_bound::Union{<:Real,Nothing} = nothing,
        upper_bound::Union{<:Real,Nothing} = nothing,
        fixed_value::Union{<:Real,Nothing} = nothing,
        start_value::Union{<:Real,Nothing} = nothing,
    )
        # Create VariableInfo for common data
        var_info = VariableInfo(
            index,
            name,
            lower_bound = lower_bound,
            upper_bound = upper_bound,
            fixed_value = fixed_value,
        )

        return new(model, var_info, start_value, Float64[])
    end
end

function latest_linearization_point(v::SPVariable)
    if isempty(v.linearization_points)
        if JuMP.has_start_value(v)
            return JuMP.start_value(v)
        end

        # If both upper and lower bound are specified, return the midpoint
        if JuMP.has_lower_bound(v) && JuMP.has_upper_bound(v)
            return (JuMP.lower_bound(v) + JuMP.upper_bound(v)) / 2
        end

        # If only lower bound is specified, return the lower bound
        if JuMP.has_lower_bound(v)
            return JuMP.lower_bound(v)
        end

        # If only upper bound is specified, return the upper bound
        if JuMP.has_upper_bound(v)
            return JuMP.upper_bound(v)
        end

        return 1.0
    end
    return v.linearization_points[end]
end

function add_linearization_point(v::SPVariable, point::Float64)
    push!(v.linearization_points, point)
end

"""
    JuMP.owner_model(v::SPVariable) -> SPModel

Returns the model that owns this variable.
"""
function JuMP.owner_model(v::SPVariable)::SPModel
    return v.model
end

"""
    JuMP.owner_model(v::GPVariable) -> GPModel

Returns the model that owns this variable.
"""
function JuMP.owner_model(v::GPVariable)::GPModel
    return v.model
end

"""
    JuMP.name(v::AbstractSPGPVariable) -> String

Returns the name of the variable.
"""
function JuMP.name(v::AbstractSPGPVariable)
    return v.info.name
end

"""
    JuMP.value(var::AbstractSPGPVariable) -> Float64

Returns the value of the variable after optimization.

# Throws
- Error if the model has not been solved yet
"""
function JuMP.value(var::AbstractSPGPVariable)
    model = var.model
    if isnothing(model.solution_info.variable_values)
        error("Model has not been solved yet")
    end
    return get(model.solution_info.variable_values, var.info.index, 0.0)
end

"""
    JuMP.is_valid(model::GPModel, var::GPVariable) -> Bool

Checks if a variable belongs to the specified model and is still valid.
"""
function JuMP.is_valid(model::GPModel, var::GPVariable)
    return var.model === model &&
           1 <= var.info.index <= length(model.variables) &&
           model.variables[var.info.index] === var
end

function JuMP.is_valid(model::SPModel, var::SPVariable)
    return var.model === model &&
           1 <= var.info.index <= length(model.variables) &&
           model.variables[var.info.index] === var
end

JuMP.index(v::AbstractSPGPVariable) = v.info.index
Base.:(==)(v::GPVariable, w::GPVariable) =
    v.model === w.model && v.info.index == w.info.index
Base.:(==)(v::SPVariable, w::SPVariable) =
    v.model === w.model && v.info.index == w.info.index
Base.broadcastable(v::AbstractSPGPVariable) = Ref(v)

# Bounds and fixed value accessors
JuMP.has_lower_bound(v::AbstractSPGPVariable) = v.info.lower_bound !== nothing
JuMP.lower_bound(v::AbstractSPGPVariable) =
    JuMP.has_lower_bound(v) ? v.info.lower_bound :
    error("Variable does not have a lower bound")
JuMP.has_upper_bound(v::AbstractSPGPVariable) = v.info.upper_bound !== nothing
JuMP.upper_bound(v::AbstractSPGPVariable) =
    JuMP.has_upper_bound(v) ? v.info.upper_bound :
    error("Variable does not have an upper bound")
JuMP.is_fixed(v::AbstractSPGPVariable) = v.info.fixed_value !== nothing
JuMP.fix_value(v::AbstractSPGPVariable) =
    JuMP.is_fixed(v) ? v.info.fixed_value : error("Variable is not fixed")
JuMP.start_value(v::GPVariable) = nothing
JuMP.start_value(v::SPVariable) = v.start_value
JuMP.has_start_value(v::GPVariable) = false
JuMP.has_start_value(v::SPVariable) = JuMP.start_value(v) !== nothing

# Handle variable creation for GPModel
function JuMP.add_variable(model::GPModel, v::JuMP.ScalarVariable, name::String = "")
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
        lower_bound = lower_bound,
        upper_bound = upper_bound,
        fixed_value = fixed_value,
    )

    # Store the variable in our variables list
    push!(model.variables, gp_var)

    return gp_var
end

# Handle constrained variables
function JuMP.add_variable(
    model::GPModel,
    v::JuMP.VariableConstrainedOnCreation{S},
    name::String = "",
) where {S<:MOI.AbstractScalarSet}
    # Check the constraint bound for GP compliance
    local lower_bound = 1e-6  # Default positive lower bound
    local upper_bound = nothing
    local fixed_value = nothing

    if v.set isa MOI.GreaterThan
        if v.set.lower <= 0
            error(
                "Variables in geometric programming models must have positive lower bounds",
            )
        end
        lower_bound = v.set.lower
    elseif v.set isa MOI.LessThan
        # For GP, we should only allow lower bounds on variables
        error(
            "Variables in geometric programming models should only use lower bounds (≥), not upper bounds (≤)",
        )
    elseif v.set isa MOI.EqualTo
        if v.set.value <= 0
            error("Variables in geometric programming models must have positive values")
        end
        fixed_value = v.set.value
    elseif v.set isa MOI.Interval
        if v.set.lower <= 0
            error(
                "Variables in geometric programming models must have positive lower bounds",
            )
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
        lower_bound = lower_bound,
        upper_bound = upper_bound,
        fixed_value = fixed_value,
    )

    # Store the variable in our variables list
    push!(model.variables, gp_var)

    return gp_var
end

# Handle variable creation for SPModel
function JuMP.add_variable(model::SPModel, v::JuMP.ScalarVariable, name::String = "")
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
    start_value = v.info.has_start ? v.info.start : nothing

    # Get a unique index for this variable
    index = length(model.variables) + 1

    # Create a GPVariable with the provided information
    sp_var = SPVariable(
        model,
        name,
        index,
        lower_bound = lower_bound,
        upper_bound = upper_bound,
        fixed_value = fixed_value,
        start_value = start_value,
    )

    # Store the variable in our variables list
    push!(model.variables, sp_var)

    return sp_var
end

# Handle constrained variables
function JuMP.add_variable(
    model::SPModel,
    v::JuMP.VariableConstrainedOnCreation{S},
    name::String = "",
) where {S<:MOI.AbstractScalarSet}
    # Check the constraint bound for GP compliance
    local lower_bound = 1e-6  # Default positive lower bound
    local upper_bound = nothing
    local fixed_value = nothing

    if v.set isa MOI.GreaterThan
        if v.set.lower <= 0
            error(
                "Variables in geometric programming models must have positive lower bounds",
            )
        end
        lower_bound = v.set.lower
    elseif v.set isa MOI.LessThan
        # For GP, we should only allow lower bounds on variables
        error(
            "Variables in geometric programming models should only use lower bounds (≥), not upper bounds (≤)",
        )
    elseif v.set isa MOI.EqualTo
        if v.set.value <= 0
            error("Variables in geometric programming models must have positive values")
        end
        fixed_value = v.set.value
    elseif v.set isa MOI.Interval
        if v.set.lower <= 0
            error(
                "Variables in geometric programming models must have positive lower bounds",
            )
        end
        lower_bound = v.set.lower
        upper_bound = v.set.upper
    end

    # Get a unique index for this variable
    index = length(model.variables) + 1

    # Create our custom GPVariable
    sp_var = SPVariable(
        model,
        name,
        index,
        lower_bound = lower_bound,
        upper_bound = upper_bound,
        fixed_value = fixed_value,
        start_value = nothing,
    )

    # Store the variable in our variables list
    push!(model.variables, sp_var)

    return sp_var
end

# Build a variable for the GPModel
function JuMP.build_variable(
    _error::Function,
    info::JuMP.VariableInfo,
    ::Type{<:AbstractSPGPVariable};
    extra_kw_args...,
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

# # We need this variant to handle the case where a regular VariableRef is requested
# # but we're in a GPModel context
# function JuMP.build_variable(
#     _error::Function,
#     info::JuMP.VariableInfo,
#     ::Type{JuMP.VariableRef};
#     extra_kw_args...,
# )
#     # Delegate to our GPVariable handler
#     return JuMP.build_variable(_error, info, GPVariable; extra_kw_args...)
# end

"""
    Base.show(io::IO, v::GPVariable)

Pretty-prints the variable, showing its name and bounds or fixed value.
"""
function Base.show(io::IO, v::GPVariable)
    print(io, v.info.name)
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

function Base.show(io::IO, v::SPVariable)
    print(io, v.info.name)
    if JuMP.is_fixed(v)
        print(io, " = ", JuMP.fix_value(v))
    else
        if JuMP.has_lower_bound(v)
            print(io, " ≥ ", JuMP.lower_bound(v))
        end
        if JuMP.has_upper_bound(v)
            print(io, " ≤ ", JuMP.upper_bound(v))
        end
        print(io, " (start: ", v.start_value, ")")
    end
end

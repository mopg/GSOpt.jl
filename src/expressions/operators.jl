"""
    Operator overloading for geometric programming expressions.
    
Operations supported:
- Multiplication (*): Creates MonomialExpressions
- Division (/): Creates MonomialExpressions
- Exponentiation (^): Creates MonomialExpressions
- Addition (+): Creates PosynomialExpressions or SignomialExpressions
- Subtraction (-): Creates SignomialExpressions
- Unary negation (-): Creates SignomialExpressions
"""


# Convert a GPVariable to a MonomialExpression
function as_monomial(v::AbstractSPGPVariable)
    return MonomialExpression(1.0, Dict(v => 1.0))
end

# Convert a constant to a MonomialExpression
function as_monomial(c::Real)
    if c <= 0
        error("Cannot convert non-positive constant to a monomial")
    end
    return MonomialExpression(c, Dict{GPVariable,Float64}())
end

#
# MULTIPLICATION OPERATIONS
#

# Variable * Variable
function Base.:*(x::T, y::T)::MonomialExpression where {T<:AbstractSPGPVariable}
    return MonomialExpression(1.0, Dict(x => 1.0, y => 1.0))
end

# Constant * Variable
function Base.:*(
    c::Real,
    x::T,
)::Union{MonomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c > 0
        return MonomialExpression(c, Dict(x => 1.0))
    else
        return SignomialExpression([MonomialTerm(c, Dict(x => 1.0))])
    end
end

# Variable * Constant
Base.:*(x::AbstractSPGPVariable, c::Real) = c * x

# Monomial * Monomial
function Base.:*(
    x::MonomialExpression{T},
    y::MonomialExpression{T},
)::MonomialExpression where {T<:AbstractSPGPVariable}
    # Combine coefficients
    coef = x.term.coefficient * y.term.coefficient

    # Combine exponents
    exponents = Dict{T,Float64}()

    # Add exponents from x
    for (var, exp) in x.term.exponents
        exponents[var] = get(exponents, var, 0.0) + exp
    end

    # Add exponents from y
    for (var, exp) in y.term.exponents
        exponents[var] = get(exponents, var, 0.0) + exp
    end

    return MonomialExpression(coef, exponents)
end

# Monomial * Variable
function Base.:*(x::MonomialExpression, y::AbstractSPGPVariable)::MonomialExpression
    return x * as_monomial(y)
end

# Variable * Monomial
Base.:*(x::AbstractSPGPVariable, y::MonomialExpression) = y * x

# Monomial * Constant
function Base.:*(
    x::MonomialExpression,
    c::Real,
)::Union{MonomialExpression,JuMP.NonlinearExpression}
    if c > 0
        return MonomialExpression(x.term.coefficient * c, copy(x.term.exponents))
    else
        # For negative constants, we create a SignomialExpression which we don't want to return
        # from multiplication, so we fall back to JuMP's NonlinearExpression
        m = first(values(x.term.exponents)).model
        return JuMP.@NLexpression(m, c * x)
    end
end

# Constant * Monomial
Base.:*(c::Real, x::MonomialExpression) = x * c

# Posynomial * Monomial and vice versa - these generally result in posynomials
function Base.:*(p::PosynomialExpression, m::MonomialExpression)::PosynomialExpression
    new_terms = [
        MonomialTerm(
            term.coefficient * m.term.coefficient,
            merge(+, copy(term.exponents), m.term.exponents),
        ) for term in p.terms
    ]

    return PosynomialExpression(new_terms)
end

Base.:*(m::MonomialExpression, p::PosynomialExpression) = p * m

# Variable * Posynomial
function Base.:*(v::AbstractSPGPVariable, p::PosynomialExpression)::PosynomialExpression
    return as_monomial(v) * p
end

# Posynomial * Variable
Base.:*(p::PosynomialExpression, v::AbstractSPGPVariable) = v * p

# Posynomial * Constant
function Base.:*(p::PosynomialExpression, c::Real)::PosynomialExpression
    return PosynomialExpression([
        MonomialTerm(p.terms[kk].coefficient * c, copy(p.terms[kk].exponents)) for
        kk = 1:length(p.terms)
    ])
end

# Constant * Posynomial
Base.:*(c::Real, p::PosynomialExpression)::PosynomialExpression = p * c

# Signomial * Real
function Base.:*(s::SignomialExpression, x::Real)
    return SignomialExpression([
        MonomialTerm(s.terms[kk].coefficient * x, copy(s.terms[kk].exponents)) for
        kk = 1:length(s.terms)
    ])
end

# Signomial * SPVariable
function Base.:*(s::SignomialExpression, v::SPVariable)
    return s * as_monomial(v)
end

# Signomial * Monomial
function Base.:*(s::SignomialExpression, m::MonomialExpression)::SignomialExpression

    new_terms = [
        MonomialTerm(
            term.coefficient * m.term.coefficient,
            merge(+, copy(term.exponents), m.term.exponents),
        ) for term in s.terms
    ]

    return SignomialExpression(new_terms)

end


# Anything * Signomial
Base.:*(x::Union{SPVariable,MonomialExpression,Real}, s::SignomialExpression) = s * x

# All operations with nonlinear expressions are not supported
function Base.:*(
    x::GenericNonlinearExpr{<:AbstractSPGPVariable},
    gp_expr::AbstractGPSPExpression,
)
    error(
        "Operations between nonlinear expressions and geometric programming expressions are not supported in the GP framework.",
    )
end

Base.:*(gp_expr::AbstractGPSPExpression, x::GenericNonlinearExpr{<:AbstractSPGPVariable}) =
    Base.:*(x, gp_expr)

#
# DIVISION OPERATIONS
#

# Variable / Variable
function Base.:/(x::AbstractSPGPVariable, y::AbstractSPGPVariable)::MonomialExpression
    return MonomialExpression(1.0, Dict(x => 1.0, y => -1.0))
end

# Variable / Constant
function Base.:/(
    x::AbstractSPGPVariable,
    c::Real,
)::Union{MonomialExpression,SignomialExpression}
    if c <= 0
        return SignomialExpression([MonomialTerm(1.0 / c, Dict(x => 1.0))])
    end
    return MonomialExpression(1.0 / c, Dict(x => 1.0))
end

# All division operations with nonlinear expressions are not supported
Base.:/(x::GenericNonlinearExpr{<:AbstractSPGPVariable}, gp_expr::AbstractGPSPExpression) =
    error(
        "Operations between nonlinear expressions and geometric programming expressions are not supported in the GP framework.",
    )

Base.:/(gp_expr::AbstractGPSPExpression, x::GenericNonlinearExpr{<:AbstractSPGPVariable}) =
    error(
        "Operations between nonlinear expressions and geometric programming expressions are not supported in the GP framework.",
    )

# Constant / Variable
function Base.:/(
    c::Real,
    x::AbstractSPGPVariable,
)::Union{MonomialExpression,SignomialExpression}
    if c <= 0
        return SignomialExpression([MonomialTerm(1.0 / c, Dict(x => -1.0))])
    end
    return MonomialExpression(c, Dict(x => -1.0))
end

# Monomial / Monomial
function Base.:/(
    x::MonomialExpression{T},
    y::MonomialExpression{T},
)::MonomialExpression{T} where {T<:AbstractSPGPVariable}
    # Combine coefficients
    coef = x.term.coefficient / y.term.coefficient

    # Combine exponents
    exponents = Dict{T,Float64}()

    # Add exponents from x
    for (var, exp) in x.term.exponents
        exponents[var] = get(exponents, var, 0.0) + exp
    end

    # Subtract exponents from y
    for (var, exp) in y.term.exponents
        exponents[var] = get(exponents, var, 0.0) - exp
    end

    return MonomialExpression(coef, exponents)
end

# Monomial / Variable
function Base.:/(x::MonomialExpression, y::AbstractSPGPVariable)::MonomialExpression
    # Create a new exponents dictionary
    exponents = copy(x.term.exponents)
    exponents[y] = get(exponents, y, 0.0) - 1.0

    return MonomialExpression(x.term.coefficient, exponents)
end

# Variable / Monomial
function Base.:/(x::AbstractSPGPVariable, y::MonomialExpression)::MonomialExpression
    # Convert variable to monomial and then divide
    return as_monomial(x) / y
end

# Monomial / Constant
function Base.:/(x::MonomialExpression, c::Real)::MonomialExpression
    if c <= 0
        error("Cannot divide by a non-positive constant in a geometric program")
    end
    return MonomialExpression(x.term.coefficient / c, copy(x.term.exponents))
end

# Posynomial / Constant
function Base.:/(x::PosynomialExpression, c::Real)::PosynomialExpression
    if c <= 0
        error("Cannot divide by a non-positive constant in a geometric program")
    end
    # Scale each term in the posynomial by 1/c
    new_terms =
        [MonomialTerm(term.coefficient / c, copy(term.exponents)) for term in x.terms]
    return PosynomialExpression(new_terms)
end

# Posynomial / Variable
function Base.:/(
    x::PosynomialExpression{T},
    v::T,
)::PosynomialExpression where {T<:AbstractSPGPVariable}
    # For each term in the posynomial, subtract 1 from the exponent of the variable
    new_terms = Vector{MonomialTerm{T}}()

    for term in x.terms
        # Create a new copy of the exponents
        new_exponents = copy(term.exponents)
        # Subtract 1 from the exponent of the variable
        new_exponents[v] = get(new_exponents, v, 0.0) - 1.0
        # Create a new monomial term
        push!(new_terms, MonomialTerm(term.coefficient, new_exponents))
    end

    return PosynomialExpression(new_terms)
end

# Posynomial / Monomial
function Base.:/(
    x::PosynomialExpression{T},
    y::MonomialExpression{T},
)::PosynomialExpression where {T<:AbstractSPGPVariable}
    # For each term in the posynomial, divide by the monomial
    new_terms = Vector{MonomialTerm{T}}()

    for term in x.terms
        # Create a new monomial term with coefficient divided by y's coefficient
        new_coef = term.coefficient / y.term.coefficient
        # Create a new copy of the exponents
        new_exponents = copy(term.exponents)

        # Subtract y's exponents from the new exponents
        for (var, exp) in y.term.exponents
            new_exponents[var] = get(new_exponents, var, 0.0) - exp
        end

        # Create a new monomial term
        push!(new_terms, MonomialTerm(new_coef, new_exponents))
    end

    return PosynomialExpression(new_terms)
end

# Constant / Monomial
function Base.:/(
    c::Real,
    x::MonomialExpression{T},
)::Union{MonomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c <= 0
        return SignomialExpression([MonomialTerm(1.0 / c, Dict(x => -1.0))])
    end

    # Create a new exponents dictionary with negated exponents
    exponents = Dict{T,Float64}()
    for (var, exp) in x.term.exponents
        exponents[var] = -exp
    end

    return MonomialExpression(c / x.term.coefficient, exponents)
end

# Other division operations typically result in more complex expressions
# that may not be representable as GP expressions, so we fall back to
# JuMP's NonlinearExpression

#
# EXPONENTIATION OPERATIONS
#

# Variable ^ Constant
function Base.:^(x::AbstractSPGPVariable, p::Real)::MonomialExpression
    return MonomialExpression(1.0, Dict(x => Float64(p)))
end

# Variable ^ Integer
function Base.:^(x::AbstractSPGPVariable, p::Integer)::MonomialExpression
    return MonomialExpression(1.0, Dict(x => Float64(p)))
end

# inv(Variable) - returns x^(-1)
function Base.inv(x::AbstractSPGPVariable)::MonomialExpression
    return MonomialExpression(1.0, Dict(x => -1.0))
end

# sqrt(Variable) - returns x^(0.5)
function Base.sqrt(x::AbstractSPGPVariable)::MonomialExpression
    return MonomialExpression(1.0, Dict(x => 0.5))
end

# Monomial ^ Constant
function Base.:^(
    x::MonomialExpression{T},
    p::Real,
)::MonomialExpression where {T<:AbstractSPGPVariable}
    # Apply power to coefficient
    coef = x.term.coefficient^p

    # Apply power to all exponents
    exponents = Dict{T,Float64}()
    for (var, exp) in x.term.exponents
        exponents[var] = exp * p
    end

    return MonomialExpression(coef, exponents)
end

# inv(Monomial) - returns 1/x which is x^(-1)
function Base.inv(
    x::MonomialExpression{T},
)::MonomialExpression where {T<:AbstractSPGPVariable}
    # Invert the coefficient
    coef = 1.0 / x.term.coefficient

    # Negate all exponents
    exponents = Dict{T,Float64}()
    for (var, exp) in x.term.exponents
        exponents[var] = -exp
    end

    return MonomialExpression(coef, exponents)
end

# sqrt(Monomial) - returns x^(0.5)
function Base.sqrt(
    x::MonomialExpression{T},
)::MonomialExpression where {T<:AbstractSPGPVariable}
    # Take square root of coefficient
    coef = sqrt(x.term.coefficient)

    # Multiply all exponents by 0.5
    exponents = Dict{T,Float64}()
    for (var, exp) in x.term.exponents
        exponents[var] = exp * 0.5
    end

    return MonomialExpression(coef, exponents)
end

# Other exponentiation operations typically result in more complex expressions
# that may not be representable as GP expressions, so we fall back to
# JuMP's NonlinearExpression
function Base.:^(x::Union{PosynomialExpression,SignomialExpression}, p::Real)
    # Fall back to JuMP's NonlinearExpression
    m = first(x.terms).exponents |> keys |> first |> owner_model
    return JuMP.@NLexpression(m, x^p)
end

#
# ADDITION OPERATIONS
#

# Variable + Variable
function Base.:+(x::AbstractSPGPVariable, y::AbstractSPGPVariable)::PosynomialExpression
    return PosynomialExpression([
        MonomialTerm(1.0, Dict(x => 1.0)),
        MonomialTerm(1.0, Dict(y => 1.0)),
    ])
end

# Variable + Constant
function Base.:+(
    x::T,
    c::Real,
)::Union{PosynomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c > 0
        return PosynomialExpression([
            MonomialTerm(1.0, Dict(x => 1.0)),
            MonomialTerm(c, Dict{T,Float64}()),
        ])
    elseif c == 0
        return PosynomialExpression([MonomialTerm(1.0, Dict(x => 1.0))])
    else
        # For negative constants, we need to create a SignomialExpression
        return SignomialExpression([
            MonomialTerm(1.0, Dict(x => 1.0)),
            MonomialTerm(c, Dict{T,Float64}()),
        ])
    end
end

# Constant + Variable
Base.:+(c::Real, x::AbstractSPGPVariable) = x + c

# Monomial + Monomial
function Base.:+(x::MonomialExpression, y::MonomialExpression)::PosynomialExpression
    return PosynomialExpression([x.term, y.term])
end

# Monomial + Variable
function Base.:+(x::MonomialExpression, y::AbstractSPGPVariable)::PosynomialExpression
    return PosynomialExpression([x.term, MonomialTerm(1.0, Dict(y => 1.0))])
end

# Variable + Monomial
Base.:+(x::AbstractSPGPVariable, y::MonomialExpression) = y + x

# Monomial + Constant
function Base.:+(
    x::MonomialExpression{T},
    c::Real,
)::Union{PosynomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c > 0
        return PosynomialExpression([x.term, MonomialTerm(c, Dict{T,Float64}())])
    elseif c == 0
        return PosynomialExpression([x.term])
    else
        # For negative constants, we need to create a SignomialExpression
        return SignomialExpression([x.term, MonomialTerm(c, Dict{T,Float64}())])
    end
end

# Constant + Monomial
Base.:+(c::Real, x::MonomialExpression) = x + c

# Posynomial + Posynomial
function Base.:+(x::PosynomialExpression, y::PosynomialExpression)::PosynomialExpression
    # Combine all terms
    return PosynomialExpression(vcat(x.terms, y.terms))
end

# Posynomial + Monomial
function Base.:+(x::PosynomialExpression, y::MonomialExpression)::PosynomialExpression
    # Add monomial term to posynomial terms
    return PosynomialExpression(vcat(x.terms, [y.term]))
end

# Monomial + Posynomial
Base.:+(x::MonomialExpression, y::PosynomialExpression) = y + x

# Posynomial + Variable
function Base.:+(x::PosynomialExpression, y::AbstractSPGPVariable)::PosynomialExpression
    # Add variable term to posynomial terms
    return PosynomialExpression(vcat(x.terms, [MonomialTerm(1.0, Dict(y => 1.0))]))
end

# Variable + Posynomial
Base.:+(x::AbstractSPGPVariable, y::PosynomialExpression) = y + x

# Posynomial + Constant
function Base.:+(
    x::PosynomialExpression{T},
    c::Real,
)::Union{PosynomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c > 0
        return PosynomialExpression(vcat(x.terms, [MonomialTerm(c, Dict{T,Float64}())]))
    elseif c == 0
        return x
    else
        # For negative constants, we need to create a SignomialExpression
        return SignomialExpression(vcat(x.terms, [MonomialTerm(c, Dict{T,Float64}())]))
    end
end

# Constant + Posynomial
Base.:+(c::Real, x::PosynomialExpression) = x + c

# Signomial + Any and Any + Signomial typically produce Signomials
# Signomial + Signomial
function Base.:+(x::SignomialExpression, y::SignomialExpression)::SignomialExpression
    return SignomialExpression(vcat(x.terms, y.terms))
end

# Signomial + Posynomial/Monomial/Variable/Constant
function Base.:+(
    x::SignomialExpression{T},
    y::Union{PosynomialExpression,MonomialExpression,T,Real},
) where {T<:AbstractSPGPVariable}
    if y isa PosynomialExpression
        return SignomialExpression(vcat(x.terms, y.terms))
    elseif y isa MonomialExpression
        return SignomialExpression(vcat(x.terms, [y.term]))
    elseif y isa T
        return SignomialExpression(vcat(x.terms, [MonomialTerm(1.0, Dict(y => 1.0))]))
    elseif y isa Real
        return SignomialExpression(vcat(x.terms, [MonomialTerm(y, Dict{T,Float64}())]))
    end
end

# Any + Signomial
Base.:+(
    y::Union{PosynomialExpression,MonomialExpression,GPVariable,SPVariable,Real},
    x::SignomialExpression,
) = x + y

#
# SUBTRACTION OPERATIONS
#

# Variable - Variable
function Base.:-(x::AbstractSPGPVariable, y::AbstractSPGPVariable)::SignomialExpression
    return SignomialExpression([
        MonomialTerm(1.0, Dict(x => 1.0)),
        MonomialTerm(-1.0, Dict(y => 1.0)),
    ])
end

# Variable - Constant
function Base.:-(
    x::T,
    c::Real,
)::Union{PosynomialExpression{T},SignomialExpression{T}} where {T<:AbstractSPGPVariable}
    if c < 0
        # Subtracting a negative is like adding a positive
        return PosynomialExpression([
            MonomialTerm(1.0, Dict(x => 1.0)),
            MonomialTerm(-c, Dict{T,Float64}()),
        ])
    elseif c == 0
        return PosynomialExpression([MonomialTerm(1.0, Dict(x => 1.0))])
    else
        # Subtracting a positive constant gives a SignomialExpression
        return SignomialExpression([
            MonomialTerm(1.0, Dict(x => 1.0)),
            MonomialTerm(-c, Dict{T,Float64}()),
        ])
    end
end

# Constant - Variable
function Base.:-(c::Real, x::T)::SignomialExpression where {T<:AbstractSPGPVariable}
    return SignomialExpression([
        MonomialTerm(c, Dict{T,Float64}()),
        MonomialTerm(-1.0, Dict(x => 1.0)),
    ])
end

# All other subtraction operations create SignomialExpressions
# (except in special cases like x - 0 or subtracting a negative number)

# Generic subtraction - create a SignomialExpression
function Base.:-(
    x::Union{MonomialExpression{T},PosynomialExpression{T}},
    y::Union{MonomialExpression{T},PosynomialExpression{T},T,Real},
)::SignomialExpression where {T<:AbstractSPGPVariable}
    # Convert to SignomialExpression
    x_terms = x isa MonomialExpression ? [x.term] : x.terms

    # Get y's terms with negated coefficients
    local y_terms
    if y isa MonomialExpression
        y_terms = [MonomialTerm(-y.term.coefficient, y.term.exponents)]
    elseif y isa PosynomialExpression
        y_terms = [MonomialTerm(-term.coefficient, term.exponents) for term in y.terms]
    elseif y isa T
        y_terms = [MonomialTerm(-1.0, Dict(y => 1.0))]
    elseif y isa Real
        y_terms = [MonomialTerm(-y, Dict{T,Float64}())]
    end

    return SignomialExpression(vcat(x_terms, y_terms))
end

# Handle remaining cases
Base.:-(
    y::Union{T,Real},
    x::Union{MonomialExpression{T},PosynomialExpression{T}},
) where {T<:AbstractSPGPVariable} =
    SignomialExpression([
        MonomialTerm(y isa Real ? y : 1.0, y isa Real ? Dict{T,Float64}() : Dict(y => 1.0)),
    ]) - x

# Signomial - Any
function Base.:-(
    x::SignomialExpression{T},
    y::Union{SignomialExpression{T},PosynomialExpression{T},MonomialExpression{T},T,Real},
) where {T<:AbstractSPGPVariable}
    # Convert to SignomialExpression
    if y isa SignomialExpression
        y_terms = [MonomialTerm(-term.coefficient, term.exponents) for term in y.terms]
    elseif y isa PosynomialExpression || y isa MonomialExpression
        y_expr = SignomialExpression(y)
        y_terms = [MonomialTerm(-term.coefficient, term.exponents) for term in y_expr.terms]
    elseif y isa T
        y_terms = [MonomialTerm(-1.0, Dict(y => 1.0))]
    elseif y isa Real
        y_terms = [MonomialTerm(-y, Dict{T,Float64}())]
    end

    return SignomialExpression(vcat(x.terms, y_terms))
end

# Any - Signomial
function Base.:-(
    y::Union{PosynomialExpression,MonomialExpression,T,Real},
    x::SignomialExpression,
) where {T<:AbstractSPGPVariable}
    # Convert y to SignomialExpression and then negate all terms of x
    y_expr =
        y isa SignomialExpression ? y :
        (
            y isa PosynomialExpression || y isa MonomialExpression ?
            SignomialExpression(y) :
            (
                y isa T ? SignomialExpression([MonomialTerm(1.0, Dict(y => 1.0))]) :
                SignomialExpression([MonomialTerm(y, Dict{T,Float64}())])
            )
        )

    x_terms = [MonomialTerm(-term.coefficient, term.exponents) for term in x.terms]

    return SignomialExpression(vcat(y_expr.terms, x_terms))
end

#
# UNARY NEGATION
#

# -Variable
function Base.:-(x::AbstractSPGPVariable)::SignomialExpression
    return SignomialExpression([MonomialTerm(-1.0, Dict(x => 1.0))])
end

# -Monomial
function Base.:-(x::MonomialExpression)::SignomialExpression
    return SignomialExpression([MonomialTerm(-x.term.coefficient, x.term.exponents)])
end

# -Posynomial
function Base.:-(x::PosynomialExpression)::SignomialExpression
    # Negate all coefficients
    terms = [MonomialTerm(-term.coefficient, term.exponents) for term in x.terms]
    return SignomialExpression(terms)
end

# -Signomial
function Base.:-(x::SignomialExpression)::SignomialExpression
    # Negate all coefficients
    terms = [MonomialTerm(-term.coefficient, term.exponents) for term in x.terms]
    return SignomialExpression(terms)
end

#==========================================================================
  Methods for Arithmetic Interface Compatibility with JuMP
==========================================================================#

# zero - creates a zero value of the specified type (required by MutableArithmetics)
Base.zero(::Type{MonomialExpression}) = MonomialExpression(0.0, Dict{GPVariable,Float64}())
Base.zero(::MonomialExpression) = zero(MonomialExpression)

Base.zero(::Type{PosynomialExpression}) = PosynomialExpression(MonomialTerm[])
Base.zero(::PosynomialExpression) = zero(PosynomialExpression)

Base.zero(::Type{SignomialExpression}) = SignomialExpression(MonomialTerm[])
Base.zero(::SignomialExpression) = zero(SignomialExpression)

# one - creates a value of one for the specified type
Base.one(::Type{MonomialExpression}) = MonomialExpression(1.0, Dict{GPVariable,Float64}())
Base.one(::MonomialExpression) = one(MonomialExpression)

# equality operators for expressions
Base.:(==)(x::MonomialExpression, y::MonomialExpression) =
    x.term.coefficient == y.term.coefficient && x.term.exponents == y.term.exponents

Base.:(==)(x::PosynomialExpression, y::PosynomialExpression) =
    length(x.terms) == length(y.terms) && all(x.terms .== y.terms)

Base.:(==)(x::SignomialExpression, y::SignomialExpression) =
    length(x.terms) == length(y.terms) && all(x.terms .== y.terms)



# Define add_mul for our expressions (important for JuMP's constraint system)
# These are critical for correctly building constraints in JuMP

# For MonomialExpression
function MA.add_mul(x::MonomialExpression, y::Real, z::AbstractSPGPVariable)
    if y <= 0
        error("Coefficients in geometric programming must be positive")
    end
    # Create a new monomial term y*z and add it to x
    new_term = MonomialTerm(y, Dict(z => 1.0))
    # Return a PosynomialExpression with the two terms
    return PosynomialExpression([x.term, new_term])
end

function MA.add_mul(x::MonomialExpression, y::AbstractSPGPVariable, z::Real)
    return MA.add_mul(x, z, y) # Reuse the implementation above
end

function MA.add_mul(x::MonomialExpression, y::AbstractSPGPVariable, z::AbstractSPGPVariable)
    return MA.add_mul(x, 1.0, y * z)
end

function MA.add_mul(x::MonomialExpression, y::Real, z::MonomialExpression)
    if y <= 0
        error("Coefficients in geometric programming must be positive")
    end
    # Scale the monomial by y and add to x
    scaled_term = MonomialTerm(y * z.term.coefficient, copy(z.term.exponents))
    # Return a PosynomialExpression with both terms
    return PosynomialExpression([x.term, scaled_term])
end

function MA.add_mul(
    x::MonomialExpression,
    y::AbstractSPGPVariable,
    z::AbstractSPGPVariable,
    w::AbstractSPGPVariable,
)
    return MA.add_mul(x, 1.0, y * z * w)
end

# For PosynomialExpression
function MA.add_mul(x::PosynomialExpression, y::Real, z::AbstractSPGPVariable)
    if y <= 0
        error("Coefficients in geometric programming must be positive")
    end
    # Create a new monomial term y*z
    new_term = MonomialTerm(y, Dict(z => 1.0))
    # Add it to the existing terms
    return PosynomialExpression([x.terms..., new_term])
end

function MA.add_mul(x::PosynomialExpression, y::AbstractSPGPVariable, z::Real)
    return MA.add_mul(x, z, y) # Reuse the implementation above
end

function MA.add_mul(x::PosynomialExpression, y::Real, z::MonomialExpression)
    if y <= 0
        error("Coefficients in geometric programming must be positive")
    end
    # Scale the monomial by y
    scaled_term = MonomialTerm(y * z.term.coefficient, copy(z.term.exponents))
    # Add it to the existing terms
    return PosynomialExpression([x.terms..., scaled_term])
end

# Generic fallbacks
function MA.add_mul(x::AbstractGPSPExpression, y::Real, z::AbstractGPSPExpression)
    return x + y * z
end

function MA.add_mul(x::AbstractGPSPExpression, y::AbstractGPSPExpression, z::Real)
    return x + y * z
end

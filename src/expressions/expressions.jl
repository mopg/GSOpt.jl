"""
    Expression types for geometric programming.
    
Expression types:
- MonomialTerm: A coefficient multiplied by variables raised to powers (positive or negative)
- MonomialExpression: A product of a coefficient and variables with exponents (a single term)
- PosynomialExpression: A sum of monomial terms with positive coefficients
- SignomialExpression: A sum of monomial terms with possibly negative coefficients
"""

"""
    MonomialTerm

Represents a single term in a monomial or posynomial expression.
It consists of a coefficient and a dictionary mapping variables to their exponents.
"""
struct MonomialTerm{T<:AbstractSPGPVariable}
    coefficient::Float64
    exponents::Dict{T,Float64}

    # Constructor that ensures coefficients are positive for monomial terms
    function MonomialTerm(coef::Real, vars::Dict{T,<:Real}) where {T<:AbstractSPGPVariable}
        return new{T}(Float64(coef), Dict{T,Float64}(k => Float64(v) for (k, v) in vars))
    end
end

function JuMP.function_string(::MIME"text/plain", term::MonomialTerm)
    exponents_str_vec =
        [(exp != 1 ? "$(name(var))^$(exp)" : name(var)) for (var, exp) in term.exponents]

    exponents_str = join(exponents_str_vec, " * ")
    return "$(term.coefficient) * $exponents_str"
end

"""
    MonomialExpression <: AbstractGPExpression

Represents a monomial expression in geometric programming.
A monomial is a product of a positive coefficient and variables raised to powers.
"""
struct MonomialExpression{T<:AbstractSPGPVariable} <: AbstractGPExpression
    term::MonomialTerm{T}

    # Constructor that validates the monomial expression
    function MonomialExpression(
        coef::Real,
        vars::Dict{T,<:Real},
    ) where {T<:AbstractSPGPVariable}
        if length(vars) == 0
            return new{T}(MonomialTerm(coef, Dict{T,Float64}()))
        end
        if coef <= 0
            error("Monomial expressions must have positive coefficients")
        end
        return new{T}(MonomialTerm(coef, vars))
    end

    # Constructor from an existing term
    function MonomialExpression(term::MonomialTerm{T}) where {T<:AbstractSPGPVariable}
        if term.coefficient <= 0
            error("Monomial expressions must have positive coefficients")
        end
        return new{T}(term)
    end
end

function variables(expr::MonomialExpression)
    return collect(keys(expr.term.exponents))
end

function JuMP.function_string(::MIME"text/plain", M::MonomialExpression)
    return JuMP.function_string(MIME("text/plain"), M.term)
end


"""
    PosynomialExpression <: AbstractGPExpression

Represents a posynomial expression in geometric programming.
A posynomial is a sum of monomials with positive coefficients.
"""
struct PosynomialExpression{T<:AbstractSPGPVariable} <: AbstractGPExpression
    terms::Vector{MonomialTerm{T}}

    # Constructor that validates the posynomial expression
    function PosynomialExpression(
        terms::Vector{MonomialTerm{T}},
    ) where {T<:AbstractSPGPVariable}
        # Check that all coefficients are positive
        for term in terms
            if term.coefficient <= 0
                error("Posynomial expressions must have positive coefficients")
            end
        end
        return new{T}(terms)
    end

    # Constructor from a single monomial term
    function PosynomialExpression(term::MonomialTerm{T}) where {T<:AbstractSPGPVariable}
        if term.coefficient <= 0
            error("Posynomial expressions must have positive coefficients")
        end
        return new{T}([term])
    end

    # Constructor from a monomial expression
    function PosynomialExpression(
        expr::MonomialExpression{T},
    ) where {T<:AbstractSPGPVariable}
        return new{T}([expr.term])
    end
end

function variables(expr::PosynomialExpression)
    return vcat([collect(keys(term.exponents)) for term in expr.terms]...)
end

"""
    SignomialExpression <: AbstractGPSPExpression

Represents a signomial expression in geometric programming.
A signomial is a sum of terms where coefficients can be positive or negative.
Signomials are generally not solvable by standard geometric programming methods.
"""
struct SignomialExpression{T<:AbstractSPGPVariable} <: AbstractGPSPExpression
    terms::Vector{MonomialTerm{T}}

    # Constructor from a vector of terms
    function SignomialExpression(
        terms::Vector{MonomialTerm{T}},
    ) where {T<:AbstractSPGPVariable}
        return new{T}(terms)
    end

    # Constructor from a posynomial expression
    function SignomialExpression(
        expr::PosynomialExpression{T},
    ) where {T<:AbstractSPGPVariable}
        return new{T}(copy(expr.terms))
    end

    # Constructor from a monomial expression
    function SignomialExpression(
        expr::MonomialExpression{T},
    ) where {T<:AbstractSPGPVariable}
        return new{T}([expr.term])
    end
end

function variables(expr::SignomialExpression)
    return vcat([collect(keys(term.exponents)) for term in expr.terms]...)
end

function JuMP.function_string(
    ::MIME"text/plain",
    P::Union{PosynomialExpression,SignomialExpression},
)
    terms_str = [JuMP.function_string(MIME("text/plain"), term) for term in P.terms]
    return join(terms_str, " + ")
end

# Utility functions to check expression types
"""
    is_monomial(expr)

Check if an expression is a valid monomial (coefficient multiplied by variables 
raised to powers, positive or negative).
"""
function is_monomial(expr::MonomialExpression)
    return true
end

function is_monomial(expr::PosynomialExpression)
    return length(expr.terms) == 1
end

function is_monomial(expr::SignomialExpression)
    return length(expr.terms) == 1 && expr.terms[1].coefficient > 0
end

function is_monomial(v::AbstractSPGPVariable)
    return true
end

function is_monomial(c::Real)
    return c > 0
end

function is_monomial(expr)
    return false
end

"""
    is_posynomial(expr)

Check if an expression is a valid posynomial (sum of monomials with positive coefficients).
"""
function is_posynomial(expr::Union{PosynomialExpression,MonomialExpression})
    return true
end

function is_posynomial(expr::SignomialExpression)
    return all(term.coefficient > 0 for term in expr.terms)
end

function is_posynomial(v::AbstractSPGPVariable)
    return true  # A single variable is a monomial, which is also a posynomial
end

function is_posynomial(c::Real)
    return c > 0
end

function is_posynomial(expr)
    return false
end

"""
    is_signomial(expr)

Check if an expression is a valid signomial (sum of monomials with possibly negative coefficients).
"""
function is_signomial(
    expr::Union{
        SignomialExpression,
        MonomialExpression,
        PosynomialExpression,
        <:AbstractSPGPVariable,
        <:Real,
    },
)
    return true
end

function is_signomial(expr)
    return false
end

function Base.iszero(m::MonomialExpression)
    return m.term.coefficient == 0
end

function Base.iszero(p::PosynomialExpression)
    return all(iszero, p.terms)
end

function Base.iszero(s::SignomialExpression)
    return all(iszero, s.terms)
end

function Base.iszero(mt::MonomialTerm)
    return mt.coefficient == 0
end

# Display methods to help with debugging
function Base.show(io::IO, term::MonomialTerm)
    if isempty(term.exponents)
        print(io, term.coefficient)
        return
    end

    print(io, term.coefficient)
    for (var, exp) in term.exponents
        if exp == 1
            print(io, " * ", JuMP.name(var))
        else
            print(io, " * ", JuMP.name(var), "^", exp)
        end
    end
end

function Base.show(io::IO, expr::MonomialExpression)
    show(io, expr.term)
end

function Base.show(io::IO, expr::PosynomialExpression)
    if isempty(expr.terms)
        print(io, "0")
        return
    end

    print(io, expr.terms[1])
    for i = 2:length(expr.terms)
        print(io, " + ", expr.terms[i])
    end
end

function Base.show(io::IO, expr::SignomialExpression)
    if isempty(expr.terms)
        print(io, "0")
        return
    end

    print(io, expr.terms[1])
    for i = 2:length(expr.terms)
        term = expr.terms[i]
        if term.coefficient < 0
            print(io, " - ", MonomialTerm(-term.coefficient, term.exponents))
        else
            print(io, " + ", term)
        end
    end
end


# For signomials

function evaluate_at_linearization_point(expr::PosynomialExpression{SPVariable})

    total = 0.0
    for term in expr.terms

        total +=
            term.coefficient *
            prod([latest_linearization_point(v)^exp for (v, exp) in term.exponents])

    end

    return total

end


function deriv_at_linearization_point(expr::PosynomialExpression{SPVariable}, v::SPVariable)

    total = 0.0

    for term in expr.terms

        if v in keys(term.exponents)

            exponent_with_v = term.exponents[v]

            total +=
                term.coefficient *
                prod([
                    latest_linearization_point(vv)^exp for
                    (vv, exp) in term.exponents if vv != v
                ]) *
                exponent_with_v *
                latest_linearization_point(v)^(exponent_with_v - 1)

        end

    end

    return total

end


function approximate_posynomial_as_monomial(p::PosynomialExpression)

    # From Boyd (2006)

    vars = variables(p)

    p0 = evaluate_at_linearization_point(p)

    ∂p0_∂x = [deriv_at_linearization_point(p, v) for v in vars]

    exps = [latest_linearization_point(v) / p0 for v in vars] .* ∂p0_∂x

    return p0 *
           prod((v / latest_linearization_point(v))^exp for (v, exp) in zip(vars, exps))

end

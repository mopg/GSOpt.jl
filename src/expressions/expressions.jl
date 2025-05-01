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
struct MonomialTerm
    coefficient::Float64
    exponents::Dict{GPVariable,Float64}

    # Constructor that ensures coefficients are positive for monomial terms
    function MonomialTerm(coef::Real, vars::Dict{GPVariable,<:Real})
        return new(
            Float64(coef),
            Dict{GPVariable,Float64}(k => Float64(v) for (k, v) in vars),
        )
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
struct MonomialExpression <: AbstractGPExpression
    term::MonomialTerm

    # Constructor that validates the monomial expression
    function MonomialExpression(coef::Real, vars::Dict{GPVariable,<:Real})
        if length(vars) == 0
            return new(MonomialTerm(coef, Dict{GPVariable,Float64}()))
        end
        if coef <= 0
            error("Monomial expressions must have positive coefficients")
        end
        return new(MonomialTerm(coef, vars))
    end

    # Constructor from an existing term
    function MonomialExpression(term::MonomialTerm)
        if term.coefficient <= 0
            error("Monomial expressions must have positive coefficients")
        end
        return new(term)
    end
end

function JuMP.function_string(::MIME"text/plain", M::MonomialExpression)
    return JuMP.function_string(MIME("text/plain"), M.term)
end


"""
    PosynomialExpression <: AbstractGPExpression

Represents a posynomial expression in geometric programming.
A posynomial is a sum of monomials with positive coefficients.
"""
struct PosynomialExpression <: AbstractGPExpression
    terms::Vector{MonomialTerm}

    # Constructor that validates the posynomial expression
    function PosynomialExpression(terms::Vector{MonomialTerm})
        # Check that all coefficients are positive
        for term in terms
            if term.coefficient <= 0
                error("Posynomial expressions must have positive coefficients")
            end
        end
        return new(terms)
    end

    # Constructor from a single monomial term
    function PosynomialExpression(term::MonomialTerm)
        if term.coefficient <= 0
            error("Posynomial expressions must have positive coefficients")
        end
        return new([term])
    end

    # Constructor from a monomial expression
    function PosynomialExpression(expr::MonomialExpression)
        return new([expr.term])
    end
end



"""
    SignomialExpression <: AbstractGPExpression

Represents a signomial expression in geometric programming.
A signomial is a sum of terms where coefficients can be positive or negative.
Signomials are generally not solvable by standard geometric programming methods.
"""
struct SignomialExpression <: AbstractGPExpression
    terms::Vector{MonomialTerm}

    # Constructor from a vector of terms
    function SignomialExpression(terms::Vector{MonomialTerm})
        return new(terms)
    end

    # Constructor from a posynomial expression
    function SignomialExpression(expr::PosynomialExpression)
        return new(copy(expr.terms))
    end

    # Constructor from a monomial expression
    function SignomialExpression(expr::MonomialExpression)
        return new([expr.term])
    end
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

function is_monomial(v::GPVariable)
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
function is_posynomial(expr::PosynomialExpression)
    return true
end

function is_posynomial(expr::MonomialExpression)
    return true
end

function is_posynomial(expr::SignomialExpression)
    return all(term.coefficient > 0 for term in expr.terms)
end

function is_posynomial(v::GPVariable)
    return true  # A single variable is a monomial, which is also a posynomial
end

function is_posynomial(c::Real)
    return c > 0
end

function is_posynomial(expr)
    return false
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
            print(io, " * ", var.name)
        else
            print(io, " * ", var.name, "^", exp)
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

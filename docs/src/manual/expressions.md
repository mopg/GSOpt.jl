# Expressions

GSOpt.jl provides specialized expression types for working with geometric programming problems:

## Expression Types

### Monomial Expressions

A monomial is a function of the form: c·x₁^a₁·x₂^a₂·...·xₙ^aₙ, where c > 0 and aᵢ are real exponents.

In GSOpt.jl, monomials are represented by the `MonomialExpression` type:

```julia
# Examples of monomial expressions
x^2 * y^3        # A monomial with variables x and y
2.5 * x^(-1) * z # A monomial with coefficient 2.5
```

### Posynomial Expressions

A posynomial is a sum of monomials. In GSOpt.jl, posynomials are represented by the `PosynomialExpression` type:

```julia
# Examples of posynomial expressions
x + y            # Sum of two monomials (each variable is a monomial)
x^2 + 3*y^(-1)   # Sum of two monomials with different exponents
x*y + y*z + z*x  # Sum of three monomials
```

### Signomial Expressions

A signomial is a sum of terms where the coefficients can be negative. In geometric programming, we can only optimize posynomials, but signomials may appear in intermediate calculations:

```julia
# Example of a signomial expression
x - y            # Difference of two monomials
```

## Checking Expression Types

GSOpt.jl provides functions to check the type of an expression:

```julia
is_monomial(x * y)           # Returns true
is_monomial(x + y)           # Returns false
is_posynomial(x + y)         # Returns true
is_posynomial(x * y)         # Returns true (a monomial is also a posynomial)
```

## Operations on Expressions

GSOpt.jl overloads standard operators to work with GP expressions:

### Addition

```julia
x + y                # Creates a posynomial
monomial1 + monomial2  # Creates a posynomial
posynomial1 + posynomial2  # Creates a posynomial
```

### Multiplication

```julia
x * y                # Creates a monomial
monomial1 * monomial2  # Creates a monomial
posynomial1 * monomial  # Creates a posynomial
```

### Division

```julia
x / y                # Creates a monomial (x * y^(-1))
monomial1 / monomial2  # Creates a monomial
```

### Exponentiation

```julia
x^2                  # Creates a monomial
x^(-0.5)             # Creates a monomial with negative exponent
```

## Expression Constraints

Expressions can be used in constraints:

```julia
@constraint(model, x * y == 1)  # Monomial equality constraint
@constraint(model, x + y ≤ 5)   # Posynomial inequality constraint
```

## Usage in Objectives

Expressions can also be used in objective functions:

```julia
# Minimize a posynomial
@objective(model, Min, x + y + x*y)

# Maximize a monomial
@objective(model, Max, x * y)
```

Note that in geometric programming:

- You can minimize posynomials
- You can maximize monomials
- You cannot minimize monomials directly (but you can minimize their reciprocal)
- You cannot maximize posynomials directly

# Constraints

In geometric programming, constraints have specific forms that must be adhered to. GSOpt.jl supports the standard constraint types required for geometric programming.

## Types of Constraints

### Monomial Equality Constraints

Monomial equality constraints have the form:

```
g(x) = 1
```

where g(x) is a monomial.

In GSOpt.jl, you can express these constraints as:

```julia
@constraint(model, x * y * z == 1)
@constraint(model, x^2 * y^(-1) == 3)  # Will be normalized to (x^2 * y^(-1))/3 == 1
```

### Posynomial Inequality Constraints

Posynomial inequality constraints have the form:

```
f(x) ≤ 1
```

where f(x) is a posynomial.

In GSOpt.jl, you can express these constraints as:

```julia
@constraint(model, x + y ≤ 5)          # Will be normalized to (x + y)/5 ≤ 1
@constraint(model, 2*x + 3*y + z ≤ 10)  # Will be normalized to (2*x + 3*y + z)/10 ≤ 1
```

### Monomial Inequality Constraints

Monomial inequality constraints are a special case of posynomial constraints:

```julia
@constraint(model, x * y ≤ 2)  # Will be normalized to (x * y)/2 ≤ 1
@constraint(model, x * y ≥ 3)  # Will be normalized to 3/(x * y) ≤ 1
```

## Constraint Normalization

GSOpt.jl automatically normalizes constraints to the standard form required for geometric programming:

1. Equality constraints: g(x) = 1
2. Inequality constraints: f(x) ≤ 1

This normalization happens behind the scenes, so you can write constraints in a more natural form.

## Examples

### Equality Constraints

```julia
# Standard form
@constraint(model, x * y == 1)

# Will be normalized to x * y / 2 == 1
@constraint(model, x * y == 2)

# Will be normalized to 3 / (x * y) == 1
@constraint(model, x * y == 1/3)
```

### Inequality Constraints

```julia
# Standard form
@constraint(model, x + y ≤ 1)

# Will be normalized to (x + y) / 10 ≤ 1
@constraint(model, x + y ≤ 10)

# Will be normalized to 5 / (x * y) ≤ 1
@constraint(model, x * y ≥ 5)
```

## Constraint References

When you create a constraint, GSOpt.jl returns a `GPConstraintRef` object that you can use to reference the constraint later:

```julia
c1 = @constraint(model, x * y == 1)
c2 = @constraint(model, x + y ≤ 5)

# You can use these references to delete constraints
delete(model, c1)
```

## Checking Constraint Types

GSOpt.jl provides functions to check if expressions satisfy the requirements for different constraint types:

```julia
# Check if an expression is a monomial (can be used in equality constraints)
is_monomial(x * y)           # Returns true
is_monomial(x + y)           # Returns false

# Check if an expression is a posynomial (can be used in inequality constraints)
is_posynomial(x + y)         # Returns true
is_posynomial(x * y)         # Returns true (a monomial is also a posynomial)
```

## Constraint Transformation

Behind the scenes, GSOpt.jl transforms geometric programming constraints into equivalent convex optimization constraints by taking logarithms. This transformation is handled automatically, allowing you to work directly with the more intuitive geometric programming formulation.

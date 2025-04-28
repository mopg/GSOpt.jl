# Getting Started

## Introduction to Geometric Programming

Geometric programming (GP) is a type of mathematical optimization problem where the objective function and constraints are expressed in terms of monomials and posynomials.

A **monomial** is a function of the form:

```
g(x) = c·x₁^a₁·x₂^a₂·...·xₙ^aₙ
```

where `c > 0` and `aᵢ` are real exponents.

A **posynomial** is a sum of monomials:

```
f(x) = ∑ᵏ cₖ·x₁^aₖ₁·x₂^aₖ₂·...·xₙ^aₖₙ
```

A geometric program has the form:

```
minimize    f₀(x)
subject to  fᵢ(x) ≤ 1,  i = 1,...,m
            gⱼ(x) = 1,  j = 1,...,p
```

where each `fᵢ` is a posynomial and each `gⱼ` is a monomial.

## Installation

To use GSOpt.jl, you need to have Julia installed. Then, you can add GSOpt.jl to your project:

```julia
using GSOpt
```

You'll also need a solver that can handle exponential cones. We recommend SCS:

```julia
using SCS
```

## Basic Usage

Here's a simple example of how to use GSOpt.jl:

```julia
using GSOpt
using SCS

# Create a geometric programming model
model = GPModel(optimizer=SCS.Optimizer)

# Define variables (all variables must be positive in GP)
@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)

# Set objective (minimize a posynomial)
@objective(model, Min, x + y + x*y)

# Add constraints
@constraint(model, x * y ≥ 1)    # monomial inequality
@constraint(model, x / y ≤ 2)    # ratio constraint

# Solve the model
optimize!(model)

# Check solution status
status = termination_status(model)
println("Termination status: ", status)

# Get solution values
if status == MOI.OPTIMAL
    println("Optimal solution:")
    println("x = ", value(x))
    println("y = ", value(y))
    println("Objective value = ", objective_value(model))
end
```

## Key Components

GSOpt.jl provides several key components for working with geometric programs:

1. **GPModel**: A specialized model type that extends JuMP's capabilities for geometric programming
2. **Expressions**: Types for working with monomials and posynomials
3. **Variables**: Variables in a GP must be positive
4. **Constraints**: Support for monomial equality constraints and posynomial inequality constraints
5. **Transformations**: Automatic transformation to log space for solving

In the following sections, we'll explore each of these components in more detail.

# GSOpt.jl - Geometric & Signomial Optimization/Programming using JuMP

## Overview

GSOpt.jl is a Julia package that extends JuMP to solve geometric programming (GP) and signomial programming (SP) problems.
It provides a natural syntax for formulating these problems while handling the necessary transformations to convert them into convex optimization problems.

## Installation

```julia
using GSOpt
```

## Features

- Formulate geometric programming problems using familiar JuMP syntax
- Automatic transformation to log space for solving
- Support for posynomial constraints (<=) and monomial equality constraints (==)
- Minimization of posynomials and maximization of monomials
- Automatic transformation of solutions back from log space

## Quick Example

```julia
using GSOpt
using SCS

# Create a geometric programming model
model = GPModel(SCS.Optimizer)

# Define variables
@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)
@variable(model, z ≥ 0.1)

# Define objective (minimize a posynomial)
@objective(model, Min, x^-1 * y^-1 * z^-1 + x * y * z)

# Add constraints
@constraint(model, x * y * z == 1)     # monomial equality constraint
@constraint(model, 2x + 3y + 4z ≤ 10)  # posynomial inequality constraint

# Solve the problem
optimize!(model)

# Get the solution
println("Optimal solution:")
println("x = ", value(x))
println("y = ", value(y))
println("z = ", value(z))
```

## Mathematical Background

A geometric program is an optimization problem of the form:

```
minimize    f₀(x)
subject to  fᵢ(x) ≤ 1,  i = 1,...,m
            gⱼ(x) = 1,  j = 1,...,p
```

where each fᵢ is a posynomial and each gⱼ is a monomial.

A monomial is a function of the form:

```
g(x) = c·x₁^a₁·x₂^a₂·...·xₙ^aₙ
```

where c > 0 and aᵢ are real exponents.

A posynomial is a sum of monomials:

```
f(x) = ∑ᵏ cₖ·x₁^aₖ₁·x₂^aₖ₂·...·xₙ^aₖₙ
```

GSOpt.jl transforms these problems into convex form by taking the logarithm of variables, constraints, and objectives.

For more information, see [A Tutorial on Geometric Programming](https://stanford.edu/~boyd/papers/pdf/gp_tutorial.pdf) by Boyd et al. (2007).

## Implementation Details

GSOpt.jl defines the following types:

- `GPModel`: A JuMP model extension for geometric programming
- `Monomial`: Represents a monomial expression
- `Posynomial`: Represents a posynomial expression

The package overloads operators like `+`, `*`, and `^` to work with these types, allowing for natural expression of GP problems.

GSOpt.jl is organized into a modular structure:

- `expressions/`: Contains Monomial and Posynomial types with operator overloading
- `model/`: Contains the GPModel implementation
- `transformations/`: Handles log-space transformations for constraints and objectives

The package automatically handles the conversion to log-space for solving geometric programming problems, while keeping the sensitivities in the original space.

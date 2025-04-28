# GSOpt.jl

_Geometric Programming for JuMP_

## Overview

GSOpt.jl is a Julia package that extends [JuMP](https://jump.dev/) to solve geometric programming (GP) problems. It provides a natural syntax for formulating these problems while handling the necessary transformations to convert them into convex optimization problems.

## Features

- Formulate geometric programming problems using familiar JuMP syntax
- Automatic transformation to log space for solving
- Support for posynomial constraints (≤) and monomial equality constraints (==)
- Minimization of posynomials and maximization of monomials
- Automatic transformation of solutions back from log space
- Uses SCS solver for handling exponential cones

## Installation

This package is not yet registered. You can install it from GitHub:

```julia
import Pkg
Pkg.add(url="https://github.com/username/GSOpt.jl")
```

Or from your local directory:

```julia
import Pkg
Pkg.develop(path="/path/to/GSOpt.jl")
```

## Quick Example

```julia
using GSOpt
using SCS

# Create a geometric programming model
model = GPModel(optimizer=SCS.Optimizer)

# Define variables
@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)
@variable(model, z ≥ 0.1)

# Define objective (minimize a posynomial)
@objective(model, Min, x^-1 * y^-1 * z^-1 + x * y * z)

# Add constraints
@constraint(model, x * y * z == 1)  # monomial equality constraint
@constraint(model, 2x + 3y + 4z ≤ 10)  # posynomial inequality constraint

# Solve the problem
optimize!(model)

# Get the solution
println("Optimal solution:")
println("x = ", value(x))
println("y = ", value(y))
println("z = ", value(z))
```

## Documentation

For more detailed information, please refer to the following sections:

- [Getting Started](@ref) - Introduction to geometric programming with GSOpt.jl
- [Expressions](@ref) - Working with monomials and posynomials
- [Models](@ref) - Creating and working with GP models
- [Constraints](@ref) - Adding constraints to your model
- [Examples](@ref) - Complete examples of geometric programming problems
- [API Reference](@ref) - Detailed documentation of all exported functions and types

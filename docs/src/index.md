# GSOpt.jl

_Geometric and Signomial Programming for JuMP_

## Overview

GSOpt.jl is a Julia package that extends [JuMP](https://jump.dev/) to solve geometric programming (GP) and signomial programming (SP) problems.

## Related Packages

- [GPKit](https://github.com/convexengineering/gpkit): A Python package for geometric and signomial programming.

## Installation

You can install it from the registry

```julia
using GSOpt
```

## Quick Example

```@example
using GSOpt
using SCS

# Create a geometric programming model
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

# Define variables
@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)
@variable(model, z ≥ 0.1)

# Define objective (minimize a posynomial)
@objective(model, Min, 1/(x * y * z) + x * y * z)

# Add constraints
@constraint(model, x * y * z == 1)  # monomial equality constraint
@constraint(model, 2x + 3y + 4z ≤ 10)  # posynomial inequality constraint

# Solve the problem
optimize!(model)

# Get the solution
solution_summary(model, verbose=true)
```

## Documentation

For more detailed information, please refer to the following sections:

- [Getting Started](@ref) - Introduction to geometric programming with GSOpt.jl
- [Examples](@ref) - Complete examples of geometric programming problems
- [API Reference](@ref) - Detailed documentation of all exported functions and types

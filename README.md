# GSOpt.jl - Geometric & Signomial Optimization/Programming using JuMP

[![Documentation](https://img.shields.io/badge/docs-%F0%9F%93%9A-blue)](https://mopg.github.io/GSOpt.jl/stable)

## Overview

GSOpt.jl is a Julia package that extends JuMP to solve geometric programming (GP) and signomial programming (SP) problems.
The package takes care of the transformation to log-space and allows users to use familiar JuMP syntax to formulate problems.

## Related Packages

- [GPKit](https://github.com/convexengineering/gpkit): A Python package for geometric and signomial programming.

## Installation

```julia
using GSOpt
```

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
@objective(model, Min, 1/(x * y * z) + x * y * z)

# Add constraints
@constraint(model, x * y * z == 1)     # monomial equality constraint
@constraint(model, 2x + 3y + 4z ≤ 10)  # posynomial inequality constraint

# Solve the problem
optimize!(model)

# Get the solution
println("Optimal solution:")
println(solution_summary(model))
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

A problem of this form is convex in log-form, and can be solved using standard convex optimization solvers.

GSOpt.jl takes care of this transformation internally and the user can formulate problems as they normally would using JuMP.

For more information, see [A Tutorial on Geometric Programming](https://stanford.edu/~boyd/papers/pdf/gp_tutorial.pdf) by Boyd et al. (2007).

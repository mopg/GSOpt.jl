# Examples

This section provides complete examples of how to use GSOpt.jl to solve various geometric programming problems.

## Basic Example: Rectangle Design

This example finds the dimensions of a rectangle with minimum area, subject to constraints on perimeter and minimum area.

```@example
using GSOpt
using SCS
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

@variable(model, w ≥ 0.1)  # width
@variable(model, h ≥ 0.1)  # height

@objective(model, Min, w * h) # minimize area

@constraint(model, 2(w + h) ≤ 10)  # perimeter constraint
@constraint(model, w * h ≥ 2)      # minimum area constraint

optimize!(model)

solution_summary(model, verbose=true)
```

## Minimizing a Complex Posynomial

This example minimizes a complex posynomial objective function with both monomial equality and posynomial inequality constraints.

```@example
using GSOpt
using SCS

model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)
@variable(model, z ≥ 0.1)

@objective(model, Min, 1/(x * y * z) + x * y * z)

@constraint(model, x * y * z == 1)
@constraint(model, 2x + 3y + 4z ≤ 10)

optimize!(model)

solution_summary(model, verbose=true)
```

## Maximizing a Monomial

This example maximizes a monomial objective function with posynomial inequality constraints.

```@example
using GSOpt
using SCS

model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)

@objective(model, Max, x * y)

@constraint(model, 3x + 4y ≤ 10)
@constraint(model, x ≤ 5)
@constraint(model, y ≤ 5)

optimize!(model)

solution_summary(model, verbose=true)
```

## Engineering Example: Cantilever Beam Design

This example optimizes the design of a cantilever beam to minimize its weight while satisfying constraints on deflection and stress.

```@example
using GSOpt
using SCS

model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

# Parameters
E = 200e9      # Young's modulus (Pa)
σ_max = 100e6  # Maximum stress (Pa)
δ_max = 0.005  # Maximum deflection (m)
L = 1.0        # Length (m)
F = 10e3       # Applied force (N)

# Variables
@variable(model, h ≥ 0.01)  # Height (m)
@variable(model, b ≥ 0.01)  # Width (m)

# Objective: minimize volume (proportional to weight)
@objective(model, Min, b * h * L)

# Stress constraint
@constraint(model, 6*F*L/(b*h^2) ≤ σ_max)

# Deflection constraint
@constraint(model, 4*F*L^3/(E*b*h^3) ≤ δ_max)

optimize!(model)

solution_summary(model, verbose=true)
```

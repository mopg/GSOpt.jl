# Examples

This section provides complete examples of how to use GSOpt.jl to solve various geometric programming problems.

## Basic Example: Rectangle Design

This example finds the dimensions of a rectangle with minimum area, subject to constraints on perimeter and minimum area.

```julia
using GSOpt
using SCS

# Create a model
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

# Variables: width and height
@variable(model, w ≥ 0.1)  # width
@variable(model, h ≥ 0.1)  # height

# Objective: minimize area
@objective(model, Min, w * h)

# Constraints
@constraint(model, 2(w + h) ≤ 10)  # perimeter constraint
@constraint(model, w * h ≥ 2)      # minimum area constraint

# Solve
optimize!(model)

# Check solution
if termination_status(model) == MOI.OPTIMAL
    println("Optimal solution found:")
    println("Width = ", value(w))
    println("Height = ", value(h))
    println("Area = ", objective_value(model))
    println("Perimeter = ", 2 * (value(w) + value(h)))
end
```

Expected output:

```
Optimal solution found:
Width = 1.4142135623730951
Height = 1.4142135623730951
Area = 2.0
Perimeter = 5.656854249492381
```

## Minimizing a Complex Posynomial

This example minimizes a complex posynomial objective function with both monomial equality and posynomial inequality constraints.

```julia
using GSOpt
using SCS

# Create a model
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

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
if termination_status(model) == MOI.OPTIMAL
    println("Optimal solution found:")
    println("x = ", value(x))
    println("y = ", value(y))
    println("z = ", value(z))
    println("Objective value = ", objective_value(model))
end
```

## Maximizing a Monomial

This example maximizes a monomial objective function with posynomial inequality constraints.

```julia
using GSOpt
using SCS

# Create a model
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

# Define variables
@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)

# Define objective (maximize a monomial)
@objective(model, Max, x * y)

# Add constraints
@constraint(model, 3x + 4y ≤ 10)  # posynomial constraint
@constraint(model, x ≤ 5)         # upper bound
@constraint(model, y ≤ 5)         # upper bound

# Solve the problem
optimize!(model)

# Get the solution
if termination_status(model) == MOI.OPTIMAL
    println("Optimal solution found:")
    println("x = ", value(x))
    println("y = ", value(y))
    println("Objective value = ", objective_value(model))
    println("Constraint value: 3x + 4y = ", 3*value(x) + 4*value(y))
end
```

## Engineering Example: Cantilever Beam Design

This example optimizes the design of a cantilever beam to minimize its weight while satisfying constraints on deflection and stress.

```julia
using GSOpt
using SCS

# Create a model
model = GPModel(optimizer=SCS.Optimizer)
set_silent(model)

# Parameters
E = 200e9    # Young's modulus (Pa)
σ_max = 100e6  # Maximum stress (Pa)
δ_max = 0.005  # Maximum deflection (m)
L = 1.0      # Length (m)
F = 10e3     # Applied force (N)

# Variables
@variable(model, h ≥ 0.01)  # Height (m)
@variable(model, b ≥ 0.01)  # Width (m)

# Objective: minimize volume (proportional to weight)
@objective(model, Min, b * h * L)

# Constraints
# Stress constraint: σ = 6*F*L/(b*h^2) ≤ σ_max
@constraint(model, 6*F*L/(b*h^2) ≤ σ_max)

# Deflection constraint: δ = 4*F*L^3/(E*b*h^3) ≤ δ_max
@constraint(model, 4*F*L^3/(E*b*h^3) ≤ δ_max)

# Solve
optimize!(model)

# Check solution
if termination_status(model) == MOI.OPTIMAL
    println("Optimal beam dimensions:")
    println("Width (b) = ", value(b), " m")
    println("Height (h) = ", value(h), " m")
    println("Volume = ", objective_value(model), " m³")
    println("Stress = ", 6*F*L/(value(b)*value(h)^2)/1e6, " MPa")
    println("Deflection = ", 4*F*L^3/(E*value(b)*value(h)^3)*1000, " mm")
end
```

# Models

## GPModel

The core of GSOpt.jl is the `GPModel` type, which extends JuMP's modeling capabilities for geometric programming problems.

### Creating a GPModel

To create a geometric programming model, use the `GPModel` constructor:

```julia
using GSOpt
using SCS  # or another solver that supports exponential cones

# Create a model with a specific optimizer
model = GPModel(optimizer=SCS.Optimizer)

# You can also set optimizer attributes
model = GPModel(optimizer=SCS.Optimizer)
set_optimizer_attribute(model, "eps", 1e-8)
set_silent(model)  # Suppress solver output
```

## Variables

In geometric programming, all variables must be positive. GSOpt.jl enforces this by requiring lower bounds on all variables.

### Creating Variables

```julia
# Create a variable with default lower bound (0.1)
@variable(model, x ≥ 0.1)

# Create a variable with a specific lower bound
@variable(model, y ≥ 1.0)

# Create an array of variables
@variable(model, z[1:3] ≥ 0.1)
```

### Variable Bounds

Variables in geometric programming must have positive lower bounds. Upper bounds are optional:

```julia
# Variable with both lower and upper bounds
@variable(model, 1 ≤ w ≤ 10)
```

## Objectives

In geometric programming:

- You can minimize posynomials
- You can maximize monomials

### Setting an Objective

```julia
# Minimize a posynomial
@objective(model, Min, x + y + x*y)

# Maximize a monomial
@objective(model, Max, x * y)
```

## Solving the Model

To solve a geometric programming model, use JuMP's `optimize!` function:

```julia
# Solve the model
optimize!(model)

# Check termination status
status = termination_status(model)
if status == MOI.OPTIMAL
    println("Model solved to optimality")
elseif status == MOI.TIME_LIMIT && has_values(model)
    println("Solution found, but time limit reached")
else
    println("Model not solved: ", status)
end
```

## Retrieving Solutions

After solving the model, you can retrieve the solution using JuMP's standard functions:

```julia
# Get variable values
x_val = value(x)
y_val = value(y)

# Get objective value
obj_val = objective_value(model)

# Check if the solution is optimal
is_optimal = termination_status(model) == MOI.OPTIMAL
```

## Model Attributes

You can query various attributes of the model:

```julia
# Get solver name
solver_name = solver_name(model)

# Get solve time
solve_time = solve_time(model)

# Get number of variables
num_variables = num_variables(model)
```

## Example: Rectangle Design

Here's a complete example that demonstrates how to use a `GPModel` to solve a rectangle design problem:

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
else
    println("Model not solved to optimality. Status: ", termination_status(model))
end
```

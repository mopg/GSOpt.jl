# Transformations

One of the key features of GSOpt.jl is its ability to automatically transform geometric programming problems into equivalent convex optimization problems. This transformation is crucial for solving geometric programming problems efficiently.

## Log Transformation

Geometric programming problems are not convex in their original form. However, they can be transformed into convex optimization problems through a logarithmic change of variables.

### Variable Transformation

For each variable $x_i$ in the original problem, we define a new variable $y_i = \log(x_i)$. This means:

- $x_i = e^{y_i}$
- $x_i > 0$ for all $i$ (a requirement for geometric programming)

### Monomial Transformation

A monomial $g(x) = c \cdot x_1^{a_1} \cdot x_2^{a_2} \cdot \ldots \cdot x_n^{a_n}$ transforms to:

$\log(g(e^y)) = \log(c) + a_1 y_1 + a_2 y_2 + \ldots + a_n y_n$

This is an affine function of $y$.

### Posynomial Transformation

A posynomial $f(x) = \sum_k c_k \cdot x_1^{a_{k1}} \cdot x_2^{a_{k2}} \cdot \ldots \cdot x_n^{a_{kn}}$ transforms to:

$\log(f(e^y)) = \log(\sum_k e^{\log(c_k) + a_{k1} y_1 + a_{k2} y_2 + \ldots + a_{kn} y_n})$

This is a log-sum-exp function, which is convex in $y$.

## Constraint Transformation

### Monomial Equality Constraints

A monomial equality constraint $g(x) = 1$ transforms to:

$\log(g(e^y)) = 0$

This is an affine equality constraint in $y$.

### Posynomial Inequality Constraints

A posynomial inequality constraint $f(x) \leq 1$ transforms to:

$\log(f(e^y)) \leq 0$

This is a convex inequality constraint in $y$.

## Objective Transformation

### Minimizing a Posynomial

When minimizing a posynomial $f_0(x)$, the objective becomes:

$\min \log(f_0(e^y))$

This is a convex objective function.

### Maximizing a Monomial

When maximizing a monomial $g_0(x)$, the objective becomes:

$\max \log(g_0(e^y))$

Which is equivalent to:

$\min -\log(g_0(e^y))$

This is also a convex objective function.

## Implementation in GSOpt.jl

GSOpt.jl handles these transformations automatically. When you create a `GPModel` and add variables, constraints, and an objective function, GSOpt.jl:

1. Creates the corresponding log-transformed variables internally
2. Transforms the constraints to their convex form
3. Transforms the objective function to its convex form
4. Solves the resulting convex optimization problem
5. Transforms the solution back to the original space

This allows you to work with the more intuitive geometric programming formulation while benefiting from the efficiency of convex optimization solvers.

## Example

Consider this simple geometric programming problem:

```julia
using GSOpt
using SCS

model = GPModel(optimizer=SCS.Optimizer)

@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)

@objective(model, Min, x * y + x / y)

@constraint(model, x * y ≥ 1)

optimize!(model)
```

Behind the scenes, GSOpt.jl transforms this to a convex problem by:

1. Creating log variables: $u = \log(x)$, $v = \log(y)$
2. Transforming the objective: $\min \log(e^{u+v} + e^{u-v})$
3. Transforming the constraint: $u + v \geq 0$
4. Solving the convex problem
5. Transforming the solution back: $x = e^u$, $y = e^v$

This transformation process is completely transparent to the user, allowing you to focus on the geometric programming formulation.

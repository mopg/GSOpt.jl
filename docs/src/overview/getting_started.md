# Getting Started

## Introduction to Geometric Programming

Geometric programming (GP) is a type of mathematical optimization problem where the objective function and constraints are expressed in terms of monomials and posynomials.

A **monomial** is a function of the form:

```math
g(x) = c\, x_1^{a_1} x_2^{a_2} \cdots x_n^{a_n}
```

where $c > 0$ and $a_i$ are real exponents.

A **posynomial** is a sum of monomials:

```math
f(x) = \sum_{i=1}^k c_i\, x_1^{a_{i1}} x_2^{a_{i2}} \cdots x_n^{a_{in}}
```

where $c_i > 0$ and $a_{ij}$ are real exponents.

A geometric program has the form:

```math
\begin{align*}
\text{min} & \quad f_0(x) \\
\text{subject to} & \quad f_i(x) \leq 1, \quad i = 1,\ldots,m \\
& \quad g_j(x) = 1, \quad j = 1,\ldots,p
\end{align*}
```

where each $f_i$ is a posynomial and each $g_j$ is a monomial.
This optimization problem is convex in log-space.
GSOpt.jl transforms the problem to log-space and solves it using a convex optimizer and then transforms the results back to non-log space for you.

For more information, see [A Tutorial on Geometric Programming](https://stanford.edu/~boyd/papers/pdf/gp_tutorial.pdf) by Boyd et al. (2007).

## Signomial Programming

For signomial programming, the same type of model is used, but some of the constraints can be signomials.

```math
\begin{align*}
\text{min} & \quad f(x) \\
\text{subject to} & \quad p_i(x) \leq q_i(x), \quad i = 1,\ldots,m \\
& \quad g_j(x) = 1, \quad j = 1,\ldots,p
\end{align*}
```

where each $f$ is a posynomial, and each $p_i$ and $q_i$ are posynomials, and each $g_j$ is a monomial.
This optimization problem is no longer convex in log-space, meaning a global solution is no longer guaranteed.
GSOpt.jl solves these types of problems iteratively, by solving a GP subproblem that is convex in log-space.

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

```example
using GSOpt
using SCS

model = GPModel(optimizer=SCS.Optimizer)

@variable(model, x ≥ 0.1)
@variable(model, y ≥ 0.1)

@objective(model, Min, x + y + x*y)

@constraint(model, x * y ≥ 1)    # monomial inequality
@constraint(model, x / y ≤ 2)    # ratio constraint

optimize!(model)

solution_summary(model)
```

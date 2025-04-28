module GSOpt

# Reexport JuMP so users don't need to import it separately
import Reexport
Reexport.@reexport using JuMP

# Import necessary packages
import MathOptInterface
import JuMP

# Aliases for convenience
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MA = JuMP._MA

# Include abstract expression first because it's needed by model components
include("types/abstract_types.jl")
include("model/constraint_types.jl")

# Include the model core components
include("model/gp_model.jl")
include("model/variables.jl")

# Include expressions after variables because expressions use variables
include("expressions/expressions.jl")

# Include expression operators last since they use model components
include("expressions/operators.jl")

# Include constraints after operators are defined
include("model/constraints.jl")

# Include transformations last as they depend on everything else
include("model/transformations.jl")

# Export main types and functions
export GPModel, GPVariable, GPConstraintRef
export AbstractGPExpression,
    MonomialTerm, MonomialExpression, PosynomialExpression, SignomialExpression
export is_monomial, is_posynomial

end # module

abstract type AbstractSpGpModel <: JuMP.AbstractModel end

mutable struct ModelSolutionInfo

    variable_values::Dict{Int,Float64} # Maps variable index to value
    objective_value::Union{Nothing,Float64}
    termination_status::Union{Nothing,MOI.TerminationStatusCode}
    solve_time::Union{Nothing,Float64}
    constraint_duals::Union{Nothing,Dict{Int,Float64}} # Maps constraint index to dual value

end

function ModelSolutionInfo()
    return ModelSolutionInfo(Dict{Int,Float64}(), nothing, nothing, nothing, nothing)
end

function is_silent(model::AbstractSpGpModel)
    return MOI.get(model.optimizer_factory, MOI.Silent())
end

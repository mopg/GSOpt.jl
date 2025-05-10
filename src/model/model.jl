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
    is_silent = MOI.get(model.optimizer_factory, MOI.Silent())

    if is_silent === nothing
        return false
    end

    return is_silent
end


struct _SolutionSummary
    is_gp::Bool
    termination_status::MOI.TerminationStatusCode
    objective_value::Union{Nothing,Float64}
    solve_time::Union{Nothing,Float64}
    variable_count::Int
    constraint_count::Int
    variable_values::Dict{String,Float64}  # Store variable values by name
    constraint_duals::Dict{Int,Float64}    # Store constraint duals by index
    verbose::Bool
end


function Base.show(io::IO, summary::_SolutionSummary)
    if summary.is_gp
        print(io, "Geometric Programming Solution Summary:")
    else
        print(io, "Signomial Programming Solution Summary:")
    end
    print(io, "\n ├ Termination status: ", summary.termination_status)

    if !isnothing(summary.objective_value)
        print(io, "\n ├ Objective value: ", summary.objective_value)
    else
        print(io, "\n ├ Objective value: Not available")
    end

    if !isnothing(summary.solve_time)
        print(io, "\n ├ Solve time: ", round(summary.solve_time, digits = 4), " seconds")
    else
        print(io, "\n ├ Solve time: Not available")
    end

    print(io, "\n ├ Variables: ", summary.variable_count)
    print(io, "\n ├ Constraints: ", summary.constraint_count)

    # If verbose, show more details
    if summary.verbose &&
       summary.termination_status in [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]
        # Show variable values if available
        if !isempty(summary.variable_values)
            print(io, "\n │")
            print(io, "\n ├ Variable values:")
            for (name, value) in summary.variable_values
                print(io, "\n │  ", name, " = ", value)
            end
        end

        # Show constraint duals if available
        if !isempty(summary.constraint_duals)
            print(io, "\n │")
            print(io, "\n ├ Constraint duals:")
            for (idx, dual) in summary.constraint_duals
                print(io, "\n │  Constraint ", idx, ": ", dual)
            end
        end
    end
end

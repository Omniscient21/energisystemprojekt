"""
  Runs the energy system model.
"""

module energisystemprojekt

using JuMP, AxisArrays, Gurobi, UnPack, #Plots

export runmodel

include("input_energisystemprojekt.jl")
include("model_energisystemprojekt.jl")

function runmodel()
    # TODO: kolla plotly!

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity = model

    println("\nSolving model...")

    status = optimize!(m)


    if termination_status(m) == MOI.OPTIMAL
        println("\nSolve status: Optimal")
    elseif termination_status(m) == MOI.TIME_LIMIT && has_values(m)
        println("\nSolve status: Reached the time-limit")
    else
        error("The model was not solved correctly.")
    end

    Cost_result = objective_value(m)/1000000 # M€
    Capacity_result = value.(Capacity)


    println("Cost (M€): ", Cost_result)

    #InstalledCapacity_vector =
    #plot(InstalledCapacity_vector, title = "Installed Capacity", label=["Installed Capacity"])
    #plot(Generators_vector, title = "Domestic generators in Germany", label=["Domestic generators in Germany"])

    nothing

end #runmodel

end # module

"""
  Runs the energy system model.
"""

module energisystemprojekt

using JuMP, AxisArrays, Gurobi, UnPack#, Plots

export runmodel

include("input_energisystemprojekt.jl")
include("model_energisystemprojekt.jl")

function runmodel()
    # TODO: kolla plotly!

    input = read_input()

    model = buildmodel(input)

    @unpack m, InstalledCapacity, Electricity, CO2emission = model

    println("\nSolving model...")

    status = optimize!(m)


    if termination_status(m) == MOI.OPTIMAL
        println("\nSolve status: Optimal")
    elseif termination_status(m) == MOI.TIME_LIMIT && has_values(m)
        println("\nSolve status: Reached the time-limit")
    else
        error("The model was not solved correctly.")
    end

    Cost_result = objective_value(m)/1000000 # €->M€
    Capacity_result = value.(InstalledCapacity)
    Emission_result = value.(CO2emission) # Mton CO2


    println("Cost (M€): ", Cost_result)
    println("CO2 Emission (Mton): ", Emission_result)

    #append!(InstalledCapacities, InstalledCapacity(m))
    #@unpack REGION, PLANT, numregions = input
    #InstalledCapacity_vector = AxisArray(zeros(numregions), REGION)
    #for r in REGION
    #    InstalledCapacity_vector[r] = sum(InstalledCapacities[r, p] for p in PLANT)
    #end

    #x_axis = 1:4
    #AnnualProduktion =
    #plot(REGION, InstalledCapacity_vector[:, p in PLANT], title = "Installed Capacity", label=["Installed Capacity"])
    #plot(Generators_vector, title = "Domestic generators in Germany", label=["Domestic generators in Germany"])

    nothing

    #Exercise:      1,         2      3      4
    # Total cost: 37238 [M€], 66305, 49121, 43619
    # Emissions: 139 [Mton], 13.9 for E2,3,4

end #runmodel

end # module

"""
  Runs the energy system model.
"""

module energisystemprojekt

using JuMP, AxisArrays, Gurobi, UnPack, PlotlyJS, CSV, DataFrames

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
    println("Capacity (MW): ", Capacity_result)
    println("CO2 Emission (Mton): ", Emission_result)


    @unpack REGION, PLANT, numregions = input
    InstalledCapacity_vector = AxisArray(zeros(numregions), REGION)
    for r in REGION
       InstalledCapacity_vector[r] = sum(value.(InstalledCapacity[r, p]) for p in PLANT)
    end
    println(InstalledCapacity_vector)

    #df = dataset(DataFrame, "Installed Capacities")
    #long_df = stack(df, Not([:REGION]), variable_name="medal", value_name="count")
    #plot(df, kind="bar", x=:REGION, Layout(title="Installed Capacities"), kind="bar")

    df = DataFrame(A=InstalledCapacity_vector, B=[:Denmark, :Sweden, :Germany])
    println(df)
    plot(df, x=df.B, y = df.A, kind = "bar", Layout(title="Installed Capacities"))



    # x_axis = 1:4
    # AnnualProduktion =
    # plot(REGION, InstalledCapacity_vector[:, p in PLANT], title = "Installed Capacity", label=["Installed Capacity"])
    # plot(Generators_vector, title = "Domestic generators in Germany", label=["Domestic generators in Germany"])

    nothing

    #Exercise:      1,     2      3      4
    # Total cost: 37238, 66305, 49121, 43619  [M€]
    # Emissions:   139,   13.9,  13.9   13.9 [Mton]

end #runmodel

end # module

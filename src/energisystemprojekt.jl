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

    @unpack m, InstalledCapacity, Electricity, CO2emission, GeneratedElectricity = model
    @unpack REGION, PLANT, HOUR, numregions, numplants = input

    println("\nSolving model...")

    status = optimize!(m)


    if termination_status(m) == MOI.OPTIMAL
        println("\nSolve status: Optimal")
    elseif termination_status(m) == MOI.TIME_LIMIT && has_values(m)
        println("\nSolve status: Reached the time-limit")
    else
        error("The model was not solved correctly.")
    end


    # Calculates installed capacity in each region
    RegionalCapacity = AxisArray(zeros(numregions), REGION)
    for r in REGION
       RegionalCapacity[r] = sum(value.(InstalledCapacity[r, p]) for p in PLANT)
    end
    # Calculates annual produktion in each region
    AnnualProduktion = AxisArray(zeros(numregions), REGION)
    for r in REGION
       AnnualProduktion[r] = sum(value.(GeneratedElectricity[r, h]) for h in HOUR)
    end
    # Production in Germany hour 147-651
    GermanyGenerators = AxisArray(zeros(651-147+1), 147:651)
    for h in 147:651
       GermanyGenerators[h-146] = value.(GeneratedElectricity[:DE, h])
    end

    Cost_result = objective_value(m)/1000000 # €->M€
    Capacity_result = value.(InstalledCapacity)
    Emission_result = value.(CO2emission) # Mton CO2

    println("Cost (M€): ", Cost_result)
    #println("Capacity (MW): ", Capacity_result)
    println("CO2 Emission (Mton): ", Emission_result)
    println("CO2 Emission (Mton): ", AnnualProduktion)
    println("Regional Capacity (MW): ", RegionalCapacity)
    println("Produktion in Germany (MW): ", GermanyGenerators)

    # Plots:
    dfInstalledCapacities = DataFrame(A=RegionalCapacity, B=[:Germany, :Sweden, :Denmark])
    display(plot(dfInstalledCapacities, x=dfInstalledCapacities.B, y = dfInstalledCapacities.A, kind = "bar", Layout(title="Installed Capacities (MW)")))

    dfGeneratedElectricity = DataFrame(A=AnnualProduction_vector, B=[:Germany, :Sweden, :Denmark])
    display(plot(dfGeneratedElectricity, x=dfGeneratedElectricity.B, y = df.A, kind = "bar", Layout(title="Annual Production (MWh)")))

    dfGermanyGenerators = DataFrame(A=GermanyGenerators, B=147:651)
    display(plot(dfGermanyGenerators, x=dfGermanyGenerators.B, y = dfGermanyGenerators.A, kind="scatter", mode="lines", Layout(title="Production in Germany hour 147-651 (MW)")))






    # Plots the total annual produktion
    # df = DataFrame(A=[AnnualProduktion], B=[:Denmark, :Sweden, :Germany])
    # println(df)
    # plot(df, x=df.B, y=df.A, kind = "bar", Layout(title="Annual produktion"))



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

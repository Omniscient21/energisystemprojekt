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

    @unpack m, InstalledCapacity, Electricity, Emission, GeneratedElectricity, TransmissionCapacity = model
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
    # Installed capacity values
    Capacity = AxisArray(zeros(numregions, numplants), REGION, PLANT)
    for r in REGION
      for p in PLANT
       Capacity[r, p] = value.(InstalledCapacity[r, p])
      end
    end
    # Calculates annual produktion in each region
    AnnualProduction = AxisArray(zeros(numregions), REGION)
    for r in REGION
       AnnualProduction[r] = sum(value.(GeneratedElectricity[r, h]) for h in HOUR)
    end
    # Production in Germany hour 147-651
    GermanyGenerators = AxisArray(zeros(651-147+1), 147:651)
    for h in 147:651
       GermanyGenerators[h-146] = value.(GeneratedElectricity[:DE, h])
    end
    Combination = [:DeSe, :SeDk, :DkDe]
    TransCap = AxisArray(zeros(numregions), Combination) # "Germany-Sweden", "Sweden-Denmark", "Denmark-Germany"
    TransCap[Combination[1]] = value.(TransmissionCapacity[:DE, :SE])
    TransCap[Combination[2]] = value.(TransmissionCapacity[:SE, :DK])
    TransCap[Combination[3]] = value.(TransmissionCapacity[:DK, :DE])

    Cost_result = objective_value(m)/1000000 # €->M€
    Capacity_result = value.(InstalledCapacity)
    Emission_result = value.(Emission) # Mton CO2

    println("Cost (M€): ", Cost_result)
    println("Capacity (MW): ", Capacity_result)
    println("CO2 Emission (Mton): ", Emission_result)
    println("Annual production (MWh): ", AnnualProduction)
    println("Regional Capacity (MW): ", RegionalCapacity)
    println("Transmission Capacity (MW): ", TransCap)
    println("Produktion in Germany (MW): ", GermanyGenerators)

    # Plots:
    # dfInstalledCapacities = DataFrame(A=RegionalCapacity, B=[:Germany, :Sweden, :Denmark])
    # plot_InstalledCapacities() = plot(dfInstalledCapacities, x=dfInstalledCapacities.B, y = dfInstalledCapacities.A, kind = "bar", Layout(title="Installed Capacities (MW)"))

    df = DataFrame(Wind=Capacity[:, :Wind], PV=Capacity[:, :PV], Gas=Capacity[:, :Gas],
      Hydro=Capacity[:, :Hydro], Region=[:Germany, :Sweden, :Denmark], Batteries=Capacity[:, :Batteries], Transmission=Capacity[:, :Transmission], Nuclear=Capacity[:, :Nuclear])
    dfCapacity = stack(df)#, Not([:H]))
    println(dfCapacity)
    plot_Capacity() = plot(dfCapacity, x=:Region, y=:value, color=:variable, kind="bar", Layout(title="Installed Capacities (MW)", barmode="stack"))
    display(plot_Capacity())

    # dfGeneratedElectricity = DataFrame(A=AnnualProduction, B=[:Germany, :Sweden, :Denmark])
    # plot_GeneratedElectricity() = plot(dfGeneratedElectricity, x=dfGeneratedElectricity.B, y = dfGeneratedElectricity.A, kind = "bar", Layout(title="Annual Production (MWh)"))
    #
    # dfGermanyGenerators = DataFrame(A=GermanyGenerators, B=147:651)
    # plot_GermanyGenerators() = plot(dfGermanyGenerators, x=dfGermanyGenerators.B, y = dfGermanyGenerators.A, kind="scatter", mode="lines", Layout(title="Production in Germany hour 147-651 (MW)"))
    #
    # dfTransmissionCapacity = DataFrame(A=TransCap, B=["Germany-Sweden", "Sweden-Denmark", "Denmark-Germany"])
    # plot_TransmissionCapacity() = plot(dfTransmissionCapacity, x=dfTransmissionCapacity.B, y = dfTransmissionCapacity.A, kind = "bar", Layout(title="Transmission Capacity (MW)"))


    # p = [plot_Capacity(); plot_GeneratedElectricity(); plot_GermanyGenerators(); plot_TransmissionCapacity()]
    # relayout!(p, title_text="Exercise 3 plots")
    # display(p)

    # df = dataset(DataFrame, "medals")
    # long_df = stack(df, Not([:nation]), variable_name="medal", value_name="count")
    #
    # plot(long_df, kind="bar", x=:nation, y=:count, color=:medal, Layout(title="Long-Form Input", barmode="stack"))



    nothing

    #Exercise:      1,     2      3      4
    # Total cost: 37238, 66305, 49121, 43619  [M€]
    # Emissions:   139,   13.9,  13.9   13.9 [Mton]

end #runmodel

end # module

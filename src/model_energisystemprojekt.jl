"""
  Constructs and returns the energy system model.
"""

function buildmodel(input)

    println("\nBuilding model...")

    @unpack REGION, PLANT, PLANTFACT, HOUR, numregions, load, maxcap, assum, discountrate, cf, hydro_inflow = input

    m = Model(Gurobi.Optimizer)

    @variables m begin
        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MW
        InstalledCapacity[r in REGION, p in PLANT]            >= 0        # MW
        ReservoirContent[h in HOUR]                           >= 0        # TWh
        CO2emission                                           >= 0        # ton
    end #variables
    #print(Capacity)

    #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(InstalledCapacity[r, p], maxcap[r, p])
    end

    function a(d,p)
        1-(1/(1+d)^assum[:Lifetime,p])
    end

    # test expression TODO: check all expressions
    @expression(m, Runningcost[r in REGION], sum(Electricity[r,p,h].*assum[:RunCost,p] for p in PLANT, h in HOUR))
    @expression(m, Investmentcost[r in REGION],
        sum(InstalledCapacity[r,p].*assum[:InvestmentCost,p].*(10^3).*discountrate./a(discountrate,p) for p in PLANT)) # €/MWh
    @expression(m, Fuelcost[r in REGION], sum(Electricity[r,p,h].*assum[:FuelCost,p]./assum[:Efficiency,p] for h in HOUR, p in PLANT))
    @expression(m, Systemcost[r in REGION], Runningcost[r] + Investmentcost[r] + Fuelcost[r])

    @expression(m, GeneratedElectricity[r in REGION, h in HOUR], sum(Electricity[r,p,h] for p in PLANT))

    @expression(m, CapacityPerHour[r in REGION, p in PLANT, h in HOUR], sum(InstalledCapacity[r, p].*cf[r, p, h]))

    # only gas has emission factor > 0
    @expression(m, Emission, sum(Electricity[r, p, h]./assum[:Efficiency, p].*assum[:EmissionFactor, p] for r in REGION, p in PLANT, h in HOUR)) # ton CO2

    #@expression(m, HydroReservoirNet, sum(hydro_inflow[h] for h in HOUR) - sum(Electricity[:SE, :Hydro, h] for h in HOUR))

    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR], # name of constraint
            Electricity[r, p, h] <= CapacityPerHour[r, p, h]

        Syscost[r in REGION], # name of constraint
            Systemcost[r] >= 0 # sum of all annualized costs

        CapacityConstraints[r in REGION, p in PLANT],
            InstalledCapacity[r, p] <= maxcap[r,p]

        GenElec[r in REGION, h in HOUR],
            GeneratedElectricity[r, h] >= load[r, h]

        #HydroReservoir,
        #    HydroReservoirNet == 0

        ReservoirBalance[h in HOUR[2:end]],
            ReservoirContent[h] <= ReservoirContent[h-1] + hydro_inflow[h] - Electricity[:SE, :Hydro, h]./(10^6) #TODO: h-1 correct?

        ReservoirEndOfYear,
            ReservoirContent[1] == ReservoirContent[end]

        ReservoirLimit[h in HOUR],
            ReservoirContent[h] <= 33 # TWh

        EmissionConstraint,
            CO2emission == Emission

    end #constraints

    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (; m, InstalledCapacity, Electricity, CO2emission)

end # buildmodel

function calculate_generation(input)

end # calculate_generation

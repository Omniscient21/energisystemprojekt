"""
  Constructs and returns the energy system model.
"""

function buildmodel(input)

    println("\nBuilding model...")

    @unpack REGION, PLANT, PLANTFACT, HOUR, numregions, load, maxcap, assum, discountrate, wind_cf, pv_cf, hydro_inflow = input

    m = Model(Gurobi.Optimizer)

    @variables m begin
        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MWh/h
        InstalledCapacity[r in REGION, p in PLANT]            >= 0        # MW
    end #variables
    #print(Capacity)

    #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(InstalledCapacity[r, p], maxcap[r, p])
    end

    function a(d,p)
        1-(1/(1+d)^assum[:Lifetime,p])
    end

    # test expression TODO: check all expressions, r in REGION?
    @expression(m, Runningcost[r in REGION], sum(Electricity[r,p,h].*assum[:RunCost,p] for p in PLANT, h in HOUR))
    @expression(m, Investmentcost[r in REGION], sum(InstalledCapacity[r,p].*assum[:InvestmentCost,p].*discountrate./a(discountrate,p) for p in PLANT))
    @expression(m, Fuelcost[r in REGION], sum(Electricity[r,:Gas,h].*assum[:FuelCost,:Gas] for h in HOUR))
    @expression(m, Systemcost[r in REGION], Runningcost[r] + Investmentcost[r] + Fuelcost[r])

    @expression(m, GeneratedElectricity[r in REGION, h = HOUR], sum(Electricity[r,p,h] for p in PLANT))

    # @expression(m, CapacityPerHour[r in REGION, p in PLANT, h in HOUR], 0)
    # add_to_expression!(CapacityPerHour[r = REGION, p = [:Wind, :PV], h = HOUR], #TODO:
    #     InstalledCapacity[r, p]
    # )
    # add_to_expression!(CapacityPerHour[r in REGION, p = :Wind, h in HOUR],
    #     sum(InstalledCapacity[r, p].*wind_ch[r, h])
    # )
    # add_to_expression!(CapacityPerHour[r in REGION, p = :PV, h in HOUR],
    #     sum(InstalledCapacity[r, p].*pv_ch[r, h])
    # )

    @expression(m, HydroReservoirNet, sum(hydro_inflow[h] for h in HOUR) - sum(Electricity[:SE, :Hydro, h] for h in HOUR))

    @constraints m begin
        #Generation[r in REGION, p in PLANT, h in HOUR], # name of constraint
        #    Electricity[r, p, h] <= CapacityPerHour[r, p, h] # * capacity factor

        Syscost[r in REGION], # name of constraint
            Systemcost[r] >= 0 # sum of all annualized costs

        CapacityConstraints[r in REGION, p in PLANT],
            InstalledCapacity[r, p] <= maxcap[r,p] # TODO: same for hydro?

        GenElec[r in REGION, h in HOUR],
            GeneratedElectricity[r, h] >= load[r, h]

        #HydroReservoir,
        #    HydroReservoirNet = 0

    end #constraints

    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (; m, InstalledCapacity, Electricity)

end # buildmodel

function calculate_generation(input)

end # calculate_generation

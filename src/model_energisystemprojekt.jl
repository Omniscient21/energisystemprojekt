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
        Emission                                              >= 0        # Mton

        # Exercise 2
        BatteryContent[r in REGION, h in HOUR]                >= 0        # MWh / MW
        BatteryInput[r in REGION, h in HOUR]                  >= 0        # MW

        # Exercise 3
        TransmissionCapacity[r in REGION, R in REGION]        >= 0        # MW
        Transmission[r in REGION, R in REGION, h in HOUR]     >= 0        # MW, r: transmission in, R: transmission out
    end #variables
    #print(Capacity)

    #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(InstalledCapacity[r, p], maxcap[r, p]) # MW
    end

    function a(d,p)
        1-(1/(1+d)^assum[:Lifetime,p])
    end

    # test expression TODO: check all expressions
    @expression(m, Runningcost[r in REGION], sum(Electricity[r,p,h].*assum[:RunCost,p] for p in PLANT, h in HOUR)) # €
    @expression(m, Investmentcost[r in REGION],
        sum(InstalledCapacity[r,p].*(assum[:InvestmentCost,p].*(10^3)).*discountrate./a(discountrate,p) for p in PLANT)) # €
    @expression(m, Fuelcost[r in REGION], sum(Electricity[r,p,h].*assum[:FuelCost,p]./assum[:Efficiency,p] for h in HOUR, p in PLANT)) #€
    @expression(m, Systemcost[r in REGION], Runningcost[r] + Investmentcost[r] + Fuelcost[r]) # €

    @expression(m, GeneratedElectricity[r in REGION, h in HOUR], sum(Electricity[r,p,h] for p in [:Wind, :PV, :Gas, :Hydro, :Nuclear])) # MW
    #@expression(m, GeneratedElectricityNet[r in REGION, h in HOUR], sum(Electricity[r,p,h] for p in PLANT)-BatteryInput[r,h])
    @expression(m, GeneratedElectricityNet[r in REGION, h in HOUR],
        sum(Electricity[r,p,h] for p in PLANT)-BatteryInput[r,h]-sum(Transmission[R, r, h] for R in REGION)./assum[:Efficiency,:Transmission]) # transmission input in Electricity[r, :Transmission,h]

    @expression(m, CapacityPerHour[r in REGION, p in PLANT, h in HOUR], sum(InstalledCapacity[r, p].*cf[r, p, h])) # MW


    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR], # name of constraint
            Electricity[r, p, h] <= CapacityPerHour[r, p, h]

        Syscost[r in REGION], # name of constraint
            Systemcost[r] >= 0 # sum of all annualized costs

        CapacityConstraints[r in REGION, p in PLANT],
            InstalledCapacity[r, p] <= maxcap[r,p]

        #GenElec[r in REGION, h in HOUR],
        #    GeneratedElectricity[r, h] >= load[r, h]
        GenElec[r in REGION, h in HOUR],
            GeneratedElectricityNet[r, h] >= load[r, h]

        ReservoirBalance[h in HOUR[1:end-1]],
            ReservoirContent[h+1] <= ReservoirContent[h] + hydro_inflow[h] - Electricity[:SE, :Hydro, h]./(10^6) #TODO: h-1 correct?

        ReservoirEndOfYear,
            ReservoirContent[1] == ReservoirContent[end]

        ReservoirLimit[h in HOUR],
            ReservoirContent[h] <= 33 # TWh

        #Exercise 2:
        MinEmission,
            Emission >= sum((Electricity[r, :Gas, h]./assum[:Efficiency, :Gas]).*assum[:EmissionFactor, :Gas] for r in REGION, h in HOUR)./(10^6)

        MaxEmission,
            Emission <= 13.9 #Mton CO2


        BatteryBalance[r in REGION, h in HOUR[1:end-1]],
            BatteryContent[r, h+1] <= BatteryContent[r, h] - Electricity[r, :Batteries, h]./assum[:Efficiency, :Batteries] + BatteryInput[r, h] #TODO: h-1 correct?

        BatteryInputMax[r in REGION, h in HOUR],
            BatteryInput[r, h] <= sum(Electricity[r,p,h] for p in PLANT) # can get input from batteries, but would be inefficient

        BatteryMax[r in REGION, h in HOUR],
            BatteryContent[r, h] <= InstalledCapacity[r, :Batteries]

        #Exercise 3
        TransmissionCapacityEquality[r in REGION, R in REGION],
            TransmissionCapacity[r, R] == TransmissionCapacity[R, r]

        TransmissionCapacityMax[r in REGION, R in REGION],
            TransmissionCapacity[r, R] <= maxcap[r, :Transmission]

            # Kolla så att blev rätt
        TransmissionInstalledCapacity[r in REGION],
            sum(TransmissionCapacity[r, R], for R in REGION) == InstalledCapacity[r, p]

        TransmissionMax[r in REGION, R in REGION, h in HOUR],
            Transmission[r, R, h] <= TransmissionCapacity[r, R]

        TransmissionProduction[r in REGION, h in HOUR], # transmission in
            sum(Transmission[r, R, h] for R in REGION) == Electricity[r, :Transmission, h]

    end #constraints

    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (; m, InstalledCapacity, Electricity, Emission, GeneratedElectricity, TransmissionCapacity)

end # buildmodel

function calculate_generation(input)

end # calculate_generation

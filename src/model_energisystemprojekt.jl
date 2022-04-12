"""
  Constructs and returns the energy system model.
"""

function buildmodel(input)

    println("\nBuilding model...")

    @unpack REGION, PLANT, PLANTFACT, HOUR, numregions, load, maxcap, assum, discountrate = input

    m = Model(Gurobi.Optimizer)

    @variables m begin
        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MWh/h
        Capacity[r in REGION, p in PLANT]                     >= 0        # MW
    end #variables


    #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(Capacity[r, p], maxcap[r, p])
    end

    # Defining costs of the system
    Runningcost = AxisArray(Array{Float64}(undef, length(REGION)),REGION) # init
    Investmentcost = AxisArray(Array{Float64}(undef, length(REGION)),REGION) # init
    Systemcost = AxisArray(Array{Float64}(undef, length(REGION)),REGION) # init

    function a(d,p)
        1-(1/(1+d)^assum[:Lifetime,p])
    end
    for r in REGION
        #print(Capacity[r,:Wind].*assum[:InvestmentCost,:Wind].*discountrate./a(discountrate,:Wind))

        Investmentcost[r] = sum(Capacity[r,p] for p in PLANT) # doesn't work, wrong type

        Investmentcost[r] = sum(Capacity[r,p].*assum[:InvestmentCost,p].*discountrate./a(discountrate,p) for p in PLANT)
        Fuelcost[r] = sum(Electricity[r,Gas,h].*assum[:FuelCost,:Gas] for h in HOUR)
    end
    for r in REGION # when r used many times external for loop needed
        print(Electricity[:DE,:Wind,100])

        # seems to not work as Electricity[r,p,h] is not a normal float element
        Runningcost[r] = sum(Electricity[r,p,h].*assum[:RunCost,p] for p in PLANT, h in HOUR)
    end
    for r in REGION
        Systemcost[r] = Runningcost[r] + Investmentcost[r] + Fuelcost[r]
    end


    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        Systemcost[r in REGION],
            Systemcost[r] >= 0 # sum of all annualized costs

    end #constraints

    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (; m, Capacity)

end # buildmodel

function calculate_generation(input)

end # calculate_generation

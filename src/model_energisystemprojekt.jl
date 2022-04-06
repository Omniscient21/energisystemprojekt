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

    RunningCost[r in REGION] = sum(Electricity[r,p,h].*assumptions[p,RunCost] for p in PLANT, h in HOUR)
    function a(p)
        1-(1/(1+r)^assumptions[p,Lifetime])
    end
    InvestmentCost[r in REGION] = sum(Capacity[r,p].*assumptions[p,InvestmentCost].*discountrate/a(p) for p in PLANT)

    Systemcost[r in REGION] = Runningcost[r] + Investmentcost[r]

    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        SystemCost[r in REGION],
            Systemcost[r] >= 0 # sum of all annualized costs

    end #constraints

    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (; m, Capacity)

end # buildmodel

function calculate_generation(input)


end # calculate_generation

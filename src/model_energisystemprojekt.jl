
function buildmodel(input)

    println("\nBuilding model...")

    @unpack REGION, PLANT, HOUR, numregions, load, maxcap = input

    m = Model(Gurobi.Optimizer)

    @variables m begin

        Electricity[r in REGION, p in PLANT, h in HOUR]       >= 0        # MWh/h
        Capacity[r in REGION, p in PLANT]                     >= 0        # MW

    end #variables


    #Variable bounds
    for r in REGION, p in PLANT
        set_upper_bound(Capacity[r, p], maxcap[r, p])
    end


    @constraints m begin
        Generation[r in REGION, p in PLANT, h in HOUR],
            Electricity[r, p, h] <= Capacity[r, p] # * capacity factor

        SystemCost[r in REGION],
            Systemcost[r] >= 0 # sum of all annualized costs

    end #constraints


    @objective m Min begin
        sum(Systemcost[r] for r in REGION)
    end # objective

    return (;m, Capacity)

end # buildmodel

function calculate_generation(input)


end # calculate_generation

function calculate_electricity(input)


end # calculate_electricity

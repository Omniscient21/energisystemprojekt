# I den här filen bygger ni modellen. Notera att det är skrivet som en modul, dvs ett paket.
# Så när ni ska använda det, så skriver ni Using energisystemprojekt i er REPL, då får ni ut det ni
# exporterat. Se rad 9.

module energisystemprojekt

using JuMP, AxisArrays, Gurobi, UnPack

export runmodel

include("input_energisystemprojekt.jl")
include("model_energisystemprojekt.jl")

function runmodel()

    input = read_input()

    model = buildmodel(input)

    @unpack m, Capacity = model

    println("\nSolving model...")

    status = optimize!(m)


    if termination_status(m) == MOI.OPTIMAL
        println("\nSolve status: Optimal")
    elseif termination_status(m) == MOI.TIME_LIMIT && has_values(m)
        println("\nSolve status: Reached the time-limit")
    else
        error("The model was not solved correctly.")
    end

    Cost_result = objective_value(m)/1000000 # M€
    Capacity_result = value.(Capacity)


    println("Cost (M€): ", Cost_result)

    nothing

end #runmodel

end # module

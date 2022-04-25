"""
  Manages all input data for the energy stystem.
"""

using CSV, DataFrames, AxisArrays

function read_input()
    println("\nReading Input Data...")
    folder = dirname(@__FILE__)

    #Sets
    REGION = [:DE, :SE, :DK]
    PLANT = [:Wind, :PV, :Gas, :Hydro, :Batteries, :Transmission] #, :Nuclear]
    PLANTFACT = [:InvestmentCost, :RunCost, :FuelCost, :Lifetime, :Efficiency, :EmissionFactor]
    HOUR = 1:8760

    #Parameters
    numregions = length(REGION)
    numhours = length(HOUR)
    numplants = length(PLANT)

    timeseries = CSV.read("src/TimeSeries.csv", DataFrame)

    wind_cf = AxisArray(ones(numregions, numhours), REGION, HOUR) # cf = capacity fraction
    pv_cf = AxisArray(ones(numregions, numhours), REGION, HOUR)

    load = AxisArray(zeros(numregions, numhours), REGION, HOUR)

    for r in REGION
        wind_cf[r, :]=timeseries[:, "Wind_"*"$r"]             # 0-1, share of installed cap
        pv_cf[r, :]=timeseries[:, "PV_"*"$r"]                 # 0-1, share of installed cap

        load[r, :]=timeseries[:, "Load_"*"$r"]                # [MWh]
    end

    cf = AxisArray(ones(numregions, numplants, numhours), REGION, PLANT, HOUR) # cf = capacity fraction, 1 for most plants
    for p in [:Wind, :PV], r in REGION
        cf[r, p, :] = timeseries[:, "$p"*"_"*"$r"] # 0-1, share of installed cap
    end

    hydro_inflow = AxisArray(zeros(numhours), HOUR)
    hydro_inflow = timeseries[:, "Hydro_inflow"]./(10^6) # MWh->TWh

    myinf = 1e8
    maxcaptable = [ # GW
            # PLANT       DE             SE              DK
            :Wind         180            280              90 # TODO: change back into correct values
            :PV           460             75              60
            :Gas          myinf          myinf           myinf
            :Hydro        0               14               0
            :Batteries    myinf          myinf           myinf
            :Transmission myinf          myinf           myinf
            #:Nuclear      myinf          myinf           myinf
    ]

    assumptions = [ #   €/kW      €/MWh       €/MWh_f     yrs     (MWh_e/MWh_f)  tonCO2/MWh_f
        # Plant      Inv. cost   Run. cost  Fuel cost   Lifetime    Efficiency  Em. factor
        :Wind           1100        0.1         0           25          1           0
        :PV             600         0.1         0           25          1           0
        :Gas            550         2           22          30          0.4         0.202 # TODO: check fuel cost
        :Hydro          0           0.1         0           80          1           0
        :Batteries      150         0.1         0           10          0.9         0
        :Transmission   2500        0           0           50          0.98        0
        #:Nuclear        7700        4           3.2         50          0.4         0
    ] #TODO: check asterisks

    maxcap = AxisArray(maxcaptable[:,2:end]'.*1000, REGION, PLANT)      # GW->MW
    assum = AxisArray(assumptions[:,2:end]', PLANTFACT, PLANT)          # ' used for matrix transpose

    discountrate=0.05

    return (; REGION, PLANT, PLANTFACT, HOUR, numregions, numplants, load, maxcap, assum, discountrate, cf, hydro_inflow)

end # read_input

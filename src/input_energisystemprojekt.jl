"""
  Manages all input data for the energy stystem.
"""

using CSV, DataFrames, AxisArrays

function read_input()
    println("\nReading Input Data...")
    folder = dirname(@__FILE__)

    #Sets
    REGION = [:DE, :SE, :DK]
    PLANT = [:Wind, :PV, :Gas, :Hydro] #:Batteries, :Transmission, :Nuclear]
    PLANTFACT = [:InvestmentCost, :RunCost, :FuelCost, :Lifetime, :Efficiency, :EmissionFactor]
    HOUR = 1:8760

    #Parameters
    numregions = length(REGION)
    numhours = length(HOUR)

    timeseries = CSV.read("src/TimeSeries.csv", DataFrame)

    wind_cf = AxisArray(ones(numregions, numhours), REGION, HOUR) # cf = capacity fraction
    pv_cf = AxisArray(ones(numregions, numhours), REGION, HOUR)

    load = AxisArray(zeros(numregions, numhours), REGION, HOUR)

    for r in REGION
        wind_cf[r, :]=timeseries[:, "Wind_"*"$r"]             # 0-1, share of installed cap
        pv_cf[r, :]=timeseries[:, "PV_"*"$r"]                 # 0-1, share of installed cap

        load[r, :]=timeseries[:, "Load_"*"$r"]                # [MWh]
    end

    hydro_inflow = AxisArray(zeros(numhours), HOUR) # TODO: only for SE?
    hydro_inflow = timeseries[:, "Hydro_inflow"]

    #println(pv_cf[:, 1:3])

    myinf = 1e8
    maxcaptable = [ # GW
            # PLANT       DE             SE              DK
            :Wind         280            90              180
            :PV           75             60              460
            :Gas          myinf          myinf           myinf
            :Hydro        0              14              0
            #:Batteries    myinf          myinf           myinf
            #:Transmission myinf          myinf           myinf
            #:Nuclear      myinf          myinf           myinf
    ]

    assumptions = [
        # Plant      Inv. cost   Run. cost  Fuel cost   Lifetime    Efficiency  Em. factor
        :Wind           1100        0.1         0           25          0           0
        :PV             600         0.1         0           25          0           0
        :Gas            550         2           22          30          0.4         0.202
        :Hydro          0           0.1         0           80          0           0
        #:Batteries      150         0.1         0           10          0.9         0
        #:Transmission   2500        0           0           50          0.98        0
        #:Nuclear        7700        4           3.2         50          0.4         0
    ] #TODO: check asterisks

    maxcap = AxisArray(maxcaptable[:,2:end]'.*1000, REGION, PLANT)      # MW
    assum = AxisArray(assumptions[:,2:end]', PLANTFACT, PLANT)          # ' used for matrix transpose

    discountrate=0.05

    return (; REGION, PLANT, PLANTFACT, HOUR, numregions, load, maxcap, assum, discountrate, wind_cf, pv_cf, hydro_inflow)

end # read_input

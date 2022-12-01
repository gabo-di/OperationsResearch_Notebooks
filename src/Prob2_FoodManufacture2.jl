using JuMP
using SCIP#SCIP #GLPK


#oil types
Vegetable_oils = ["veg1", "veg2"]
Non_vegetable_oils = ["oil1", "oil2", "oil3"]
Oils = vcat(Vegetable_oils, Non_vegetable_oils)

#months
Months = ["January","February","March","April","May","June"]

#prices oil month  pound/ton
prices_mat = [110 120 130 110 115;
              130 130 110 90 115;
              110 140 130 100 95;
              120 110 120 120 125;
              100 120 150 110 105;
              90 100 140 80 135]
              
prices = Containers.DenseAxisArray(prices_mat, Months, Oils)

#product sell cost pound/ton
sell = 150

#max amount of refined vegetable oils per month in tons
refine_max_vegoil = 200

#max amount of refined nonvegetable oils per month in tons
refine_max_nonvegoil = 250

#max amount possible to store per raw oil in tons
store_max_rawoil = 1000

#initial amount of each oil in tons
store_initial = 500

#final amount of each oil in tons
store_final = 500

#storage cost of raw oils in pound/ton 
store_cost_rawoil = 5

#hardness of final oil mix
hardness_min_oilmix = 3
hardness_max_oilmix = 6

#max number of oils in bending
n_oils_max = 3

#minumum amount of tons of oil to use
use_oil_min = 20


#hardness of each raw oil
hardness_oils_array = [8.8 6.1 2.0 4.2 5.0]
hardness_oils = Dict([(oil,hard) for (oil, hard) in zip(Oils,hardness_oils_array)])

#optimizer to use
use_optimizer = SCIP.Optimizer
model = Model(use_optimizer)

#decision variables Amount of each oil to buy (refine, store) each month
@variable(model, raw_oilmonth[m in Months, oil in Oils] )
@variable(model, refined_oilmonth[m in Months, oil in Oils] )
@variable(model, stored_oilmonth_prev[m in Months, oil in Oils] )
@variable(model, stored_oilmonth_post[m in Months, oil in Oils] )
#decision variable if we use each oil each month
@variable(model, using_oilmonth[m in Months, oil in Oils], Bin )


#storing oil constraint
@constraint(model, [oil in Oils], stored_oilmonth_prev[Months[1], oil] == store_initial )
@constraint(model, [oil in Oils], stored_oilmonth_post[Months[end], oil] == store_final )
@constraint(model, [month in Months, oil in Oils], store_max_rawoil >= stored_oilmonth_prev[month, oil] >= 0 )
@constraint(model, [month in Months, oil in Oils], store_max_rawoil >= stored_oilmonth_post[month, oil] >= 0 )

#raw oil constraint
@constraint(model, [month in Months, oil in Oils], raw_oilmonth[month, oil] >= 0)

#refined oil constraint
@constraint(model, [month in Months, oil in Oils], refined_oilmonth[month, oil] >= 0)
@constraint(model, [month in Months], sum( refined_oilmonth[month,oil] for oil in Vegetable_oils) <= refine_max_vegoil)
@constraint(model, [month in Months], sum( refined_oilmonth[month,oil]  for oil in Non_vegetable_oils) <= refine_max_nonvegoil)

#Material conservation 
@constraint(model, [month in Months, oil in Oils], stored_oilmonth_post[month, oil] - raw_oilmonth[month, oil] - stored_oilmonth_prev[month, oil] + refined_oilmonth[month, oil]  == 0)
@constraint(model, [ii in 1:size(Months)[1]-1, oil in Oils], stored_oilmonth_prev[Months[ii+1], oil] == stored_oilmonth_post[Months[ii], oil] )

#blending constraint
@constraint(model, [month in Months], sum( refined_oilmonth[month,oil]*hardness_oils[oil] for oil in Oils ) <= hardness_max_oilmix*sum(refined_oilmonth[month,oil] for oil in Oils) )
@constraint(model, [month in Months], sum( refined_oilmonth[month,oil]*hardness_oils[oil] for oil in Oils ) >= hardness_min_oilmix*sum(refined_oilmonth[month,oil] for oil in Oils) )

#indicator constraints
@constraint(model, [month in Months, oil in Oils], refined_oilmonth[month,oil] - store_max_rawoil*using_oilmonth[month,oil] <= 0 ) 

#food never made up of more than some quantity of oils
@constraint(model, [month in Months], sum(using_oilmonth[month,oil] for oil in Oils) <= n_oils_max )

#if an oil is used at least some quantity must be used
@constraint(model, [month in Months, oil in Oils], refined_oilmonth[month,oil] >= use_oil_min*using_oilmonth[month,oil] )

#if either vec1 or veg2 are used, then oil3 also
@constraint(model, [month in Months], using_oilmonth[month,"oil3"] - using_oilmonth[month,"veg1"]>=0 )
@constraint(model, [month in Months], using_oilmonth[month,"oil3"] - using_oilmonth[month,"veg2"]>=0 )


#objective
@objective(model, Max,  sum( sell*refined_oilmonth[month,oil] - store_cost_rawoil*stored_oilmonth_post[month,oil] - prices[month,oil]*raw_oilmonth[month,oil] for month in Months, oil in Oils ) )



optimize!(model)
println("\nstored")
println( value.(stored_oilmonth_post))
println("\nraw")
println( value.(raw_oilmonth))
println("\nrefined")
println( value.(refined_oilmonth))
println("\nobjective")
println( objective_value(model)) 
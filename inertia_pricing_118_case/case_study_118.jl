## Instantiate Julia Environment
using Pkg
Pkg.activate(".")
# Pkg.instantiate()

# Load necessary packages
using DataFrames, CSV
using JuMP
using Ipopt
using Juniper
using Gurobi
using Cbc
using LinearAlgebra
using JLD

# Load case data
include("src/input.jl") # Type definitons and read-in functions
include("src/model_definitions.jl") # Model definiton
include("src/output.jl") # Postprocessing of solved model
include("src/tools.jl")
# Load case data
casedat = load("casedata/118bus.jld")
# Prepare Data
generators = casedat["generators"]
buses = casedat["buses"]
lines = casedat["lines"]
generatorlist = casedat["generatorlist"]

refbus = 1
loadscale = 1.10
mvaBase = 100
thermalLimitscale = 0.9
theta_u = 15

line_limits= [175 175 500 175 175 175 500 500 500 175 175 175 175 175 175 175 175 175 175 175 500 175 175 175 175 175 175 175 175 175 500 500 500 175 175 500 175 500 175 175 140 175 175 175 175 175 175 175 175 500 500 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 500 175 175 500 500 500 500 500 500 500 175 175 500 175 500 175 175 500 500 175 175 175 175 175 175 175 500 175 175 175 175 175 175 500 500 175 500 500 200 200 175 175 175 500 500 175 175 500 500 500 175 500 500 175 175 175 175 175 175 175 175 175 175 200 175 175 175 175 175 175 175 175 175 500 175 175 175 175 175 175 175 175 175 175 175 175 175 175 175 500 175 175 175 500 175 175 175]

for i in 1:length(lines)
    lines[i].u = 0.99*thermalLimitscale * line_limits[i]/mvaBase
end

# Create Wind Farms
wp = 1.25
factor_σ =  1.25*wp
voll = 10000

farms = Farm[]
push!(farms, Farm(70.0/100*wp,   factor_σ *7.0/100,  3,  1.5))
push!(farms, Farm(147.0/100*wp,  factor_σ *14.7/100, 8,  1.5))
push!(farms, Farm(102.0/100*wp,  factor_σ *10.2/100, 11, 1.5))
push!(farms, Farm(105.0/100*wp,  factor_σ *10.5/100, 20, 1.5))
push!(farms, Farm(113.0/100*wp,  factor_σ *11.3/100, 24, 1.5))
push!(farms, Farm(84.0/100*wp,   factor_σ *8.4/100,  26, 1.5))
push!(farms, Farm(59.0/100*wp,   factor_σ * 5.9/100, 31, 1.5))
push!(farms, Farm(250.0/100*wp,  factor_σ *25.0/100, 38, 1.5))
push!(farms, Farm(118.0/100*wp,  factor_σ *11.8/100, 43, 1.5))
push!(farms, Farm(76.0/100*wp,   factor_σ *7.6/100,  49, 1.5))
push!(farms, Farm(72.0/100*wp,   factor_σ *7.2/100,  53, 1.5))

for (i,f) in enumerate(farms)
    push!(buses[f.bus].farmids, i)
end

ES = load_ES("casedata")
wind_data, load_data, Hw = load_timeseries("casedata")
#load_data=load_data*1.2
#wind_data=wind_data*1.2
# Set up
settings = Dict(
    "k" => 0.9, # Efficiency of the ES;
    "μp" => 0.5, # Mean of wind power forecast error;
    "θp" => 1, # Standard deviation of wind power forecast error;
    "μh" => 0.5, # Mean of wind inertia forecast error;
    "θh" => 1, # Standard deviation of wind inertia forecast error;
    "ϵg" => 0.05, # Probability of generator's power limit violations;
    "ϵd" => 0.05, # Probability of ES's discharging power limit violations;
    "ϵc" => 0.05, # Probability of ES's charging power limit violations;
    "ϵh" => 0.05, # Probability of inertia limit violations;
    "Φg" => 1.65, # the (1-ϵ_g)-quantile of the standard normal distribution;
    "Φd" => 1.65, # the (1-ϵ_d)-quantile of the standard normal distribution;
    "Φc" => 1.65, # the (1-ϵ_c)-quantile of the standard normal distribution;
    "Φh" => 1.65, # the (1-ϵ_h)-quantile of the standard normal distribution;
    "Hmin" => 3.3, # unit: s
    "Δfmax" => 0.55, # unit: Hz
    "f0" => 60, # unit: Hz
    "RoCoFmax" => 0.5, # unit: Hz/s
    "E0" => 0.5, # unit: MWh
)
case=1
run_case_study(generators, ES, buses, lines, farms, wind_data, load_data, Hw, settings, case)

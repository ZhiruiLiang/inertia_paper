function build_model(G, ES, buses, lines, farms, wind, load, Hw, settings, case, fixed_U)

    n_buses = length(buses)
    n_lines = length(lines)
    n_generators = length(G)
    n_farms = length(farms)
    n_ESs = length(ES)

    println("bus: ", n_buses)
    println("line: ", n_lines)
    println("gen: ", n_generators)
    println("farm: ", n_farms)
    println("ES: ", n_ESs)

    # Get and prepare settings
    k = settings["k"]
    μp = settings["μp"]
    θp = settings["θp"]
    μh = settings["μh"]
    θh = settings["θh"]
    ϵg = settings["ϵg"]
    ϵd = settings["ϵd"]
    ϵc = settings["ϵc"]
    ϵh = settings["ϵh"]
    Φg = settings["Φg"]
    Φd = settings["Φd"]
    Φc = settings["Φc"]
    Φh = settings["Φh"]
    Hmin = settings["Hmin"]
    Δfmax = settings["Δfmax"]
    f0 = settings["f0"]
    RoCoFmax = settings["RoCoFmax"]
    E0 = settings["E0"]
    Hg=zeros(1,54)
    for i in 1:10
        Hg[i]=3.5
    end
    for i in 11:35
        Hg[i]=4
    end
    for i in 36:54
        Hg[i]=5
    end

    t_list = collect(1:24) # List with timesteps 1...24
    t_list2 = collect(2:24)
    bus_list = collect(1:n_buses)
    line_list = collect(1:n_lines)
    G_list = collect(1:n_generators)
    ES_list = collect(1:n_ESs)
    wind_list = collect(1:n_farms)
    Ssys=sum(generators[i].Pgmax for i in G_list) + sum(ES[j].Pdmax for j in ES_list) + sum(farms[k].Pwmax for k in wind_list)

    if fixed_U == []
        m = Model(Gurobi.Optimizer)
        set_optimizer_attribute(m, "NonConvex", 2)
        #set_optimizer_attribute(m, "OptimalityTol", 0.01)
        @variable(m, u[G_list,t_list], Bin)
    else
        u = fixed_U
        m = Model(Ipopt.Optimizer)
    end

    # Define Variables
    @variable(m, Pg[G_list,t_list] >= 0)
    @variable(m, Pd[ES_list,t_list] >= 0)
    @variable(m, Pc[ES_list,t_list] >= 0)
    @variable(m, E[ES_list,t_list] >= 0)
    @variable(m, 0 <= αg[G_list,t_list] <= 1)
    @variable(m, Cost_E[t_list] >= 0)
    @variable(m, Cost_G[t_list] >= 0)
    @variable(m, θ[bus_list,t_list])
    @variable(m, bus_out_power[bus_list,t_list])
    @variable(m, DC_flow[line_list,t_list])
    @variable(m, G_bus[bus_list,t_list])
    @variable(m, ESwind_bus[bus_list,t_list])
    if case == 6
        @variable(m, He[ES_list,t_list] >= 0)
        @variable(m, 0 <= αd[ES_list,t_list] <= 1)
        @variable(m, 0 <= αc[ES_list,t_list] <= 1)
    end

    # Add constraints
    # power constraints for G
    @constraint(m, μ_plus[i=G_list,t=t_list], Pg[i,t] <= u[i,t]*G[i].Pgmax - (Φg * θp - μp) * αg[i,t])
    @constraint(m, μ_minus[i=G_list,t=t_list], u[i,t]*G[i].Pgmin + (Φg * θp - μp) * αg[i,t] <= Pg[i,t])
    # DC power flow
    @constraint(m, [i=line_list, t=t_list], DC_flow[i,t] == (θ[lines[i].head,t]- θ[lines[i].tail,t])*lines[i].β)
    @constraint(m, ϑ_plus[i=line_list, t=t_list], DC_flow[i,t]<=lines[i].u)
    @constraint(m, ϑ_minus[i=line_list, t=t_list], -lines[i].u<= DC_flow[i,t])
    @constraint(m, [t=t_list], θ[2,t] == 0)

    for i in bus_list
        if buses[i].inlist ==[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == 0)
        elseif buses[i].inlist !=[] && buses[i].outlist ==[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist))
        elseif buses[i].inlist ==[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(DC_flow[k,t] for k in buses[i].outlist))
        elseif buses[i].inlist !=[] && buses[i].outlist !=[]
            @constraint(m, [i,t=t_list], bus_out_power[i,t] == sum(-DC_flow[k,t] for k in buses[i].inlist) + sum(DC_flow[k,t] for k in buses[i].outlist))
        end
    end

    for i in bus_list
        if buses[i].genids ==[] && buses[i].farmids ==[]
            @constraint(m, [i,t=t_list], G_bus[i,t]==0)
            @constraint(m, [i,t=t_list], ESwind_bus[i,t]==0)
        elseif buses[i].genids !=[] && buses[i].farmids ==[]
            @constraint(m, [i,t=t_list], G_bus[i,t]==sum(Pg[k,t] for k in buses[i].genids))
            @constraint(m, [i,t=t_list], ESwind_bus[i,t]==0)
        elseif buses[i].genids ==[] && buses[i].farmids !=[]
            @constraint(m, [i,t=t_list], G_bus[i,t]==0)
            @constraint(m, [i,t=t_list], ESwind_bus[i,t]==sum(Pd[k,t] - Pc[k,t] + wind[k,t] for k in buses[i].farmids))
        elseif buses[i].genids !=[] && buses[i].farmids !=[]
            @constraint(m, [i,t=t_list], G_bus[i,t]==sum(Pg[k,t] for k in buses[i].genids))
            @constraint(m, [i,t=t_list], ESwind_bus[i,t]==sum(Pd[k,t] - Pc[k,t] + wind[k,t] for k in buses[i].farmids))
        end
    end
    # Energy price
    @constraint(m, λ[i=bus_list,t=t_list], G_bus[i,t] + ESwind_bus[i,t] == load[i,t] + bus_out_power[i,t])

    if case == 1
        #power constraints for ES
        @constraint(m, ξ_plus[j=ES_list,t=t_list], Pd[j,t] <= ES[j].Pdmax)
        @constraint(m, ν_plus[j=ES_list,t=t_list], Pc[j,t] <= ES[j].Pcmax)
        # energy constraints for ES
        @constraint(m, β_plus[j=ES_list,t=t_list], E[j,t] <= ES[j].Emax)
        @constraint(m, β_minus[j=ES_list,t=t_list], E[j,t] >= ES[j].Emin)
        @constraint(m, [j=ES_list], E[j,1] == E0)
        @constraint(m, η[j=ES_list,t=t_list2], E[j,t] == E[j,t-1]+Pc[j,t]*k-Pd[j,t]/k)
        # participation factor limitation
        @constraint(m, ρ_g[i=G_list,t=t_list], αg[i,t]<=u[i,t])
        # Reserve price
        @constraint(m, γ[t=t_list], sum(αg[i,t] for i in G_list) == 1)
        # Inertia price
        @constraint(m, χ[t=t_list], sum(u[i,t]*Hg[i]*generators[i].Pgmax for i in G_list) >= Hmin*Ssys)
        # cost of G and ES
        @constraint(m, [t=t_list], Cost_E[t]==sum(ES[j].cd*Pd[j,t] + ES[j].cc*Pc[j,t] for j in ES_list))
        @constraint(m, [t=t_list], Cost_G[t]==sum(u[i,t]*G[i].pi1/100 + G[i].pi2/100 * (Pg[i,t] + μp * αg[i,t])
                    + G[i].pi3/100 * (Pg[i,t]^2 + 2*μp * αg[i,t] * Pg[i,t] + αg[i,t]^2 * (θp^2 + μp^2)) for i in G_list))

    elseif case == 6
        #power constraints for ES
        @constraint(m, ξ_plus[j=ES_list,t=t_list], Pd[j,t] + 2*He[j,t] * ES[j].Pdmax *RoCoFmax/f0 <= ES[j].Pdmax- (Φd * θp - μp) * αd[j,t] )
        @constraint(m, ν_plus[j=ES_list,t=t_list], Pc[j,t] + 2*He[j,t] * ES[j].Pdmax *RoCoFmax/f0 <= ES[j].Pcmax- (Φc * θp - μp) * αc[j,t] )
        # energy constraints for ES
        @constraint(m, β_plus[j=ES_list,t=t_list], E[j,t] <= ES[j].Emax-2*He[j,t] * Δfmax * ES[j].Pdmax /f0 *k)
        @constraint(m, β_minus[j=ES_list,t=t_list], E[j,t] >= ES[j].Emin-2*He[j,t] * Δfmax * ES[j].Pdmax /f0 /k)
        @constraint(m, [j=ES_list], E[j,1] == E0)
        @constraint(m, η[j=ES_list,t=t_list2], E[j,t] == E[j,t-1]+Pc[j,t]*k-Pd[j,t]/k)
        # synthetic inertia limitation
        @constraint(m, ε[j=ES_list,t=t_list], He[j,t] <= ES[j].Hemax)
        # participation factor limitation
        @constraint(m, ρ_g[i=G_list,t=t_list], αg[i,t]<=u[i,t])
        # Reserve price
        @constraint(m, γ[t=t_list], sum(αg[i,t] for i in G_list) + sum(αd[j,t] - αc[j,t] for j in ES_list) == 1)
        # Inertia price
        @constraint(m, χ[t=t_list], sum(u[i,t]*Hg[i]*generators[i].Pgmax for i in G_list)
                    + sum(He[j,t]*ES[j].Pdmax for j in ES_list) + sum((Hw[k,t]-(Φh*θh-μh))*farms[k].Pwmax for k in wind_list) >= Hmin*Ssys )
        # cost of G and ES
        @constraint(m, [t=t_list], Cost_E[t]==sum(ES[j].cd*(Pd[j,t]+μp*αd[j,t]) + ES[j].cc*(Pc[j,t]+μp*αc[j,t]) for j in ES_list))
        @constraint(m, [t=t_list], Cost_G[t]==sum(u[i,t]*G[i].pi1/100 + G[i].pi2/100 * (Pg[i,t] + μp * αg[i,t])
                    + G[i].pi3/100 * (Pg[i,t]^2 + 2*μp * αg[i,t] * Pg[i,t] + αg[i,t]^2 * (θp^2 + μp^2)) for i in G_list))
    end

    # Objective function
    @objective(m, Min,sum(Cost_G[t]+Cost_E[t] for t in t_list))

    return m, u
end

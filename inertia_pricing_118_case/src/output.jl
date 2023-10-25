function save_results(m,u,case)
    all_vars = all_variables(m)
    f = open("results/all_vars_case$case.txt", "w")
    for v in all_vars
        print(f, "$(v) = $(value(v))\n")
    end
    close(f)

    Energy_price = []
    Reserve_price = []
    Inertia_price = []
    Congestion_plus = []
    Congestion_minus = []
    t_list = collect(1:24)
    bus_list = collect(1:118)
    G_list = collect(1:54)
    line_list = collect(1:186)

    for t in t_list
        push!(Reserve_price, dual(m[:γ][t]))
        push!(Inertia_price, dual(m[:χ][t]))
    end

    for t in t_list
        for b in bus_list
            push!(Energy_price, dual(m[:λ][b,t]))
        end
    end

    for t in t_list
        for b in line_list
            push!(Congestion_plus, dual(m[:ϑ_plus][b,t]))
            push!(Congestion_minus, dual(m[:ϑ_minus][b,t]))
        end
    end

    f = open("results/Energy_price_case$case.txt", "w")
    for t in t_list
        for b in bus_list
            println(f, Energy_price[118*(t-1)+b])
        end
        print(f, "\n")
    end
    close(f)

    f = open("results/Reserve_price_case$case.txt", "w")
    for t in t_list
        println(f, Reserve_price[t])
    end
    close(f)

    f = open("results/Inertia_price_case$case.txt", "w")
    for t in t_list
        println(f, Inertia_price[t])
    end
    close(f)

    f = open("results/Congestion_plus_case$case.txt", "w")
    for t in t_list
        for b in line_list
            println(f, Congestion_plus[186*(t-1)+b])
        end
    end
    close(f)


    f = open("results/Congestion_minus_case$case.txt", "w")
    for t in t_list
        for b in line_list
            println(f, Congestion_minus[186*(t-1)+b])
        end
    end
    close(f)

    f = open("results/U_case$case.txt", "w")
    for t in t_list
        println(f, u[t])
    end
    close(f)

    f = open("results/U_case$case.txt", "w")
    for t in t_list
        for g in G_list
            println(f, u[54*(t-1)+g])
        end
        print(f, "\n")
    end
    close(f)

    return Energy_price, Reserve_price, Inertia_price
end

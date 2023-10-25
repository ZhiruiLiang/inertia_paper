# Build, run and process a single model run
function run_case_study(generators, ES, buses, lines, farms, wind_data, load_data, Hw, settings, case)
    fixed_U=[]
    println(">>>> Building MIQP Model")
    m, u = build_model(generators, ES, buses, lines, farms, wind_data, load_data, Hw, settings, case, fixed_U)
    println(">>>> Running MIQP Model")
    solvetime = @elapsed optimize!(m)
    status = termination_status(m)
    println(">>>> MIQP Model finished with status $status in $solvetime seconds")

    fixed_U=zeros(54,24)
    for i in 1:54
        for j in 1:24
            fixed_U[i,j]=value(u[i,j])
        end
    end

    println(">>>> Building QP Model")
    m, u = build_model(generators, ES, buses, lines, farms, wind_data, load_data, Hw, settings, case, fixed_U)
    println(">>>> Running QP Model")
    solvetime = @elapsed optimize!(m)
    status = termination_status(m)
    println(">>>> QP Model finished with status $status in $solvetime seconds")

    Energy_price, Reserve_price, Inertia_price = save_results(m,u,case)
    return
end

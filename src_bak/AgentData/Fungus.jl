module Fungus

## FUNGUS
function fungus_step!(fungus::Organism, model::ABM)
    fungus_begin!(fungus, model)

    @match fungus.status.status begin
        :spore    => fungus_act_spore!(fungus, model)
        :fruiting => fungus_act_fruiting!(fungus, model)
        _         => nothing
    end
end

function fungus_begin!(fungus::Organism, model::ABM)

    if fungus.status.status == :fruiting
        fungus.age += 1
    end 
            
    neighbors = filter(x -> x.type == :fungus, those_nearby(fungus, model)) |> length 
    if fungus.nrg.qty <= 0 || fungus.age > 10 || neighbors > 1
        # set_status_dead!(fungus, model)
        remove_agent!(fungus, model)
    end

end

function fungus_act_spore!(fungus::Organism, model::ABM)
    
    # spots = get_fungus_vacancies(fungus, model)
    dead = filter(x -> x.status.status == :dead, those_nearby(fungus, model)) 
    if !isempty(dead)
        # focus = rand(dead)
        # move_agent!(fungus, focus.pos, model)
        fungus.status = Status(:fruiting, 0)
    end

    if model.tox[fungus.pos...] > 1
        print("Changed status because of toxicity\n")
        fungus.status = Status(:fruiting, 0)
    end
end

function fungus_act_fruiting!(fungus, model)

    ## Detoxify surrounding soil
    fungus_detoxify!(fungus, model)
    
    ## DECAY
    fungus_decay!(fungus, model)
    
    if fungus.age == 10 && can_fruit(fungus, model)
        fungus_reproduce!(fungus, model)
    end
end

function fungus_detoxify!(fungus::Organism, model::ABM)
    
    for pos in union(nearby(fungus, model; r=rand((1,2,3))),[fungus.pos])
        qty = 1 + exp(-(model.tox[pos...])) |> inv
        model.tox[pos...] -= qty
        addt!(fungus.nrg, 1.0)
    end
end

function fungus_decay!(fungus::Organism, model::ABM)
    ## DECAY
    dead = filter(x -> x.status.status == :dead, those_nearby(fungus, model))
    for x in dead
        qty = min(x.mass, 1.0)
        addt!(fungus.nrg, qty)
        x.mass -= qty 
        x.mass <= 0 ? kill_agent!(x, model) : nothing
    end

#     for x in filter(x -> x.type != :fungus && x.status.status == :dead, those_nearby(fungus, model))
#         qty = min(x.mass, 1)
#         fungus.nrg.qty += qty 
#         x.mass         -= qty 
#         x.mass <= 0 ? kill_agent!(x, model) : nothing 
#     end
end

function fungus_reproduce!(fungus::Organism, model::ABM)
    subt!(fungus.nrg, 4.0)
   
    vacancies = get_fungus_vacancies(fungus, model)
    near = !isempty(vacancies) ? sample(vacancies, rand((2,3))) |> unique : []
    if !isempty(near)
        for spot in near 
            @pipe init_fungus(model, spot) |> add_agent_pos!(_, model) ## TODO; add stat changes
        end
    end

    # kill_agent!(fungus, model)
end       




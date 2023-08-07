module Grass

## INIT
function init_grass(model::ABM, pos::NTuple{2, Int64}; tox::Triple=Triple(1,5,0.5))
    id=nextid(model)
    stat=Status(:growing,id)
    null=Triple(0,0,0)
    repro=Quadruple(5,1,1,0)
    Grass(;id=id,pos=pos,status=stat,age=0,mass=0.5,repro=repro
          ,nrg=Triple(1,8,1),hyd=Triple(3,5,1),tox=tox,mot=null)
end

function get_grass_vacancies(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    close = @pipe filter(x -> x.status.status != :spore, those_nearby(agent, model)) .|> getfield(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots 
end

## GRASS METHODS
function grass_step!(grass::Organism, model::ABM)
    grass_begin!(grass, model)

    @match grass.status.status begin
        :growing   => grass_act_growing!(grass, model)
        :defending => grass_act_defending!(grass, model)
        _          => nothing
    end
end

function grass_begin!(grass::Organism, model::ABM)

    avg_tox = [model.tox[x...] for x in nearby(grass, model)] |> mean
    if avg_tox > grass.mass*10 
        remove_agent!(grass, model)
    end

    if is_grass_dead(grass, model)
        set_status_dead!(grass, model)
    else
        grass.age += 1
    end

    near = nearby(grass, model) 
    if can_grass_reproduce(grass, model)
        grass_reproduce!(grass, model)
    end
end

function grass_act_growing!(grass::Organism, model::ABM)
    new_hyd = 0.5 + model.water[grass.pos...]
    new_nrg = model.sunlight[grass.pos...]  

    ## grow
    addt!(grass.hyd, new_hyd)
    addt!(grass.nrg, new_nrg)
    
    grass.mass += new_hyd*new_nrg |> abs
    ## produce toxin
    if grass.hyd.qty > 1.0
        addt!(grass.tox, 1.0)
        subt!(grass.hyd, 1.0)
    end
   
    # 
    addt!(grass.nrg, model.sunlight[grass.pos...]) ## proximity to neighbors...or...sunlight?
end

function grass_act_defending!(grass::Organism, model::ABM)
    near = nearby(grass, model)
    c, r, u = 0, grass.tox.mod, near |> length |> inv 
    for pos in near 
        qty = u*(model.tox[pos...] ⊕ grass.tox.qty)(r)
        model.tox[pos...] += qty 
        c                 += qty
    end
    grass.tox.qty -= c
end

function grass_reproduce!(grass::Organism, model::ABM) ## TODO: change to NTuple
    
    viable = pos_grass_reproduce(grass, model)
    if !isempty(viable)
        # new grass stats
        toxin_bias = (rand() - 0.5*(grass.tox.qty/grass.tox.max))/200
        new_tox = Triple(0, grass.tox.max + toxin_bias, 1-grass.tox.mod*(1-rand()))
        # new pos 
        new_pos = @pipe viable |> sample(_, rand((1,2))) |> unique
        
        # use to remove spores
        # occupants = agents_in_position(new_pos, model)
        # [kill_agent!(x, model) for x in occupants]

        for p in new_pos
            @pipe init_grass(model, p; tox=new_tox) |> add_agent_pos!(_, model)
            subt!(grass.nrg, 1.0)
        end
    end
end       

## GRASS FUNCTIONS
function is_grass_dead(grass::Organism, model::ABM)
    grass.nrg.qty <= 0 || grass.age >= 100 || grass.mass <= 0
end

using Statistics

function can_grass_reproduce(grass::Organism, model::ABM)
    avg_tox = [model.tox[x...] for x in nearby(grass, model)] |> mean
    grass.age % 6 == 0 && grass.age > 5 && avg_tox < 1 && model.sunlight[grass.pos...] > 0.5
end

function pos_grass_reproduce(grass::Organism, model::ABM)
    return filter(pos -> model.tox[pos...] < 0.3, get_grass_vacancies(grass, model)) 
end


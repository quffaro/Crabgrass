module Crab

## CRAB METHODS
function crab_step!(crab::Organism, model::ABM)
    crab_begin!(crab, model)

    @match crab.status.status begin
        :walking => crab_act_walking!(crab, model)
        :eating  => crab_act_eating!(crab, model)
        _        => nothing
    end
end

function crab_begin!(crab::Organism, model::ABM)
    
    ## buffetted by toxins in soil    
    sum_tox = [model.tox[x...] for x in nearby(crab, model)] |> mean
    addt!(crab.tox, sum_tox*(1-crab.tox.mod))
    
    # dead?
    if crab.nrg.qty <= 0 || crab.tox.qty >= crab.tox.max + log(crab.mass)
        set_status_dead!(crab, model)
        print("Died from poisoning: ",crab.tox,"\n")
    end

    addt!(crab.nrg, model.sunlight[crab.pos...]/2)

    # dead?
    if is_crab_dead(crab, model)
        set_status_dead!(crab, model)
    else
        crab.age += 1
    end
    
    # reproduce?
    if can_crab_reproduce(crab, model)
        crab_reproduce!(crab, model)
    end
end

function crab_act_walking!(crab::Organism, model::ABM)
    food = filter(x -> x.type == :grass, those_nearby(crab, model))
    if !isempty(food)
        food_id = rand(food).id
        crab.status = Status(:eating, food_id)
        model[food_id].status = Status(:defending, crab.id)
    else
        crab.status.status = :walking
        crab_walk_carefully!(crab, model)
    end
end

function crab_walk_carefully!(crab::Organism, model::ABM)
    
    if crab.tox.qty >= crab.tox.qty*0.5
        dir = crab_orient(crab, model, :tox; f=inv)
        walk!(crab, dir, model; ifempty=false) 
        subt!(crab.nrg, 0.3*crab.mot.mod)
    else
        walk!(crab, rand, model)
        subt!(crab.nrg, 0.5*crab.mot.mod)
    end

    ## COST
end

function crab_reproduce!(crab::Organism, model::ABM)
    spots = get_vacancies(crab, model)
    if !isempty(spots)
        nrg, tox = crab_spawn_stats(crab, model)
        print("DEBUG: Crab reproduced\n")
        @pipe init_crab(model,rand(spots);nrg=nrg,tox=tox) |> add_agent_pos!(_, model) ## TODO; add stat changes
        crab.nrg.qty *= 0.5
        crab.repro.last = crab.age 
    end
end       

function crab_act_eating!(crab::Organism, model::ABM)
    ## TODO
    food = try model[crab.status.focus] catch; 0 end

    atk = 10 + log(crab.mass)

    if food == 0
        crab_set_walking!(crab, model)
    elseif food.nrg.qty < atk
        @pipe max(food.nrg.qty, 0.1) |> addt!(crab.nrg, _)
        remove_agent!(food, model)
        crab_set_walking!(crab, model)
    else
        addt!(crab.nrg, 4.0)
        subt!(food.nrg, atk)
        # mass
        food.mass -= atk
        crab.mass += 1
    end
end
## CRAB FUNCTIONS
function crab_set_walking!(crab::Organism, model::ABM)
    crab.status = Status(:walking, crab.id)
end

function is_crab_dead(crab, model)
    crab.status == :dead || crab.age > 80 || crab.nrg.qty <= 0
end

function can_crab_reproduce(crab::Organism, model::ABM)
    crab.age > 10 && crab.age - crab.last > 30 && crab.nrg.qty > 5 && model.sunlight[crab.pos...] < 0.7
end

function crab_spawn_stats(crab::Organism, model::ABM)
    # depletes the energy 
    new_nrg = Triple(crab.nrg.qty/2, crab.nrg.max + (rand() - 0.5)/10, crab.nrg.mod)
    # tox with mutation
    toxin_bias = (rand() - 0.5*(crab.tox.qty/crab.tox.max))/100
    
    new_tox = Triple(0, crab.tox.max + toxin_bias, 1-crab.tox.mod*(1-rand()))
    # new_mot = Triple(1, crab.mot.max + rand() - 0.5, crab.mot.mod + rand())
    return new_nrg, new_tox
end


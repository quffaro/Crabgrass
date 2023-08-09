import Pkg; Pkg.add(["CairoMakie","Plots","StructArrays","Match","Pipe","Parameters","Permutations","Suppressor"])

using Agents
using StructArrays, Match, Random, Pipe, SparseArrays, Parameters, StatsBase 
using Permutations

#############################################
## UTILITY
#############################################
xs <| f = [f(x) for x in xs] 
a ⊕ b = r -> a + r*(b-a)

## 
sqrtint(x) = convert(Int, ceil(sqrt(x)))

function init_sparray(dim, param)::Vector{NTuple{2, Int64}}
    return @pipe sprand(Float64, dim[1], dim[2], param) |> Tuple.(findall(!iszero, _))
end 

function sparseN(X::Int, Y::Int; vol::Int=9, nz::Int=sqrtint(X))
    sparse(rand(1:X, nz), rand(1:Y, nz), float(rand(1:vol, nz)), X, Y)
end

mutable struct Status
    action::Symbol
    focus::Int # TODO: Union(Int, Nothing)
end 

#############################################
## TRIPLE FUNCTION
#############################################
mutable struct Triple 
    qty::Float64
    max::Float64
    mod::Float64
end 

############################################
## TRIPLE METHODS
############################################
function addt(x::Triple, y::Float64)::Triple
    x.qty = min(x.qty + y, x.max)
    return x
end

function addt!(x::Triple, y::Float64)::Triple
    x.qty = min(x.qty + y, x.max)
    return x
end

function subt(x::Triple, y::Float64)::Triple
    x.qty = max(x.qty - y, 0)
    return x
end

function subt!(x::Triple, y::Float64)::Triple
    x.qty = max(x.qty - y, 0)
    return x
end


############################################
## ORGANISM
############################################
@agent Organism GridAgent{2} begin
    type::Symbol
    status::Status
    age::Int 
    mass::Float64
    energy::Triple
    toxicity::Triple
end

Crab(;id,pos,status,age,mass,energy,toxicity)=
Organism(id,pos,:crab,status,age,mass,energy,toxicity)
##
Grass(;id,pos,status,age,mass,energy,toxicity)= 
Organism(id,pos,:grass,status,age,mass,energy,toxicity)
##
Fungus(;id,pos,status,age,mass,energy,toxicity)=
Organism(id,pos,:fungus,status,age,mass,energy,toxicity) 


############################################
## ORGANISM METHODS
############################################

############################################
## ORGANISM FUNCTIONS
############################################

##
function init_crab(model::ABM,pos::NTuple{2,Int64}; tox::Triple=Triple(1,5,1))
    id=nextid(model)
    status=Status(:walking,id)
    Crab(;id=id,pos=pos,status=status,age=0,mass=5.0
         ,energy=Triple(1,8,1),toxicity=tox)
end

##
function init_grass(model::ABM,pos::NTuple{2,Int64}; tox::Triple=Triple(1,5,0.5))
    id=nextid(model)
    status=Status(:sessile,id)
    Grass(;id=id,pos=pos,status=status,age=0,mass=1.0
          ,energy=Triple(1,8,1),toxicity=tox)
end

##
function init_fungus(model::ABM,pos::NTuple{2,Int64}; tox::Triple=Triple(1,5,0.5))
    id=nextid(model)
    status=Status(:fruiting,id)
    Fungus(;id=id,pos=pos,status=status,age=0,mass=1.0
          ,energy=Triple(1,8,1),toxicity=tox)
end

##
function nearby(agent::Organism,model::ABM;r=1)::Vector{NTuple{2,Int}}
    return nearby_positions(agent.pos,model,r) |> collect
end 

##
function those_nearby(agent::Organism,model::ABM)::Vector{Organism}
    return nearby_agents(agent,model)|>collect
end
    
##
function nearby_grass(agent::Organism,model::ABM)::Vector{Organism}
    return filter(x->x.type==:grass,those_nearby(agent,model))
end

##
function get_vacancies(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    close = @pipe those_nearby(agent, model) .|> getfield(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots 
end


############################################
## STEP METHODS
############################################
function agent_step!(organism::Organism, model::ABM)
    organism.age += 1

    @match organism.type begin
        :crab => crab_step!(organism,model)
        :grass => grass_step!(organism,model)
        :fungus => fungus_step!(organism,model)
    end
end

############################################
## CRAB STEP
############################################
function crab_step!(crab::Organism, model::ABM)

    crab_begin!(crab,model)

    @match crab.status.action begin
        :walking => crab_act_walking!(crab,model)
        :eating => crab_act_eating!(crab,model)
        :dead => remove_agent!(crab, model)
        _ => nothing
    end 
end 

function crab_begin!(crab::Organism,model::ABM)
    crab.age += 1

    ## buffetted by toxins in soil
    crab_toxic!(crab,model)

    ## dead?
    if is_crab_dead(crab,model)
        # remove_agent!(crab, model)
        crab.status.action = :dead
        print("Crab ", crab.id, " died at age ", crab.age)
    end

    ## reproduce?
    if can_crab_reproduce(crab,model)
        crab_act_reproduce!(crab,model)
    end
end

function crab_set_walking!(crab::Organism)
    crab.status = Status(:walking, 0)
end

function crab_act_walking!(crab::Organism, model::ABM)
    food = nearby_grass(crab,model)
    if !isempty(food)
        food_id=rand(food).id
        crab.status=Status(:eating,food_id)
        model[food_id].status=Status(:defending,crab.id)
    else
        crab.status.action=:walking
        walk!(crab,rand,model)
        # crab_walk_carefully!(crab,model)
    end 
end

# function crab_walk_carefully!(crab::Organism, model::ABM)
#     walk!(crab,rand,model)
# end

function crab_act_eating!(crab::Organism, model::ABM)
    food = try model[crab.status.focus] catch; 0 end

    atk = crab.mass

    if food == 0
        crab_set_walking!(crab)
    elseif food.mass <= atk
        crab.mass += max(food.mass, 0.1)
        remove_agent!(food,model)
        crab_set_walking!(crab)
    else
        crab.mass += atk
        food.mass -= atk
    end
end

function crab_toxic!(crab::Organism, model::ABM)
    sum_tox = [model.tox[x...] for x in nearby(crab, model)] |> mean
    addt!(crab.toxicity, sum_tox*(1-crab.toxicity.mod))
end

function crab_act_reproduce!(crab::Organism, model::ABM)
    spots = get_vacancies(crab,model)
    if !isempty(spots)
        @pipe init_crab(model,rand(spots)) |> add_agent_pos!(_,model)
        crab.mass *= 0.25
    end
end

function is_crab_dead(crab::Organism, model::ABM)
    crab.mass <= 0 || crab.age > 50
end

function can_crab_reproduce(crab::Organism, model::ABM)
    crab.mass > 10 && crab.age > 5
end

############################################
## GRASS STEP
############################################
function grass_step!(grass::Organism, model::ABM) 
    grass_begin!(grass,model)

    near = nearby(grass, model)
    @match grass.status.action begin
        :sessile => grass_act_sessile!(grass,model)
        :defending => grass_act_defending!(grass,model)
        _ => nothing
    end
end

function grass_begin!(grass::Organism, model::ABM)
    grass.age += 1
 
    if is_grass_dead(grass, model)
        # set_status_dead!(grass, model)
        remove_agent!(grass,model)
    end

    near = nearby(grass, model) 
    if can_grass_reproduce(grass, model)
        grass_reproduce!(grass, model)
    end
end


function grass_act_sessile!(grass::Organism, model::ABM)
    new_hyd = 0.5 + model.water[grass.pos...]
    
    ## grow
    grass.mass += new_hyd |> abs
end

function grass_act_defending!(grass::Organism, model::ABM)
    near = nearby(grass, model)
    c, r, u = 0, grass.toxicity.mod, near |> length |> inv 
    for pos in near 
        qty = u*(model.tox[pos...] ⊕ grass.toxicity.qty)(r)
        model.tox[pos...] += qty 
        c                 += qty
    end
    grass.toxicity.qty -= c
end

function grass_reproduce!(grass::Organism, model::ABM) ## TODO: change to NTuple 
    viable = pos_grass_reproduce(grass, model)
    if !isempty(viable)
        # p = sample(viable, rand(1,2)) |> unique
        add_agent_pos!(init_grass(model, viable[1]), model)
        subt!(grass.energy, 1.0)
    end
        # if !isempty(viable)
    #     # new grass stats
    #     toxin_bias = (rand() - 0.5*(grass.toxicity.qty/grass.toxicity.max))/200
    #     new_tox = Triple(0, grass.toxicity.max + toxin_bias, 1-grass.toxicity.mod*(1-rand()))
    #     # new pos 
    #     new_pos = @pipe viable |> sample(_, rand((1,2))) |> unique
        
    #     # use to remove spores
    #     # occupants = agents_in_position(new_pos, model)
    #     # [kill_agent!(x, model) for x in occupants]

    #     for p in new_pos
    #         @pipe init_grass(model, p; tox=new_tox) |> add_agent_pos!(_, model)
    #         subt!(grass.energy, 1.0)
    #     end
    # end
end       


############################################
## GRASS FUNCTIONS
############################################
function is_grass_dead(grass::Organism, model::ABM)
    avg_tox = [model.tox[x...] for x in nearby(grass,model)] |> mean
    grass.mass <= 0 || 
    grass.age >= 100 || 
    avg_tox > grass.mass*10
end

function can_grass_reproduce(grass::Organism, model::ABM)
    avg_tox = [model.tox[x...] for x in nearby(grass, model)] |> mean
    grass.age % 33 == 0 && 
    avg_tox < 1 
    # && model.sunlight[grass.pos...] > 0.5
end

function pos_grass_reproduce(grass::Organism, model::ABM)
    return filter(pos -> model.tox[pos...] < 0.3, get_grass_vacancies(grass, model)) 
end

## TODO do we use this elsewhere
function get_grass_vacancies(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    close = @pipe filter(x -> x.status.action != :spore, those_nearby(agent, model)) .|> getfield(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots 
end

############################################
## FUNGUS FUNCTIONS
############################################
function fungus_step!(fungus::Organism, model::ABM)
    fungus_begin!(fungus, model)

    @match fungus.status.action begin
        :spore    => fungus_act_spore!(fungus, model)
        :fruiting => fungus_act_fruiting!(fungus, model)
        :dead     => remove_agent!(fungus,model)
        _         => nothing
    end
end

function fungus_begin!(fungus::Organism, model::ABM)
    # if fungus.status.action == :fruiting
    fungus.age += 1
    
    neighbors = filter(x -> x.type == :fungus, those_nearby(fungus, model)) |> length 
    if fungus.energy.qty <= 0 || fungus.age > 10 || neighbors > 1
        # set_status_dead!(fungus, model)
        # remove_agent!(fungus, model)
        fungus.status.action=:dead
    end
end

function fungus_act_spore!(fungus::Organism, model::ABM)
    # spots = get_fungus_vacancies(fungus, model)
    # dead = filter(x -> x.status.action == :dead, those_nearby(fungus, model)) 
    # if !isempty(dead)
    #     fungus.status = Status(:fruiting, 0)
    # end

    if model.tox[fungus.pos...] > 1
        print("Changed status because of toxicity\n")
        fungus.status = Status(:fruiting, 0)
    end
end

function fungus_act_fruiting!(fungus, model)

    ## detoxify surrounding soil
    fungus_detoxify!(fungus, model)
    
    ## decay
    # fungus_decay!(fungus, model)
   
    ## reproduce
    # if can_fungus_reproduce(fungus,model)
    #     fungus_reproduce!(fungus, model)
    # end
end

function fungus_detoxify!(fungus::Organism, model::ABM) 
    c = 0
    for pos in union(nearby(fungus, model; r=rand((1,2,3))),[fungus.pos])
        qty = 1 + exp(-(model.tox[pos...])) |> inv
        model.tox[pos...] -= qty
        # addt!(fungus.energy, 1.0)
        fungus.mass += qty
        c += qty
    end

    print("FUNGUS ", fungus.id, " REMOVED: ", c)
    if c > 10
        fungus_reproduce!(fungus,model)
        fungus.status.action = :dead
        # remove_agent!(fungus,model)
    end
end

# function fungus_decay!(fungus::Organism, model::ABM)
#     ## DECAY
#     dead = filter(x -> x.status.status == :dead, those_nearby(fungus, model))
#     for x in dead
#         qty = min(x.mass, 1.0)
#         addt!(fungus.energy, qty)
#         x.mass -= qty 
#         x.mass <= 0 ? kill_agent!(x, model) : nothing
#     end
# end

## TODO celluar automata behavior
function fungus_reproduce!(fungus::Organism, model::ABM)
    subt!(fungus.energy, 4.0)
   
    vacancies = get_fungus_vacancies(fungus, model)
    near = !isempty(vacancies) ? sample(vacancies, rand((2,3))) |> unique : []
    if !isempty(near)
        for spot in near 
            @pipe init_fungus(model, spot) |> add_agent_pos!(_, model) ## TODO; add stat changes
        end
    end
end
############################################
## FUNGUS FUNCTIONS
############################################
function can_fungus_reproduce(fungus::Organism, model::ABM)
    fungus.age == 10 && 
    filter(x -> x.status.action == :fruiting && 
           collect(fungus.pos) - collect(x.pos) .|> abs |> sum >= 2, those_nearby(fungus, model)) |> isempty
end

function get_fungus_vacancies(agent::Organism, model::ABM)
    close = @pipe those_nearby(agent, model) |> getfield.(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots
end

############################################
## MODEL FUNCTIONS
############################################
function initialize(; numcrabs = 1, dim = (40, 40))
    # space
    space = GridSpace(dim, periodic = false)
    # properties 
    prop = Dict(:tick          => 0,
                :grass_density => 0.1,
                :spore_density => 0.01,
                :water_density => 0.1,
                :water_ratio   => 0.5,
                :tox           => zeros(dim...),
                :water         => spzeros(dim...),
                :sunlight      => init_sunlight(dim[1])
               ) ## TODO
    # model 
    model = ABM(Organism, space, properties=prop)

    # generate terrain
    generate_terrain!(model; vol=60, steps=10)
   
    ## TODO: parameters in agent init functions should be more flexible

    # # populate grass 
    for pos in init_sparray(dim, model.grass_density) 
        add_agent_pos!(init_grass(model, pos), model)
    end

    # # populate fungus
    for pos in init_sparray(dim, model.spore_density) 
        add_agent_pos!(init_fungus(model, pos), model)
    end

    # # populate crabs
    for _ in 1:numcrabs 
        add_agent_single!(init_crab(model, (10,10)), model)
    end

    return model
end


############################################
## MODEL METHODS
############################################
function generate_terrain!(model::ABM; vol::Int=30, steps::Int=5)
    # dims = spacesize(model)
    model.water = sparseN(dim[1], dim[2], vol=15)
    # model.water = sparseN(model.spacesize...; vol=vol)
    for _ in 1:steps
        diffuse!(model, :water, model.water_ratio)
    end
    model.water = Matrix(model.water)
end

function diffuse!(model::ABM, property, ratio)
    wetness = Tuple.(findall(!iszero, model.water))
    for pos in wetness
        diffuse_pos!(model, pos, ratio)       
    end
end

function diffuse_pos!(model::ABM, pos::NTuple{2, Int64}, ratio::Float64)
    npos = filter(x -> model.water[x...] < model.water[pos...], nearby_positions(pos, model) |> collect)
    c, u = 0, 1/length(npos)
    ##rand(length(npos)) |> (y -> y/sum(y)) |> pairs## 1/length(npos)
    for n in npos
        q = u*(model.water[n...] ⊕ model.water[pos...])(ratio)
        if q > 0.005 ## TODO: tolerance
            model.water[n...] += q
            c                 += q
        end
    end
    model.water[pos...] -= c
end 

function model_step!(model::ABM)
    ##
    model.tick += 1
    # if model.tick % 4 == 0 
        # sunlight_step!(model)
    # end
    
    # DEBUG
    print("Model step: ",model.tick,"\n")
    print("NAgents: ",nagents(model),"\n")
end

# function sunlight_step!(model::ABM)
#     model.sunlight=model.sunlight[:,p]
# end

function init_sunlight(X)
    width = 1
    x = X/width
    return repeat(1:x, inner=(width, 1), outer=(1,X)) |> transpose |> m -> m.*pi/x .|> sin
end


############################################
## MAIN 
############################################
using CairoMakie

numcrabs = 35
dim=(60,60)

model = initialize(numcrabs=numcrabs,dim=dim)

# permutation vector
l=last(size(model.sunlight))
p=pushfirst!(Vector(1:l-1),l)

############################################
## PLOT
############################################
using CairoMakie, Plots
using Dates

function color(agent)
    @match agent.type begin
        :crab => if agent.mass >= 10
            :red
        else 
            :blue
        end
        :grass => :green
        :fungus => :orange
    end
end

function marker(agent)
    @match agent.type begin
        :crab => :rect
        :grass => '✿'
        :fungus => :circle
    end
end

function agent_size(agent)
    @match agent.type begin
        :crab   => 5
        :grass  => 5
        :fungus => @match agent.status.action begin 
            :spore => 3
            :fruiting => 3
        end
        _       => 0
    end 
end



heatarray = :tox
upperlimit = maximum(model.water)
heatkwargs = (colorrange = (0, upperlimit), colormap = :magma)

moviename = string("movie_",Dates.format(now(), "HHMM"),"_crabs_",numcrabs,".mp4") 
abmvideo(moviename,model,agent_step!,model_step!;
        framerate=4,frames=1000,title="Crabgrass!"
       ,ac=color,am=marker,as=agent_size
       ,heatarray,heatkwargs) 


# anim = @animate for i in 1:5
#      step!(model,agent_step!,model_step!,1)
#      abmplot(model)
# end

# gif(anim,moviename,fps=30)



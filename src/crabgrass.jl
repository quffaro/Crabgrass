import Pkg; Pkg.add(["CairoMakie","Plots","StructArrays", "Match", "Pipe", "Parameters","Permutations"])

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

mutable struct Status
    action::Symbol
    focus::Int # TODO: Union(Int, Nothing)
end 

############################################
## ORGANISM
############################################
@agent Organism GridAgent{2} begin
    type::Symbol
    status::Status
    age::Int 
    mass::Float64
end

Crab(;id,pos,status,age,mass)=Organism(id,pos,:crab,status,age,mass)

function init_crab(model::ABM,pos::NTuple{2,Int64})
    id=nextid(model)
    status=Status(:walking,id)
    Crab(;id=id,pos=pos,status=status,age=0,mass=5.0)
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
function nearby_grass(agent::Organism,model::ABM)::Vector{NTuple{2,Int}}
    return filter(x->x.type==:grass,those_nearby(agent,model))
end

############################################
## STEP METHODS
############################################
function agent_step!(organism::Organism, model::ABM)
    @match organism.type begin
        :crab => crab_step!(organism,model)
    end
end

############################################
## CRAB STEP
############################################
function crab_step!(crab::Organism, model::ABM)
    
    @match crab.status.action begin
        :walking => crab_act_walking!(crab,model)
        :eating => crab_act_eating!(crab,model)
        _ => nothing
    end 
end 

function crab_act_walking!(crab::Organism, model::ABM)
    food = nearby_grass(crab,model)
    if !isempty(food)
        food_id=rand(food).id
        crab.status=Status(:eating,food_id)
        model[food_id].status=Status(:defending,crab.id)
    else
        crab.status.action=:walking
        crab_walk_carefully!(crab,model)
    end 
end

function crab_walk_carefully!(crab::Organism, model::ABM)
    randomwalk!(crab,model,1)
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
                :spore_density => 0.1,
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
    # for pos in init_sparray(dim, model.grass_density) 
    #     add_agent_pos!(init_grass(model, pos), model)
    # end

    # # populate fungus
    # for pos in init_sparray(dim, model.spore_density) 
    #     add_agent_pos!(init_fungus(model, pos), model)
    # end

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
    # model.water = sparseN(dims[1], dims[2], vol=15)
    model.water = sparseN(spacesize(model)...; vol=vol)
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
##
############################################
movie = Any[];
heatarray = :tox
scatterkwargs = (colorrange = (0, 5), colormap = :magma)
for i in 1:5
     step!(model,agent_step!,model_step!,1)
     fig, ax, abmobs = abmplot(model)
end


using Dates
moviename = string("movie_",Dates.format(now(), "MMHH"),"_crabs_",numcrabs,".mp4") 

## looping

# abmvideo(
#          name, model, agent_step!, model_step!;
#          framerate=4, frames=frames,
#          title="Movie",
#          ac=color, am=marker, as=agent_size,
#          heatarray, heatkwargs
#         )

print(movie,"\n")



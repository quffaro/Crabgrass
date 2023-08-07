using Agents, Plots
using StructArrays, Match, Random, Pipe, SparseArrays, Parameters, StatsBase 
using Permutations



@agent Organism GridAgent{2} begin
    type::Symbol
    status::Status
    age::Int 
    mass::Float64
    repro::Quadruple
    nrg::Triple
    hyd::Triple
    tox::Triple
    mot::Triple
end 

Crab(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:crab,status,age,mass,repro,nrg,hyd,tox,mot)
Fungus(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:fungus,status,age,mass,repro,nrg,hyd,tox,mot)
Grass(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:grass,status,age,mass,repro,nrg,hyd,tox,mot)

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
                :sunlight      => init_sunlight(dim[1])) ## TODO
    # model 
    model = ABM(Organism, space, properties=prop)

    # generate terrain
    generate_soil_moisture!(model; vol=60, steps=10)
   
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

#####################################
## INITIALIZE
#####################################
using InteractiveDynamics, CairoMakie 

numcrabs = 35
dim=(60,60)

model = initialize(numcrabs=numcrabs,dim=dim)

# permutation vector
l=last(size(model.sunlight))
p=pushfirst!(Vector(1:l-1),l)

#
frames = 2000
heatarray = :tox
heatkwargs = (colorrange = (0, 5), colormap = :magma)

using Dates
name = string("movie_",Dates.format(now(), "MMHH"),"_crabs_",numcrabs,".mp4") 

abmvideo(
         name, model, agent_step!, model_step!;
         framerate=4, frames=frames,
         title="Movie",
         ac=color, am=marker, as=agent_size,
         heatarray, heatkwargs
        )

print(name,"\n")

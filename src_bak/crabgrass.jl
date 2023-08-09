using Agents, Plots
using StructArrays, Match, Random, Pipe, SparseArrays, Parameters, StatsBase 
using Permutations

using ["Utility.jl", "Types.jl", "Plotting.jl", "Model.jl"]

Crab(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:crab,status,age,mass,repro,nrg,hyd,tox,mot)
Fungus(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:fungus,status,age,mass,repro,nrg,hyd,tox,mot)
Grass(; id,pos,status,age,mass,repro,nrg,hyd,tox,mot) = Organism(id,pos,:grass,status,age,mass,repro,nrg,hyd,tox,mot)

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

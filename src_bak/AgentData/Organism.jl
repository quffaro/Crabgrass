module Organism

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


#############################################
## ORGANISM METHODS
#############################################
function set_status_dead!(organism::Organism, model::ABM)
    organism.status.status != :dead ? organism.status.status = :dead : nothing 
end


#############################################
## ORGANISM FUNCTIONS
#############################################

## TODO: I want a function for agents as well
function nearby(agent::Organism, model::ABM; r=1)::Vector{NTuple{2, Int}}
    return nearby_positions(agent.pos, model, r) |> collect 
end 

function those_nearby(agent::Organism, model::ABM)::Vector{Organism}
    return nearby_agents(agent, model) |> collect
end

function get_vacancies(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    close = @pipe those_nearby(agent, model) .|> getfield(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots 
end

function get_crab_vacancies(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    close = @pipe filter(x -> x.status.status != :spore, those_nearby(agent, model)) .|> getfield(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots 
end

function get_fungus_vacancies(agent::Organism, model::ABM)
    close = @pipe those_nearby(agent, model) |> getfield.(_, :pos)
    spots = @pipe nearby(agent, model) |> setdiff(_, close)
    return spots
end

function can_fruit(fungus::Organism, model::ABM)::Bool
    filter(x -> x.status.status == :fruiting && collect(fungus.pos) - collect(x.pos) .|> abs |> sum >= 2, those_nearby(fungus, model)) |> isempty
end

function get_opens(agent::Organism, model::ABM)::Vector{NTuple{2, Int}}
    near = nearby(agent, model)
    return filter(x -> getfield.(agents_in_position(x, model) |> collect, :pos) ∉ near, near)
end

function crab_orient(agent::Organism, model::ABM, property::Symbol; f=identity, is_dir::Bool=true)
    # function
    weights(xs) = [getproperty(model, property)[x...] for x in xs] .|> f
    # body
    near = get_crab_vacancies(agent, model) 
    result = if !isempty(near)
        @pipe near |> sample(_, Weights(weights(_))) |> (is_dir ? get_direction(agent.pos, _, model) : identity)
    else
        (0,0)
    end
        # return @pipe near |> (is_dir ? get_direction(agent.pos, _, model) : identity)
end

#############################################
## STEP METHODS
#############################################
function agent_step!(organism::Organism, model::ABM)
    @match organism.type begin
        :crab => crab_step!(organism, model)
        :grass => grass_step!(organism, model)
        :fungus => fungus_step!(organism, model)
    end 
end


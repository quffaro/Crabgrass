# MODEL METHODS
function generate_soil_moisture!(model::ABM; vol::Int=30, steps::Int=5)
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
    c, u = 0, 1/length(npos)##rand(length(npos)) |> (y -> y/sum(y)) |> pairs## 1/length(npos)
    for n in npos
        q = u*(model.water[n...] ⊕ model.water[pos...])(ratio)
        if q > 0.005 ## TODO: tolerance
            model.water[n...] += q
            c                 += q
        end
    end
    model.water[pos...] -= c
end 

## MODEL METHODS
function model_step!(model::ABM)
    ##
    model.tick += 1
    if model.tick % 4 == 0 
        sunlight_step!(model)
    end
    # DEBUG
    print("Model step: ",model.tick,"\n")
    print("NAgents: ",nagents(model),"\n")
end


function sunlight_step!(model::ABM)
    model.sunlight=model.sunlight[:,p]
end

## MODEL FUNCTIONS
function init_sunlight(X)
    width = 1
    x = X/width
    return repeat(1:x, inner=(width, 1), outer=(1,X)) |> transpose |> m -> m.*pi/x .|> sin
end


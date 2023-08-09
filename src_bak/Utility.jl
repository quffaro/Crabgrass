##########################
## INFIX
#########################3
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


function init_fungus(model::ABM, pos::NTuple{2, Int64}; tox::Triple=Triple(0,5,1))
    id=nextid(model)
    stat=Status(:spore,id)
    null=Triple(0,0,0)
    repro=Quadruple(6,3,3,0)
    Fungus(;id=id,pos=pos,status=stat,age=0,mass=0.0,repro=repro
           ,nrg=Triple(3,5,1),hyd=Triple(3,5,1),tox=tox,mot=null)
end 

function init_crab(model::ABM, pos::NTuple{2, Int64}; nrg::Triple=Triple(20,40,1), tox::Triple=Triple(0,20,0.5), mot::Triple=Triple(0,0,0.5))
    id=nextid(model)
    stat=Status(:walking,id)
    repro=Quadruple(7,5,3,0)
    Crab(;id=id,pos=pos,status=stat,age=0,mass=5.0,repro=repro
         ,nrg=nrg,hyd=Triple(8,16,1),tox=tox,mot=mot)
end


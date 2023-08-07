mutable struct Triple 
    qty::Float64
    max::Float64
    mod::Float64
end 

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

mutable struct Quadruple
    mtur::Int
    freq::Int
    cost::Int
    last::Int
end

mutable struct Status
    status::Symbol
    focus::Int # TODO: Union(Int, Nothing)
end 


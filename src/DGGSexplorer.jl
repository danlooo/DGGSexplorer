module DGGSexplorer

using DGGS
using Oxygen
using OteraEngine
using HTTP
using DimensionalData
using JSON3
using ColorSchemes
using FileIO
using ColorTypes
using ImageCore
using Makie
using Extents

DGGSMakie = Base.get_extension(DGGS, :DGGSMakie)

include("plot.jl")
include("webserver.jl")

export serve
end

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

include("plot.jl")
include("webserver.jl")

export serve
end

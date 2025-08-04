using Pkg
Pkg.activate("/home/dloos/prj/DGGS.jl/etc")

using DGGS
using DGGSexplorer
using YAXArrays
using Zarr

collections = Dict(
    "sentinel-2-l2a" => open_dggs_pyramid("data/dggs/sentinel-2-l2a.dggs.zarr"),
    "natural-earth" => open_dggs_pyramid("data/dggs/natural-earth.dggs.zarr"),
)

serve(collections; parallel=true)
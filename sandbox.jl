using Pkg
Pkg.activate("/home/dloos/prj/DGGS.jl/etc")

using Zarr
using DGGS
using DGGSexplorer

collections = Dict(
    "sentinel-2-l2a" => open_dggs_pyramid("data/dggs/sentinel-2-l2a.dggs.zarr"),
    "natural-earth" => open_dggs_pyramid("data/dggs/natural-earth.dggs.zarr"),
)

serve(collections; parallel=true)
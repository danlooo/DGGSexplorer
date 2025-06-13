using Pkg
Pkg.activate("/home/dloos/prj/DGGS.jl/etc")

using DGGS
using DGGSexplorer
using YAXArrays
using Zarr

collection = open_dggs_dataset("https://s3.bgc-jena.mpg.de:9000/dggs/natural-earth.dggs.zarr")

collections = Dict(
    "sentinel-2-l2a" => open_dggs_dataset("https://s3.bgc-jena.mpg.de:9000/dggs/sentinel-2-l2a.dggs.zarr"),
    "natural-earth" => open_dggs_dataset("https://s3.bgc-jena.mpg.de:9000/dggs/natural-earth.dggs.zarr"),
)
serve(collections)
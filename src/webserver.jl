
function request_root(collections)
    tmpl = joinpath(pkgdir(DGGSexplorer), "src", "html_templates", "root.html") |> Template
    tmpl(init=Dict(:title => "DGGSExplorer", :collectionIds => keys(collections)))
end

function request_collections_json(collections)
    collections_d = [Dict(
        :id => k,
        :crs => [
            "http://www.opengis.net/def/crs/EPSG/0/4326",
            v.dggsrs
        ],
        :extent => Dict(
            :spatial => Dict(
                :bbox => [v.bbox |> x -> [x.X[1], x.Y[1], x.X[2], x.Y[2]]]
            )
        )
    ) for (k, v) in collections]

    return Dict(
        :collections => collections_d
    )
end

function request_collections_html(collections)
    tmpl = joinpath(pkgdir(DGGSexplorer), "src", "html_templates", "collections.html") |> Template
    tmpl(init=Dict(:title => "collections", :collectionIds => keys(collections)))
end

function request_collections(req, collections)
    query_params = queryparams(req)
    f = get(query_params, "f", "json")
    if f == "html"
        return request_collections_html(collections)
    else
        return request_collections_json(collections)
    end
end

function request_collection(req, collectionId, collections, host_url)
    query_params = queryparams(req)
    f = get(query_params, "f", "json")
    collection = get(collections, collectionId, nothing)

    isnothing(collection) && error("Collection not found: $collectionId")

    if f == "html"
        @info host_url
        return request_collection_html(collectionId, collection, host_url)
    else
        return request_collection_json(collectionId, collection)
    end
end


function request_collection_html(collectionId, collection::DGGSPyramid, host)
    tmpl = joinpath(pkgdir(DGGSexplorer), "src", "html_templates", "collection.html") |> Template
    d = request_collection_json(collectionId, collection)
    d[:collection] = collection
    d[:host] = host
    d[:title] = d[:id] * " - DGGSexplorer"
    tmpl(init=d)
end

function request_collection_json(collectionId, collection::DGGSPyramid)
    return Dict(
        :id => collectionId,
        :url => "",
        :layers => collection |> first |> keys,
        :metadata => [(key=k, val=String(v)) for (k, v) in pairs(collection.metadata)],
        :size => join(collection |> last |> size, " x "),
        :geo_bbox => collection.bbox,
        :map_layer => intersect(collection |> first |> keys, (:Red, :Green, :Blue)) |> length == 3 ? ("Red,Green,Blue") : collection |> first |> keys |> first |> String
    )
end

function request_collection_zarr(req, collectionId, collections)
    # TODO: extract base path
    # TODO: throw error if not zarr
    dggs_p = collections[collectionId]
    dggs_a = dggs_p |> first |> x -> x.data |> values |> first

    pyramid_dir = try
        # CachedDiskArray
        dggs_a.data.parent.a.storage.folder
    catch
        # CFDiskArray
        dggs_a.data.a.storage.folder
    end

    file_path = joinpath(pyramid_dir, replace(req.target, "/collections/$(collectionId)/zarr/" => ""))
    try
        data = open(file_path, "r") do file
            read(file)
        end
        return HTTP.Response(200, data)
    catch
        HTTP.Response(404, "File $(file_path) not found")
    end
end

"""
Serve a collection of DGGSPyramids.

Caching individual DGGSArrays is highly recommended.
"""
function serve(
    collections::Dict{String,DS};
    host::String="http://127.0.0.1:8080",
    kwargs...
) where {DS<:DGGSPyramid}
    @get "/" req -> request_root(collections)
    @get "/collections" req -> request_collections(req, collections)
    @get "/collections/{collectionId}" (req, collectionId) -> request_collection(req, collectionId, collections, host)
    @get "/collections/{collectionId}/map" (req, collectionId) -> request_collection_map(req, collectionId, collections)
    @get "/collections/{collectionId}/coverage/tiles/WebMercatorQuad/{z}/{x}/{y}" (req, collectionId, z, x, y) -> request_tile(req, collectionId, collections, z, x, y)
    @get "/collections/{collectionId}/zarr/**" (req, collectionId) -> request_collection_zarr(req, collectionId, collections)
    #Makie.inline!(false)
    Oxygen.serve(; kwargs...)
end
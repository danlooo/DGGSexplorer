
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

function request_collection(req, collectionId, collections)
    query_params = queryparams(req)
    f = get(query_params, "f", "json")
    collection = get(collections, collectionId, nothing)

    isnothing(collection) && error("Collection not found: $collectionId")

    if f == "html"
        return request_collection_html(collectionId, collection)
    else
        return request_collection_json(collectionId, collection)
    end
end


function request_collection_html(collectionId, collection::DGGSPyramid)
    tmpl = joinpath(pkgdir(DGGSexplorer), "src", "html_templates", "collection.html") |> Template
    d = request_collection_json(collectionId, collection)
    d[:collection] = collection
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

"""
Serve a collection of DGGSPyramids.

Caching individual DGGSArrays is highly recommended.
"""
function serve(
    collections::Dict{String,DS};
    kwargs...
) where {DS<:DGGSPyramid}
    @get "/" req -> request_root(collections)
    @get "/collections" req -> request_collections(req, collections)
    @get "/collections/{collectionId}" (req, collectionId) -> request_collection(req, collectionId, collections)
    @get "/collections/{collectionId}/map" (req, collectionId) -> request_collection_map(req, collectionId, collections)
    @get "/collections/{collectionId}/coverage/tiles/WebMercatorQuad/{z}/{x}/{y}" (req, collectionId, z, x, y) -> request_tile(req, collectionId, collections, z, x, y)

    #Makie.inline!(false)
    Oxygen.serve(; kwargs...)
end
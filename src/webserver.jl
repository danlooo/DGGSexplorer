
function request_root(collections)
    tmpl = Template("/home/dloos/.julia/dev/DGGSexplorer/src/html_templates/root.html")
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
                :bbox => [DGGS.get_geo_bbox(v) |> x -> [x.X[1], x.Y[1], x.X[2], x.Y[2]]]
            )
        )
    ) for (k, v) in collections]

    return Dict(
        :collections => collections_d
    )
end

function request_collections_html(collections)
    tmpl = Template("/home/dloos/.julia/dev/DGGSexplorer/src/html_templates/collections.html")
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


function request_collection_html(collectionId, collection::DGGSDataset)
    tmpl = Template("/home/dloos/.julia/dev/DGGSexplorer/src/html_templates/collection.html")
    tmpl(init=Dict(
        :title => "DGGSExplorer",
        :collectionId => collectionId,
        :layers => keys(layers(collection)),
        :collection => collection,
    ))
end


function request_collection_json(collectionId, collection::DGGSDataset)
    return Dict(
        :id => collectionId
    )
end

function request_collection_map(req, collectionId, collections; scale_factor=1, offset=0)
    dggs_ds = collections[collectionId]
    layer = dggs_ds |> keys |> first
    dggs_array = getproperty(dggs_ds, layer)

    lon_dim = X(-180:180)
    lat_dim = Y(-90:90)
    matrix = to_geo_array(dggs_array, lon_dim, lat_dim) |> collect .|> x -> isnan(x) ? 1 : x

    # Normalize matrix to [0, 1]
    minval = minimum(matrix)
    maxval = maximum(matrix)
    norm_matrix = (matrix .- minval) ./ (maxval - minval + eps())
    norm_matrix = norm_matrix[1:length(lon_dim), length(lat_dim):-1:1]'

    img = colorview(RGB, reinterpret(RGB{Float32}, [get(ColorSchemes.viridis, v) for v in norm_matrix]))

    io = IOBuffer()
    save(FileIO.Stream(format"PNG", io), img)

    response_headers = [
        "Content-Type" => "image/png",
        # "cache-control" => "max-age=23117, stale-while-revalidate=604800, stale-if-error=604800"
    ]
    response = HTTP.Response(200, response_headers, io.data)
    return response

end

function serve(
    collections::Dict{String,DS};
    kwargs...
) where {DS<:DGGSDataset}
    @get "/" req -> request_root(collections)
    @get "/collections" req -> request_collections(req, collections)
    @get "/collections/{collectionId}" (req, collectionId) -> request_collection(req, collectionId, collections)
    @get "/collections/{collectionId}/map" (req, collectionId) -> request_collection_map(req, collectionId, collections)

    @get "/hello" function ()
        fig = heatmap(rand(50, 50))
        html(fig)
    end

    Makie.inline!(false)
    Oxygen.serve(; kwargs...)
end
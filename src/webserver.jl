
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
                :bbox => [DGGS.get_geo_bbox(v) |> x -> [x.X[1], x.Y[1], x.X[2], x.Y[2]]]
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


function request_collection_html(collectionId, collection::DGGSDataset)
    tmpl = joinpath(pkgdir(DGGSexplorer), "src", "html_templates", "collection.html") |> Template
    tmpl(init=Dict(
        :title => "DGGSExplorer",
        :collectionId => collectionId,
        :layers => keys(layers(collection)),
        :collection => collection,
        :collectionURL => try
            collection.data |> first |> a -> a.data.a.storage.parent.url
        catch
            ""
        end
    ))
end


function request_collection_json(collectionId, collection::DGGSDataset)
    return Dict(
        :id => collectionId,
        :url => try
            collection.data |> first |> a -> a.data.a.storage.parent.url
        catch
            ""
        end
    )
end

function get_geo_bbox(z, x, y)
    #@see https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames

    n = 2^z
    lon_min = x / n * 360.0 - 180.0
    lat_max = atan(sinh(π * (1 - 2 * y / n))) |> rad2deg

    lon_max = (x + 1) / n * 360.0 - 180.0
    lat_min = atan(sinh(π * (1 - 2 * (y + 1) / n))) |> rad2deg

    return Extent(X=(lon_min, lon_max), Y=(lat_min, lat_max))
end

function get_map(dggs_array::DGGSArray, lon_dim, lat_dim)
    matrix = to_geo_array(dggs_array, lon_dim, lat_dim) |> collect |> x -> replace!(x, missing => 1, NaN => 1)

    # Normalize matrix to [0, 1]
    minval = minimum(matrix)
    maxval = maximum(matrix)
    norm_matrix = (matrix .- minval) ./ (maxval - minval + eps())
    norm_matrix = norm_matrix[1:length(lon_dim), length(lat_dim):-1:1]'

    img = colorview(RGB, reinterpret(RGB{Float32}, [get(ColorSchemes.viridis, v) for v in norm_matrix]))
    return img
end

function request_tile(req, collectionId, collections, z, x, y)
    dggs_ds = collections[collectionId]
    layer = dggs_ds |> keys |> first
    dggs_array = getproperty(dggs_ds, layer)

    z = parse(Int, z)
    y = parse(Int, y)
    x = parse(Int, x)
    bbox = get_geo_bbox(z, x, y)
    lon_dim = range(bbox.X..., length=256)
    lat_dim = range(bbox.Y..., length=256)

    img = get_map(dggs_array, lon_dim, lat_dim)

    io = IOBuffer()
    save(FileIO.Stream(format"PNG", io), img)

    response_headers = [
        "Content-Type" => "image/png",
    ]
    response = HTTP.Response(200, response_headers, io.data)
    return response
end

function request_collection_map(req, collectionId, collections)
    dggs_ds = collections[collectionId]
    layer = dggs_ds |> keys |> first
    dggs_array = getproperty(dggs_ds, layer)

    geo_bbox = DGGS.get_geo_bbox(dggs_array)
    aspect_ratio = (geo_bbox.X[2] - geo_bbox.X[1]) / (geo_bbox.Y[2] - geo_bbox.Y[1])
    height = 400
    lon_dim = X(range(geo_bbox.X..., length=aspect_ratio * height |> round |> Int))
    lat_dim = Y(range(geo_bbox.Y..., length=height))
    img = get_map(dggs_array, lon_dim, lat_dim)

    io = IOBuffer()
    save(FileIO.Stream(format"PNG", io), img)

    response_headers = [
        "Content-Type" => "image/png",
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
    @get "/collections/{collectionId}/coverage/tiles/WebMercatorQuad/{z}/{x}/{y}" (req, collectionId, z, x, y) -> request_tile(req, collectionId, collections, z, x, y)

    Makie.inline!(false)
    Oxygen.serve(; kwargs...)
end
function get_geo_bbox(z, x, y)
    #@see https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames

    n = 2^z
    lon_min = x / n * 360.0 - 180.0
    lat_max = atan(sinh(π * (1 - 2 * y / n))) |> rad2deg

    lon_max = (x + 1) / n * 360.0 - 180.0
    lat_min = atan(sinh(π * (1 - 2 * (y + 1) / n))) |> rad2deg

    return Extent(X=(lon_min, lon_max), Y=(lat_min, lat_max))
end

function to_image(dggs_array::DGGSArray, lon_dim, lat_dim)
    matrix = to_geo_array(dggs_array, lon_dim, lat_dim) |> collect |> x -> replace!(x, missing => 1, NaN => 1)

    # Normalize matrix to [0, 1]
    minval = minimum(matrix)
    maxval = maximum(matrix)
    norm_matrix = (matrix .- minval) ./ (maxval - minval + eps())

    norm_matrix = norm_matrix[1:length(lon_dim), length(lat_dim):-1:1]'
    img = colorview(RGB, reinterpret(RGB{Float32}, [get(ColorSchemes.viridis, v) for v in norm_matrix]))
    return img
end

function to_image(dggs_ds::DGGSDataset, lon_dim, lat_dim)
    geo_ds = to_geo_dataset(dggs_ds, lon_dim, lat_dim)
    img = Matrix{RGB{Float64}}(undef, length(lon_dim), length(lat_dim))
    for i in CartesianIndices(img)
        r = geo_ds.Red[i] / 255 |> x -> ismissing(x) ? 1 : x |> x -> isnan(x) ? 1 : x
        g = geo_ds.Green[i] / 255 |> x -> ismissing(x) ? 1 : x |> x -> isnan(x) ? 1 : x
        b = geo_ds.Blue[i] / 255 |> x -> ismissing(x) ? 1 : x |> x -> isnan(x) ? 1 : x
        img[i] = RGB(r, g, b)
    end
    img = img[1:length(lon_dim), length(lat_dim):-1:1]'
    return img
end


function request_tile(req, collectionId, collections, z, x, y)
    z = parse(Int, z)
    y = parse(Int, y)
    x = parse(Int, x)
    bbox = get_geo_bbox(z, x, y)
    lon_dim = range(bbox.X..., length=256) |> X
    lat_dim = range(bbox.Y..., length=256) |> Y

    request_collection_map(req, collectionId, collections; lon_dim=lon_dim, lat_dim=lat_dim)
end

function request_collection_map(req, collectionId, collections; lon_dim=nothing, lat_dim=nothing)
    resolution = DGGSMakie.get_resolution(collections[collectionId], lon_dim, lat_dim)
    dggs_ds = collections[collectionId][resolution]

    subset = get(queryparams(req), "subset", "")
    if occursin("Layer(", subset)
        layer = match(r"Layer[(][^)]+[)]"ism, subset).match[7:end-1]
    else
        if intersect(keys(dggs_ds), (:Red, :Green, :Blue)) |> length == 3
            layer = "Red,Green,Blue"
        else
            layer = keys(dggs_ds)[1] |> String
        end
    end

    if isnothing(lon_dim) || isnothing(lat_dim)
        geo_bbox = dggs_ds.data[1].bbox
        aspect_ratio = (geo_bbox.X[2] - geo_bbox.X[1]) / (geo_bbox.Y[2] - geo_bbox.Y[1])
        height = 400
        lon_dim = X(range(geo_bbox.X..., length=aspect_ratio * height |> round |> Int))
        lat_dim = Y(range(geo_bbox.Y..., length=height))
    end

    if layer == "Red,Green,Blue"
        # filter not required bands
        dggs_ds = DGGSDataset(dggs_ds.Red, dggs_ds.Green, dggs_ds.Blue)
        img = to_image(dggs_ds, lon_dim, lat_dim)
    else
        dggs_array = getproperty(dggs_ds, Symbol(layer))
        img = to_image(dggs_array, lon_dim, lat_dim)
    end

    io = IOBuffer()
    save(FileIO.Stream(format"PNG", io), img)
    response_headers = [
        "Content-Type" => "image/png",
        "Access-Control-Allow-Origin" => "*",
    ]
    response = HTTP.Response(200, response_headers, io.data)
    return response
end
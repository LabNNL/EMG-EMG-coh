function idx = get_poi_indices(R)
    idx = [];
    try
        idx = R.POI.indices;
    catch
        idx = [];
    end
end
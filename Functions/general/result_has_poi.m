function tf = result_has_poi(R)
    tf = isfield(R, 'POI') && isfield(R.POI, 'has_poi') && R.POI.has_poi && isfield(R.POI, 'indices') && ~isempty(R.POI.indices);
end
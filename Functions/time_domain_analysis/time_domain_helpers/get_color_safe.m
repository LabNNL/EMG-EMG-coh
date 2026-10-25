function col = get_color_safe(colorStruct, fieldName, fallback)
    if isfield(colorStruct, fieldName)
        col = colorStruct.(fieldName);
    else
        col = fallback;
    end
end

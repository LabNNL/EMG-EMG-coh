function apply_boxchart_color(b, c)
    try, b.BoxFaceColor = c; end
    try, b.BoxEdgeColor = c; end
    try, b.MarkerColor = c; end
    try, b.WhiskerLineColor = c; end
    try, b.MedianLineColor = [0 0 0]; end
end
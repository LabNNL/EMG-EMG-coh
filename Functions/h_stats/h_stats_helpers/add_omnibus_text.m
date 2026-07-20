function add_omnibus_text(ax, txtLines)
    txt = strjoin(txtLines, '\n');
    text(ax, 0.02, 0.98, txt, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 10, 'BackgroundColor', 'w', 'Margin', 6);
end
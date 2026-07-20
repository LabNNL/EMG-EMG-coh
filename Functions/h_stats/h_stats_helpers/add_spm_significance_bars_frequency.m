function add_spm_significance_bars_frequency(ax, spmi, freqRef, varargin)

    p = inputParser;
    addParameter(p, 'y_frac', 0.85);
    addParameter(p, 'line_width', 2);
    addParameter(p, 'color', [0 0 0]);
    addParameter(p, 'show_p_text', false);
    addParameter(p, 'show_stars', true);
    addParameter(p, 'star_font_size', 11);
    parse(p, varargin{:});

    y_frac = p.Results.y_frac;
    lw = p.Results.line_width;
    col = p.Results.color;
    show_p_text = p.Results.show_p_text;
    show_stars = p.Results.show_stars;
    star_font_size = p.Results.star_font_size;

    fprintf('\n=== DEBUG add_spm_significance_bars_frequency ===\n');

    if isempty(spmi)
        fprintf('spmi is empty\n');
        return;
    end

    hold(ax, 'on');

    yl0 = ylim(ax);
    yr0 = yl0(2) - yl0(1);

    % Add small headroom only once for significance bars
    ylim(ax, [yl0(1), yl0(2) + 0.12 * yr0]);
    yl = ylim(ax);
    yr = yl(2) - yl(1);

    clusters = [];

    try
        if isprop(spmi, 'clusters')
            clusters = spmi.clusters;
            fprintf('Read clusters from property\n');
        elseif isfield(spmi, 'clusters')
            clusters = spmi.clusters;
            fprintf('Read clusters from field\n');
        else
            fprintf('No clusters property/field found\n');
            return;
        end
    catch ME
        fprintf('Failed to access clusters: %s\n', ME.message);
        return;
    end

    fprintf('numel(clusters) = %d\n', numel(clusters));

    if isempty(clusters)
        fprintf('No clusters to draw\n');
        return;
    end

    y = yl(1) + y_frac * yr;
    tick_h = 0.012 * yr;
    text_offset = 0.018 * yr;

    for i = 1:numel(clusters)

        if iscell(clusters)
            c = clusters{i};
        else
            c = clusters(i);
        end

        fprintf('\n--- Cluster %d ---\n', i);
        fprintf('class(c) = %s\n', class(c));

        endpoints = [];
        pval = NaN;

        % ---------- extract endpoints and p-value safely ----------
        if isobject(c)

            if isprop(c, 'endpoints')
                endpoints = c.endpoints;
            end

            if isprop(c, 'P')
                pval = c.P;
            elseif isprop(c, 'p')
                pval = c.p;
            end

        elseif isstruct(c)

            if isfield(c, 'endpoints')
                endpoints = c.endpoints;
            end

            if isfield(c, 'P')
                pval = c.P;
            elseif isfield(c, 'p')
                pval = c.p;
            end
        end

        fprintf('raw endpoints =\n');
        disp(endpoints);
        fprintf('freqRef(1) = %.3f | freqRef(end) = %.3f | n = %d\n', freqRef(1), freqRef(end), numel(freqRef));
        fprintf('pval = ');
        disp(pval);

        % ---------- skip invalid endpoints ----------
        if isempty(endpoints) || numel(endpoints) < 2 || any(isnan(endpoints(1:2)))
            fprintf('Skipping cluster: invalid endpoints\n');
            continue;
        end

        % ---------- skip invalid / NaN p-values ----------
        if isempty(pval) || ~isnumeric(pval) || any(isnan(pval(:)))
            fprintf('Skipping cluster: p-value is NaN or unavailable\n');
            continue;
        end

        pval = pval(1);

        % ---------- skip non-significant clusters if returned anyway ----------
        if pval > 0.05
            fprintf('Skipping cluster: p = %.4g > 0.05\n', pval);
            continue;
        end

        % ---------- convert cluster endpoints to frequency ----------
        x1 = interp1(1:numel(freqRef), freqRef, endpoints(1), 'linear', 'extrap');
        x2 = interp1(1:numel(freqRef), freqRef, endpoints(2), 'linear', 'extrap');

        % Keep inside visible frequency range
        x1 = max(min(x1, max(freqRef)), min(freqRef));
        x2 = max(min(x2, max(freqRef)), min(freqRef));

        xm = mean([x1 x2]);

        fprintf('converted x1 = %.3f | x2 = %.3f\n', x1, x2);
        fprintf('Mapped x1 = %.3f Hz | x2 = %.3f Hz\n', x1, x2);

        % ---------- draw bracket ----------
        plot(ax, [x1 x2], [y y], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

        plot(ax, [x1 x1], [y - tick_h, y + tick_h], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

        plot(ax, [x2 x2], [y - tick_h, y + tick_h], '-', 'Color', col, 'LineWidth', lw, 'HandleVisibility', 'off');

        % ---------- stars ----------
        if show_stars
            stars = p_to_stars(pval);
            fprintf('stars = %s\n', stars);

            if ~isempty(stars)
                text(ax, xm, y + text_offset, stars, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', col, 'FontWeight', 'bold', 'FontSize', star_font_size, 'Clipping', 'off');
            end
        end

        % ---------- optional p-text ----------
        if show_p_text
            text(ax, xm, y + text_offset, sprintf('p=%.3g', pval), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', col, 'FontSize', 9, 'Clipping', 'off');
        end
    end
end

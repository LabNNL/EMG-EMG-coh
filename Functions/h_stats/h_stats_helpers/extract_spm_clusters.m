function clusters = extract_spm_clusters(spmi, freqRef)

    clusters = struct('f1', {}, 'f2', {}, 'p', {});

    try
        if ~isfield(spmi, 'clusters') || isempty(spmi.clusters)
            return;
        end

        for i = 1:numel(spmi.clusters)
            c = spmi.clusters{i};

            % try common fields from spm1d objects
            idx = [];

            if isprop(c, 'endpoints')
                ep = c.endpoints;
                if numel(ep) == 2
                    f1 = interp1(1:numel(freqRef), freqRef, ep(1), 'linear', 'extrap');
                    f2 = interp1(1:numel(freqRef), freqRef, ep(2), 'linear', 'extrap');
                else
                    continue;
                end
            elseif isprop(c, 'indices')
                idx = c.indices;
                f1 = freqRef(min(idx));
                f2 = freqRef(max(idx));
            else
                continue;
            end

            p = NaN;
            if isprop(c, 'P')
                p = c.P;
            elseif isprop(c, 'p')
                p = c.p;
            end

            clusters(end+1).f1 = f1; %#ok<AGROW>
            clusters(end).f2 = f2;
            clusters(end).p = p;
        end
    catch
        clusters = struct('f1', {}, 'f2', {}, 'p', {});
    end
end
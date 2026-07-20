function [T_spec_subj, freqRef] = average_spectrum_legs(T_spec_row)

    [G, subject_u, age_u, cond_u, pair_u] = findgroups( T_spec_row.subject, T_spec_row.age_group, T_spec_row.condition, T_spec_row.pair_name);

    if iscell(T_spec_row.Freq)
        freqRef = T_spec_row.Freq{1};
    else
        freqRef = T_spec_row.Freq(1,:);
    end
    freqRef = freqRef(:)';

    specMean = splitapply(@mean_cell_spectra, T_spec_row.Spectrum, G);
    nLegs = splitapply(@numel, T_spec_row.leg, G);

    % force cell columns
    if ~iscell(specMean)
        tmp = cell(size(specMean,1),1);
        for i = 1:size(specMean,1)
            tmp{i} = specMean(i,:);
        end
        specMean = tmp;
    end

    freqCol = repmat({freqRef}, numel(subject_u), 1);

    T_spec_subj = table(subject_u, age_u, cond_u, pair_u, nLegs, freqCol, specMean, 'VariableNames', {'subject','age_group','condition','pair_name','n_legs_collapsed','Freq','Spectrum'});
end

function y = mean_cell_spectra(x)

    % x is a cell array of spectra for one subject x condition x pair
    specs = x;

    if isempty(specs)
        y = {[]};
        return;
    end

    % unwrap if needed
    for i = 1:numel(specs)
        if iscell(specs{i})
            specs{i} = specs{i}{1};
        end
        specs{i} = specs{i}(:)';
    end

    lens = cellfun(@numel, specs);

    % remove empty spectra
    valid = lens > 0;
    specs = specs(valid);
    lens = lens(valid);

    if isempty(specs)
        y = {[]};
        return;
    end

    % keep only the most common spectrum length
    uLens = unique(lens);
    counts = arrayfun(@(L) sum(lens == L), uLens);
    [~, imax] = max(counts);
    targetLen = uLens(imax);

    specs = specs(lens == targetLen);

    X = cat(1, specs{:});
    y = {mean(X, 1, 'omitnan')};
end
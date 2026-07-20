function T_age = average_spectrum_conditions(T)
%AVERAGE_SPECTRUM_CONDITIONS Collapse spectra across conditions.
%
% Input:
%   T = subject x condition x pair spectrum table, usually after leg averaging.
%
% Output:
%   T_age = subject x pair spectrum table.
%
% Purpose:
%   For age-group spectrum plots, avoid counting one participant multiple
%   times because they have several conditions.

    if isempty(T)
        T_age = T;
        return;
    end

    keyVars = {'subject','age_group','pair_name'};

    G = findgroups(T(:, keyVars));
    T_age = unique(T(:, keyVars), 'rows');

    T_age.Freq = cell(height(T_age), 1);
    T_age.Spectrum = cell(height(T_age), 1);
    T_age.n_conditions_collapsed = nan(height(T_age), 1);
    T_age.conditions_collapsed = strings(height(T_age), 1);

    for iG = 1:height(T_age)

        idx = (G == iG);

        % ----- reference frequency axis -----
        freq0 = unwrap_table_vector_entry(T.Freq, find(idx, 1, 'first'));
        freq0 = freq0(:)';

        % ----- stack spectra -----
        specs = cell(sum(idx), 1);
        rowsHere = find(idx);

        for ii = 1:numel(rowsHere)
            r = rowsHere(ii);
            s = unwrap_table_vector_entry(T.Spectrum, r);
            specs{ii} = s(:)';
        end

        % keep only spectra with the same width as freq0
        good = false(numel(specs), 1);
        for ii = 1:numel(specs)
            good(ii) = numel(specs{ii}) == numel(freq0);
        end

        specs = specs(good);

        if isempty(specs)
            T_age.Freq{iG} = freq0;
            T_age.Spectrum{iG} = nan(size(freq0));
        else
            X = vertcat(specs{:});
            T_age.Freq{iG} = freq0;
            T_age.Spectrum{iG} = mean(X, 1, 'omitnan');
        end

        condsHere = categories(removecats(T.condition(idx)));
        T_age.n_conditions_collapsed(iG) = numel(condsHere);
        T_age.conditions_collapsed(iG) = strjoin(string(condsHere), '+');
    end
end
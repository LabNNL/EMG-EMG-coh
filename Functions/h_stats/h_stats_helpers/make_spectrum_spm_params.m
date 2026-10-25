function P = make_spectrum_spm_params(HS)
%MAKE_SPECTRUM_SPM_PARAMS
% Centralized SPM/SnPM settings for all spectrum profile analyses.

    P = struct();

    if isfield(HS, 'use_nonparametric')
        P.use_nonparametric = HS.use_nonparametric;
    elseif isfield(HS, 'mixed_use_nonparametric')
        % Backward compatibility
        P.use_nonparametric = HS.mixed_use_nonparametric;
    else
        P.use_nonparametric = false;
    end

    if isfield(HS, 'spm_alpha') && ~isempty(HS.spm_alpha)
        P.alpha = HS.spm_alpha;
    else
        P.alpha = 0.05;
    end

    if isfield(HS, 'two_tailed') && ~isempty(HS.two_tailed)
        P.two_tailed = HS.two_tailed;
    else
        P.two_tailed = true;
    end

    if isfield(HS, 'nonparam_iterations') && ~isempty(HS.nonparam_iterations)
        P.nonparam_iterations = HS.nonparam_iterations;
    elseif isfield(HS, 'mixed_nonparam_iterations') && ~isempty(HS.mixed_nonparam_iterations)
        P.nonparam_iterations = HS.mixed_nonparam_iterations;
    else
        P.nonparam_iterations = 5000;
    end

    % Seed for the SnPM permutations, so a rerun gives the same p-values
    P.nonparam_seed = 0;
    if isfield(HS, 'nonparam_seed') && ~isempty(HS.nonparam_seed)
        P.nonparam_seed = HS.nonparam_seed;
    end
end

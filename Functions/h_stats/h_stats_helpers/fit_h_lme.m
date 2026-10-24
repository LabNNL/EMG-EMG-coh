function lme = fit_h_lme(T, formula, HC)
% Every stage-h mixed model is fitted here, so the coding of categorical
% predictors and the fit method are the same in every table and figure.
%   HC.lme.dummy_var_coding  'effects' (default): main effects are averaged over
%                            the other factor's levels; 'reference' makes the
%                            age term the slope in the first condition only
%   HC.lme.fit_method        'REML' (default) | 'ML'

    L = lme_settings(HC);
    lme = fitlme(T, formula, 'DummyVarCoding', L.dummy_var_coding, 'FitMethod', L.fit_method);
end

function L = lme_settings(HC)
    L = struct('dummy_var_coding', 'effects', 'fit_method', 'REML');
    if nargin >= 1 && isfield(HC, 'lme')
        for f = fieldnames(L)'
            if isfield(HC.lme, f{1}), L.(f{1}) = HC.lme.(f{1}); end
        end
    end
end

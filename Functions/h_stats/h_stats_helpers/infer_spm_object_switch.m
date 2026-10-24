function spmi = infer_spm_object_switch(spm, P, isTTest)
%INFER_SPM_OBJECT_SWITCH
% Centralized inference for SPM and SnPM objects.
%
% Its own file because three runners call it:
%   run_spm_age_on_spectrum, run_spm_condition_on_spectrum and
%   run_spm_mixed_age_condition_on_spectrum.
% It used to be a local function inside the mixed runner, which a local
% function's own file can see but the other two cannot, so those two always
% fell into their catch block and produced no inference at all.

    spmi = [];

    if isempty(spm)
        return;
    end

    alpha = P.alpha;

    if P.use_nonparametric

        nIter = P.nonparam_iterations;

        if isTTest
            try
                spmi = spm.inference(alpha, 'two_tailed', P.two_tailed, 'iterations', nIter);
            catch
                try
                    spmi = spm.inference(alpha, 'two_tailed', P.two_tailed);
                catch
                    spmi = spm.inference(alpha);
                end
            end
        else
            try
                spmi = spm.inference(alpha, 'iterations', nIter);
            catch
                spmi = spm.inference(alpha);
            end
        end

    else

        if isTTest
            spmi = spm.inference(alpha, 'two_tailed', P.two_tailed);
        else
            spmi = spm.inference(alpha);
        end
    end
end

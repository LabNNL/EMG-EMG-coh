function [TFR1_all, TFR2_all, Freq] = precompute_wavelets_for_trials(S1, S2, Args)

    nTrials = size(S1,2);

    [TFR1, period,~,~] = wavelet(S1(:,1), Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
    [TFR2, ~,~,~]      = wavelet(S2(:,1), Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);

    nFreq = size(TFR1,1);
    nTime = size(TFR1,2);

    TFR1_all = complex(zeros(nFreq, nTime, nTrials));
    TFR2_all = complex(zeros(nFreq, nTime, nTrials));

    TFR1_all(:,:,1) = TFR1;
    TFR2_all(:,:,1) = TFR2;

    for p = 2:nTrials
        [TFR1_all(:,:,p), ~,~,~] = wavelet(S1(:,p), Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
        [TFR2_all(:,:,p), ~,~,~] = wavelet(S2(:,p), Args.DT, Args.Pad, Args.DJ, Args.S0, Args.J1, Args.Mother, Args.Cycles);
    end

    Freq = 1 ./ period;
end
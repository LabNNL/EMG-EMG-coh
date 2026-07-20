function [wave, Time, Freq] = TimeFreqTransform(s1, Freq, Args, X_Interp)
%% Time-frequency transformation
n = length(s1) ;
T = n/Freq ;
Time = linspace(0,T,n) ;

% Compute time-frequency representation
[wave,period,~,~] = wavelet(s1,Args.DT,Args.Pad,Args.DJ,Args.S0,Args.J1,Args.Mother,Args.Cycles) ;

% Time frequency interpolation
if X_Interp~=1
	[X,Y]   = meshgrid((1:size(wave,2)),(1:size(wave,1))) ;
	[Xq,Yq] = meshgrid((1:size(wave,2)/X_Interp:size(wave,2)),(1:size(wave,1))) ;
	wave = interp2(X, Y, abs(wave).^2, Xq, Yq, 'spline') ;
else     
    wave = abs(wave).^2 ;    
end

Freq = 1./period ;




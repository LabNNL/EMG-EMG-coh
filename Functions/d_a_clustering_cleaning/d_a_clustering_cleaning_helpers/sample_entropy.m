function se = sample_entropy(x, m, r)
% SAMPLE_ENTROPY Compute Sample Entropy (SampEn) of a 1D signal.
%
%   se = sample_entropy(x, m, r)
%
%   Inputs:
%       x : vector (signal)
%       m : embedding dimension (typical: m = 2)
%       r : tolerance (e.g., r = 0.1*std(x) or 0.2*std(x))
%
%   Output:
%       se : sample entropy value (scalar)
%
%   Notes:
%       - Returns NaN if the signal is too short.
%       - Works on raw or rectified EMG.
%       - Uses Chebyshev (max-abs) distance between template vectors.

x = x(:);                % ensure column vector
N = length(x);
if N < m+2
    se = NaN;
    return;
end

% standard tolerance
r = r + eps;

% --- Build template vectors of length m ---
Xm = zeros(N-m, m);
for i = 1:m
    Xm(:,i) = x(i:N-m+i-1);
end

% --- Build template vectors of length m+1 ---
Xm1 = zeros(N-m-1, m+1);
for i = 1:m+1
    Xm1(:,i) = x(i:N-m+i-2);
end

% --- Compute pairwise Chebyshev distances (vectorized) ---
% distances for m
D_m = squareform(pdist(Xm, 'chebychev'));      % fast, vectorized
C_m = sum(sum(D_m <= r)) - (N-m);              % remove diagonal

% distances for m+1
D_m1 = squareform(pdist(Xm1, 'chebychev'));
C_m1 = sum(sum(D_m1 <= r)) - (N-m-1);

% --- SampEn ---
if C_m == 0
    se = NaN;
else
    se = -log( (C_m1 + eps) / (C_m + eps) );
end

end
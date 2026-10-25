function tf = spm_info_ok(spmInfo)
%SPM_INFO_OK  True when an SPM runner actually produced an inference.
%
%   tf = spm_info_ok(spmInfo)
%
% The run_spm_*_on_spectrum runners never throw: on failure they return a
% struct with ok = false and an empty spmi. Callers that only check whether
% the struct exists cannot tell a real null result from a test that never
% ran, so use this before claiming on a figure that an SPM was performed.

tf = ~isempty(spmInfo) ...
    && isstruct(spmInfo) ...
    && (~isfield(spmInfo, 'ok') || spmInfo.ok) ...
    && isfield(spmInfo, 'spmi') ...
    && ~isempty(spmInfo.spmi);
end

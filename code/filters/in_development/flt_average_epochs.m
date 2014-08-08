function signal = flt_average_epochs(varargin)
% comments...
% Multiepoch trials?

    if ~exp_beginfun('filter'); return; end;
    
    declare_properties(...
        'name', 'AverageEpochs', ...
        'depends', 'set_makepos', ...   % TODO
        'follows', {'flt_fourier'}, ... % TODO
        'independent_channels',true, 'independent_trials',false);
    
    % Steps. 
    % Example with StimulusPerTrial = 15, EpochsToAverage=5,
    % StimulusCodes from 1 to 12 (P300 speller rows and columns):
    % 
    %   1. Cut signal into epochs. Check in depends and follows that only
    %   signal processing filters that handle epoched data follows, and
    %   only continous signal filters precedes.
    %
    %   2. Take the first 15 epochs with stimulus code equal to 1 = A
    %
    %   3. Make the waveform average with the first 5 elements from A.
    %      The rest will be discarded: From the original epochs, 
    %      the first one will contain the average waveform; the remaining 
    %      10 will be deleted.
    %
    %   4. Repeat for stimulus 2 to 15. These will complete the average for
    %      the first trial. 
    %   
    %   5. Repeat for all trials (each trial is considered to be made of a
    %   repetition of StimulusPerTrial epoch of each stimulus).
    %
    % TODO: See how to include target markers
    
end
function signal = flt_average_epochs(varargin)
% Average signals corresponding to a same stimulus and trial.
% Signal = flt_average_epochs(Signal, StimulusPerTrial, EpochsPerTrial, EpochsToAverage)
%
% In:
%   Signal          : Epoched EEGLAB data structure.
%
%   StimulusPerTrial: Number of repetitions of a same stimulus that makes a
%                     trial. The default value is 15.
%
%   EpochsPerTrial  : Number of epochs that belong to a same trial.
%                     TODO! no queda claro este parametro
%
%   EpochsToAverage : Number of epochs to take into consideration from 
%                     each trial when averaging. Must be less or equal than
%                     StimulusPerTrial. If not specified, this argument
%                     will be equal to StimulusPerTrial.
%
% Out:
%   Signal          : Signal with averaged epochs.
%    
%
% The filter receives an epoched signal and outputs a signal with less 
% epochs than the original one: each new epoch will consist of an average 
% of some other epochs taken from the input signal, all of them  belonging 
% to a same stimulus (as defined in StimulusCodes).
%
% Unlike the EEGLAB data structure, this filter does not consider that 
% one trial corresponds to one epoch. Instead, we will consider a trial to
% be made out of a certain number of contiguos epochs. The argument 
% StimulusPerTrial indicates after how many repetitions of a same stimulus 
% (i.e. one epoch in the original signal) a new trial begins. For example, 
% when used in the P300Speller[1], a value of StimulusPerTrial = 15 means 
% that the first 15 appearences of a stimulus (for example, the stimulus 
% corresponding to the flashing of the first row) correspond to a same 
% letter the user intends to spell; the next group of 15 appearences 
% corresponds to the second letter, and so on. A trial is made out of all
% the stimulus presented in order to retrieve one single letter.
%
% All the stimulus that appear on a same trial must have the same number of
% repetitions.
%
% NOTE: For now, the code expects each trial to have all stimulus present, 
% each repeated StimulusPerTrial number of times. 
%
% The new signal will contain only one epoch for every trial and stimulus
% (in the previous example, it would have one epoch for every 15
% consecutive epochs belonging to a same stimulus). The parameter
% EpochsToAverage specifies, for one stimulus, how many of the epochs that 
% belong to a same trial will actually be used for averaging. Only the 
% first EpochsToAverage epochs will be averaged and thus transformed into 
% one single epoch; the rest of the epochs will be discarded. 
% EpochsToAverage is allowed to be less than StimulusPerTrial in order for
% researchers to test which is the least ammount of epochs needed for 
% averaging,  withouth the need to perform several recording sessions.
%
% Note that the new epochs will have the same markers as the original ones:
% each average is done only among epochs with the same event type.
% 
% VER   set.epoch.type ---> 0 y 1
%       set.epoch.codes --> 1 a 12

%
% Example
% =======
%
% This example illustrates how to use this filter on a P300Speller session. 
% 
% There are two markers for every posible row (1 to 6) or column (7 to 12) 
% flashing. The markers are divided into two groups: those that are target
% markers (finishing with 'Y') and those which are not:
%
% >> markers = {{'1Y','2Y','3Y','4Y','5Y','6Y','7Y','8Y','9Y','10Y','11Y','12Y'},
%               {'1N','2N','3N','4N','5N','6N','7N','8N','9N','10N','11N','12N'}};
% 
% Markers with the same stimulus are considered
% >> stim = {{'1Y', '1N'}, {'2Y', '2N'}, {'3Y', '3N'}, {'4Y', '4N'}, {'5Y', '5N'},
%            {'6Y', '6N'}, {'7Y', '7N'}, {'8Y', '8N'}, {'9Y', '9N'}, {'10Y', '10N'},
%            {'11Y', '11N'}, {'12Y', '12N'} };
%
% >> signal = set_targetmarkers('Signal', signal, 'EventTypes', markers);
% >> signal = flt_average_epochs('Signal', signal, 'StimulusCodes', stim, 'StimulusPerTrial', 15, 'EpochsToAverage', 10);
%
% References
% ==========


if ~exp_beginfun('filter'); return; end;

% --------------------
% Arguments Definition
% --------------------

% Declare that this filter requires epoched data
declare_properties(...
    'name', 'AverageEpochs', ...
    'depends', 'set_makepos', ...       % Require epoched data
    'depends', 'set_targetmarkers', ... % Require markers to be already specified
    'independent_channels',true);
    %'independent_trials',false,...     % TODO (not sure)
    %'follows', {'flt_fourier'}, ...    % TODO (not sure)

% Input arguments declaration
arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg({'stimulus','StimulusCodes'}, [], [], ...
        ['Stimulus Codes. Cell array of events considered to be stimulus. Each element on this array can be ' ...
        'either a string, or an array cell of strings. In the latter case, this means that all the strings ' ...
        'grouped into one array actually belong to a same stimulus. If not specified, the function will ' ...
        'search for event type definitions on the EEGLAB data structure.']),...
    arg({'stim_per_trial','StimulusPerTrial'}, 15, [1 Inf], ...
        'Stimulus Per Trial. Number of repetitions of a same stimulus inside a trial.'),...
    arg({'epochs_per_trial','EpochsPerTrial'}, [], [1 Inf], ...
        'Epochs Per Trial. Number of consecutive epochs that make one single trial.'),...
    arg({'epochs2avg','EpochsToAverage'}, [], [1 Inf], ...
        'Epochs to average. Number of epochs from a same trial and stimulus to use when averaging. Must be less or equal than StimulusPerTrial. By default, this argument will be equal to StimulusPerTrial.'));
        
% If EpochsToAverage was not specified, make it equal to StimulusPerTrial
if isempty(epochs2avg)
   epochs2avg = stim_per_trial;
end

% If EpochsPerTrial was not specified, make it equal to the number of
% unique events, multiplied by StimulusPerTrial
stimulus = unique({signal.event.type});
totalStims = length(stimulus);

if isempty(epochs_per_trial)    
    epochs_per_trial = numStim * stim_per_trial;
end

% -----------
% Validations
% -----------

% Validate that the required fields are present.
%utl_check_fields(signal,{'event','epoch','srate','pnts'},'signal','signal');
utl_check_fields(signal,{'event','epoch','data'},'signal','signal');

% Check that the trial size fits
% 
% if mod(totalEpochs, epochs_per_trial) ~= 0
%    error('Invalid Signal. All stimulus should be present on each trial.'); 
% end

% ----------------
% Signal Averaging
% ----------------

totalEpochs = length(signal.epoch);
% 
% if mod(totalEpochs, epochs_per_trial) ~= 0
%    error('Invalid Signal. All stimulus should be present on each trial.'); 
% end

totalTrials = totalEpochs / epochs_per_trial;

% This matrix will say, for each trial and stimulus, the index where the
% stimulus first appeared. The rest of the appearences of that stimulus 
% within that trial will be averaged and then deleted; the result of the
% average will be saved in the position of the first appearence.
stimFirstApp = zeros(totalTrials, totalStims);

% TODO: this could be done using pop_rejepoch?

% Loop through each "trial"
for trial = 1:totalTrials
    % Loop through each epoch inside the trial and average.
    trial_start = (trial - 1) * epochs_per_trial + 1;
    trial_end = trial_start + epochs_per_trial - 1;
    
    %trial_stims = {signal.epoch(trial_start:trial_end).type};
    
    for numEpoch = trial_start:trial_end
       
        % If this is the first time that we see this stimulus, save it's
        % position and continue.
        currStim = signal.epoch(numEpoch).type;
        numStim = find(strcmp(currStim, stimulus));
        
        if stimFirstApp(trial, numStim) == 0
            stimFirstApp(trial, numStim) = numEpoch;
           continue; 
        end
        
        % If not, add its signal to the average
        epochWithAvg = stimFirstApp(trial, numStim);
        epochSignal = signal.data(:,:,numEpoch);
        signal.data(:,:,epochWithAvg) = signal.data(:,:,epochWithAvg) + epochSignal;
        
    end
end

% Discard information about epochs that don't contain averages.
remaining_trials = stimFirstApp(:);
remaining_trials(remaining_trials == 0) = [];

signal.data = signal.data(:, :, remaining_trials);
signal.trials = length(remaining_trials);
signal.event = signal.event(remaining_trials);
signal.urevent = signal.urevent(remaining_trials);
signal.epoch = signal.epoch(remaining_trials);

% Divide each remaining epoch by the number of epochs per trial
signal.data = signal.data / epochs_per_trial;

exp_endfun;
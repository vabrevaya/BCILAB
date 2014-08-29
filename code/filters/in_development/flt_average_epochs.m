function signal = flt_average_epochs(varargin)
% Average signals corresponding to a same stimulus and trial.
% Signal = flt_average_epochs(Signal, StimulusCodes, StimulusPerTrial, EpochsToAverage)
%
% In:
%   Signal          : Epoched EEGLAB data structure.
%
%   StimulusCodes   : Cell array of events considered to be 'stimulus'. Each
%                     element on this array can be either a string, or an
%                     array cell of strings. In the latter case, this means
%                     that all the strings grouped into one array actually
%                     belong to a same stimulus (for example, the event type 
%                     '1-TARGET' and the event type '1-NON-TARGET' both 
%                     belong to the stimulus 1.
%                     If not specified, the function will search for event
%                     type definitions on the EEGLAB data structure.
%
%   StimulusPerTrial: Number of repetitions of a same stimulus that makes a
%                     trial. The default value is 15.
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
% The filter receives an epoched signal, and outputs a signal with less 
% epochs than the original one: each new epoch will consist of an average 
% of a certain number of epochs from the input signal, all of them 
% belonging to a same stimulus (as defined in StimulusCodes).
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
% The new signal will contain only one epoch for every trial and stimulus
% (in the previous example, it would have one epoch for every 15
% consecutive epochs belonging to a same stimulus). The parameter
% EpochsToAverage specifies, for one stimulus, how many of the epochs that 
% belong to a same trial will actually be used for averaging. Only the 
% first EpochsToAverage epochs will be averaged and thus transformed into 
% one single epoch; the rest of the epochs that appear on that same trial
% will be discarded. EpochsToAverage is allowed to be less than 
% StimulusPerTrial in order to allow researchers to test which is the 
% least ammount of epochs needed for averaging,  withouth the need to 
% perform several recording sessions.
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
% >> stim = {{'1Y', '1N'}, {'2Y', '2N'}, {'3Y', '3N'}, {'4Y', '4N'}, {'5Y', '5N'}
%            {'6Y', '6N'}, {'7Y', '7N'}, {'8Y', '8N'}, {'9Y', '9N'}, {'10Y', '10N'}
%            {'11Y', '11N'}, {'12Y', '12N'} };
%
% >> eeg = flt_average_epochs('Signal', eeg, 'StimulusCodes', stim, 'StimulusPerTrial', 15, 'EpochsToAverage', 10);
% FALTAN MARKERS
%
% References
% ==========


%The EEGLAB data structures contains event types defined as follows:
%       - The stimulus type contains a number between 1 and 12, followed by
%         the letter 'Y' or 'N'. For example, one stimulus could be '12Y'
%       - Numbers 1 to 6 indicate that a row was flashed, and which one.
%       - Numbers 7 to 12 indicate that a column was flashed, and which one.
%       - The letter 'Y' specifies that the event was a target one (i.e.
%       the user intends to write a letter present on that row/column)
%       - The letter 'N' specifies that the event was non-target.


if ~exp_beginfun('filter'); return; end;

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
        'Stimulus Per Trial. Number of consecutive epochs belonging to a same stimulus, that will constitute one single trial.'),...
    arg({'epochs_to_avg','EpochsToAverage'}, [], [1 Inf], ...
        'Epochs to average. Number of epochs from a same trial to use when averaging. Must be less or equal than StimulusPerTrial. By default, this argument will be equal to StimulusPerTrial.'));
        
% If EpochsToAverage was not specified, make it equal to StimulusPerTrial
if isempty(epochs_to_avg)
   epochs_to_avg = stim_per_trial;
end

% If StimulusCodes was not specified, make it equal to event types
if isempty(stimulus)
    % Get all stimulus codes present on the signal
    stimulus = unique({setep.epoch(:).type});
end

finished = false;
ind = 1;

% Loop through each "trial"
while ~finished:
    % 1. Define the trial's limits
    
    % 2. For each stimulus inside the trial, average epochs and save them 
    % inside the first appearance of the corresponding stimulus
    % (preserve order of stimulus appearance)
    
    % 3. Discard epochs that were not used (only the first "number of
    % stimulus in trial will remain"
    
    % 4. Move index to the next trial.
    % If the index is greater than the signal, then the loop is finished.
    finished = true;
end





% Para mantener orden de unique:
% [_,order] = unique(stimulus_in_trial,'first');
% stimulus_in_trial(sort(order))

exp_endfun;
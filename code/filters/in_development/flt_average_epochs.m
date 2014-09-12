function signal = flt_average_epochs(varargin)
% Average signals corresponding to a same stimulus and trial.
% Signal = flt_average_epochs(Signal, StimulusCodes, StimulusPerTrial, EpochsToAverage)
%
% In:
%   Signal          : Epoched EEGLAB data structure.
%
%   StimulusCodes   : Cell array of events considered to be 'stimulus'. Each
%                     element on this array can be either a string, or an
%                     array cell of strings. The latter case means that all 
%                     the strings grouped into one array actually belong to 
%                     a same stimulus (for example, the event type 
%                     '1-TARGET' and the event type '1-NON-TARGET' both 
%                     belong to the stimulus 1).
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
    arg({'stimpertrial','StimulusPerTrial'}, 15, [1 Inf], ...
        'Stimulus Per Trial. Number of consecutive epochs belonging to a same stimulus, that will constitute one single trial.'),...
    arg({'epochs2avg','EpochsToAverage'}, [], [1 Inf], ...
        'Epochs to average. Number of epochs from a same trial to use when averaging. Must be less or equal than StimulusPerTrial. By default, this argument will be equal to StimulusPerTrial.'));
        
% If EpochsToAverage was not specified, make it equal to StimulusPerTrial
if isempty(epochs2avg)
   epochs2avg = stimpertrial;
end

% If StimulusCodes was not specified, make it equal to event types
if isempty(stimulus)
    stimulus = unique({setep.epoch(:).type});       % Get all stimulus codes present on the signal
end

% Validate that required fields are present.
%utl_check_fields(signal,{'event','epoch','srate','pnts'},'signal','signal');
utl_check_fields(signal,{'event','epoch','data'},'signal','signal');

% Get number of different stimulus present
[rows, numStim] = size(stimulus);

% Check that stimulus definition has the correct size
if rows ~= 1
    error('Invalid StimulusCodes');
end

% We will assume that all stimulus are present on each trial,
% i.e. the trial consists of stimpertrial repetitions of each
% defined stimulus.
trialSize = numStim * stimpertrial;

% --------------------------------------------------------------------
% TODO: The case where not all stimulus are present on a same trial is
% not being considered yet.
% A check should be made on each loop, for example:
% #(unique(Signal[i:trialSize])) = numStim
% Second idea: set numStim = unique(Signal[i:trialSize]))
% Keep order in unique():
% [_,order] = unique(stimulus_in_trial,'first');
% stimulus_in_trial(sort(order))
% and average each stimulus present, in order
% --------------------------------------------------------------------

% Get number of epochs, and check that the trial size fits (if it does not,
% our assumption about all stimulus being present in each trial is incorrect).
numEpochs = length(set_epoched.epoch);

if mod(numEpochs, trialSize) ~= 0
   error('Invalid Signal. All stimulus should be present on each trial.'); 
end

totalTrials = numEpochs / trialSize;

% Map each event type to a number
stimulusMap = containers.Map();     

for i = 1:numStim
    % Loop each stimulus and asign them the same code
    for j = 1:length(stimulus{i})
       stimulusMap(stimulus{i}) = i;
    end
end

% This matrix will say, for each trial and stimulus, the index where the
% stimulus first appears. The rest of the appearences of that stimulus 
% within that trial will be averaged and then deleted; the result of the
% average will be saved in the position of the first appearence.
stimFirstApp = zeros(totalTrials, numStim);

% Loop through each "trial"
for trial = 1:trialSize:numEpochs
    % Loop through each epoch inside the trial and average.
    trialEnd = trial + trialSize - 1;
    
    for numEpoch = trial:trialEnd
       
        % If this is the first time that we see this stimulus, save it's
        % position and continue.
        currStim = signal.epoch(numEpoch).type;
        stimInd = stimulusMap(currStim);
        
        if stimFirstApp(trial, stimInd) == 0
            stimFirstApp(trial, stimInd) = numEpoch;
           continue; 
        end
        
        % If not, add its signal to the average
        avgEpochInd = stimFirstApp(trial, stimInd);
        epochSignal = signal.data(:,:,numEpoch);
        signal(:,:,avgEpochInd) = signal(:,:,avgEpochInd) + epochSignal;
        
    end
end

% Discard information about epochs that don't contain averages.
% TODO http://www.mathworks.com/help/nnet/ref/removerows.html?
% CAMBIAR LAS LATENCIAS
        
        
% Divide each remaining epoch by the number of trials

exp_endfun;
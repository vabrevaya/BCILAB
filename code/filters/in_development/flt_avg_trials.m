function signal = flt_avg_trials(varargin)
% Average epoched signal.
% This filter performs an average over trials belonging to a same stimulus
% and "block" - a grouping of trials such that all trials belonging to a
% same event (stimulus) are actually repetitions of a same task, meant to 
% be averaged.
%
% Usage:
% Signal = flt_avg_trials(Signal, RepetitionsPerBlock, StimulusPerBlock, RepetitionsToAverage)
%
% In:
%   Signal                : Epoched dataset to be processed.
%
%   RepetitionsPerBlock   : Number of repetitions of a same stimulus inside
%                           one block. It is assumed that this number does
%                           not vary among different blocks.
%                           Default value: 15
%
%   StimulusPerBlock      : Number of distinct stimulus that occur on each
%                           block of trials. It is assumed that this number
%                           does not vary among different blocks.
%                           Default value: 2
%
%   RepetitionsToAverage  : Number of trials belonging to a same stimulus 
%                           that will be actually used for averaging. Must 
%                           be less or equal than RepetitionsPerBlock. 
%                           If not specified, this argument will be equal 
%                           to RepetitionsPerBlock.
% Out:
%   Signal                : Epoched signal, where each trial is the average 
%                           of all trials belonging to a same stimulus and 
%                           block.
%    
% The filter receives an epoched signal and outputs a new epoched signal 
% with less trials than the original one. Each new epoch will consist of 
% an average of trials belonging to a same stimulus and block.
%
% The argument RepetitionsPerBlock indicates how many repetitions of a same 
% stimulus (event) must be seen before a new block (group of trials) 
% begins. 
%
% The argument StimulusPerBlock specifies the number of distinct events
% that appear on each block. Muliplying this value by RepetitionsPerBlock
% we can know the total number of trials on each block.
%
% As an example, if used with signals produced by a P300Speller[1], a value 
% of RepetitionsPerBlock = 15 means that we will have, on each block, 15 
% repetitions of each row/column in the speller matrix. The first 15 trials 
% corresponding to a flashing of the same row belong to a same letter the 
% user intended to spell; the next group of 15 appearences of that stimulus 
% correspond to the second letter, and so on. Each block will have 12 
% different stimulus, one for each row/column, so StimlulusPerBlock will be
% equal to 12. A block is made out of all 12 stimulus, each one presented
% 15 times, with a total of 12*15 trials per block.
%
% The new signal will contain as many trials as blocks multiplied by the 
% number of distinct stimulus on each block. The actual number of trials 
% used for averaging is specified in the argument RepetitionsToAverage. 
% If this value is less than RepetitionsPerBlock, then only the first 
% appareances that stimulus inside a same block will be used for the 
% average; the rest will be discarded. Whereas RepetitionsPerBlock 
% specifies the limits between blocks of trials, the argument 
% RepetitionsToAverage can be used to perform an average with less 
% information, thus testing whether good performance can be obtained 
% without the need for long recording sessions.
%
% Note that the each new trial will have the same markers as the original 
% ones: average is done only among epochs with the same event type (i.e
% same stimulus).
%
% NOTE: All the stimulus that appear on a same block must have the same 
% number of repetitions (as specified in RepetitionsPerBlock). Also, each
% block must have the same number of distinct stimulus, as specified in
% StimulusPerBlock (although the event types might change between 
% different blocks).
%
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
% If, for each letter, 15 flashes of each row and column were presented to 
% the subject, the following code produces a signal with one trial per 
% row/column and intended letter (averaging only the first 10 flashings of 
% each row/column):
%
% >> signal = set_targetmarkers('Signal', signal, 'EventTypes', markers);
% >> signal = flt_avg_trials('Signal', signal, 'RepetitionsPerBlock', 15, 'StimulusPerBlock', 12, 'RepetitionsToAverage', 10);
%
% References
% ==========
% [1]: p300speller, donchin
% [2]: luck
% 


if ~exp_beginfun('filter'); return; end;

% -------------------------------
% Filter Properties and Arguments
% -------------------------------

declare_properties(...
    'name', 'AverageTrials', ...
    'depends', 'set_makepos', ...       % Require epoched data
    'depends', 'set_targetmarkers', ... % Require markers to be already specified
    'independent_channels', true,...
    'independent_trials', true);

% Input arguments declaration
arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg({'reps_per_block','RepetitionsPerBlock'}, 15, [1 Inf], ...
        'Repetitions per Block. Number of repetitions of a same stimulus that constitute a block.'),...
    arg({'num_stims','StimulusPerBlock'}, 15, [1 Inf], ...
        'Stimulus per Block. Number of distinct stimulus that will be present on each block.'),...
    arg({'stim_2_avg','RepetitionsToAverage'}, [], [1 Inf], ...
        'Repetitions to Average. Number of trials from a same block and stimulus to use when averaging. Must be less or equal than RepetitionsPerBlock. By default, this argument will be equal to RepetitionsPerBlock.'));
        
% If RepetitionsToAverage was not specified, make it equal to RepetitionsPerBlock
if isempty(stim_2_avg)
   stim_2_avg = reps_per_block;
end

% -----------
% Validations
% -----------

% Validate that the required fields are present.
%utl_check_fields(signal,{'event','epoch','srate','pnts'},'signal','signal');
utl_check_fields(signal,{'event','epoch','data'},'signal','signal');

% Check whether there are full blocks inside the signal
% if mod(totalEpochs, epochs_per_block) ~= 0
%    error('Invalid Signal. All stimulus should be present on each trial.'); 
% end

% ----------------
% Signal Averaging
% ----------------

% Get all possible stimulus that might be present on each block.
% Even though the number of distinct stimulus on every block should not
% vary, their codes might do, among different blocks (see P300Speller
% example).
all_stimulus = unique({signal.epoch.type});
%num_stims = length(all_stimulus);

% Get block size and number of blocks in the original signal
trials_per_block = num_stims * reps_per_block;
total_blocks = signal.trials / trials_per_block;

% This matrix will say, for each block and stimulus, the position within 
% the signal where that stimulus was first seen (for the current  block). 
% The rest of the appearences of that stimulus within that block will be 
% averaged and then deleted; the result of the average will be saved in 
% the position of the first appearence.
stim_first_app = zeros(total_blocks, length(all_stimulus));

% Get event codes associated with each trial
stim_codes = {signal.epoch.type};

% Loop through each "block"
for block = 1:total_blocks
    
    % Get all stimulus present on this block
    block_start_ind = (block - 1) * trials_per_block + 1;
    block_end_ind = block_start_ind + trials_per_block - 1;
    block_stim_codes = stim_codes(block_start_ind : block_end_ind);
    
    % Iterate through each trial inside the block and average events,
    % until all distinct stimulus have been averaged
    % (iteration is done to preserve the order in which they appear)
    stim_averaged = 0;
    
    for s_ind = 1:length(block_stim_codes)
    
        curr_stim = block_stim_codes(s_ind);
        stim_number = find(strcmp(curr_stim, all_stimulus));
        
        % Check if we have already averaged this stimulus
        if stim_first_app(block, stim_number) > 0
            % We have already made the average on this stimulus:
            % there is nothing to do 
            continue;
        else
            % First time we see this event.
            % Mark the position where the average will be saved
            epoch_ind = block_start_ind + s_ind - 1;
            stim_first_app(block, stim_number) = epoch_ind;
            
            % Get all indexes where the event appears 
            stim_idxs = find(strcmp(curr_stim, block_stim_codes));
            
            % Transform indexes to be based on the whole signal
            stim_idxs = stim_idxs + (block - 1)*trials_per_block;
            
            % Average the first stim_2_avg signals belonging to that event
            real_stim2avg = min(stim_2_avg, length(stim_idxs));  % in case there are less... TODO: comment this case
            stim_idxs = stim_idxs(1:real_stim2avg);
            signal.data(:,:, epoch_ind) = sum(signal.data(:, :, stim_idxs), 3) ;
            signal.data(:,:, epoch_ind) = signal.data(:,:, epoch_ind) / real_stim2avg;
            
            % Check if we have finished averaging all events
            stim_averaged = stim_averaged + 1;
            
            if stim_averaged == num_stims
                break;
            end
        end
    end
end

% TODO: this could be done using pop_rejepoch?

% Discard information about epochs that do not contain averages.
remaining_trials = stim_first_app(:);           % Indexes of epochs used for average
remaining_trials(remaining_trials == 0) = [];   % Delete zeros - we will index the signal with this array
remaining_trials = sort(remaining_trials);

% Only keep epochs with average
signal.data = signal.data(:, :, remaining_trials);      
signal.trials = length(remaining_trials);
signal.event = signal.event(remaining_trials);
signal.urevent = signal.urevent(remaining_trials);
signal.epoch = signal.epoch(remaining_trials);

% TODO: still need to change signal.times field!!!
% For now I'll just delete it (better than to have wrong info)
signal.times = [];

exp_endfun;
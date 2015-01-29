function signal = flt_avg_trials(varargin)
% Average epoched signal.
% This filter performs an average over trials belonging to a same stimulus
% and "block" - a grouping of epochs such that all epochs belonging to a
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
%                           each block. The number of repetitions in a
%                           block must be the same for all stimulus, and
%                           the same on each block.
%
%   StimulusPerBlock      : Number of *distinct* stimulus that occur on 
%                           each block of trials. The number of stimulus
%                           per block must be the same for all blocks.
%
%   RepetitionsToAverage  : Number of trials belonging to a same stimulus 
%                           that will be actually used for averaging. Must 
%                           be less or equal than RepetitionsPerBlock. 
%                           If not specified, this argument will be equal 
%                           to RepetitionsPerBlock.
% Out:
%   Signal                : Epoched signal, where each epoch is the average 
%                           of all epochs belonging to a same stimulus and 
%                           block.
%    
% The filter receives an epoched signal and outputs a new epoched signal 
% with less trials than the original one. Each new trial will be the 
% average of epochs belonging to a same stimulus and block.
% 
% TODO: for now it actually keeps all the epochs; those which do not
% contain the averages have their event types modified to '__'
%
% The argument RepetitionsPerBlock indicates how many repetitions of a same 
% stimulus (event) must be seen before a new block (group of trials) 
% begins. 
%
% The argument StimulusPerBlock specifies the number of distinct events
% that appear on each block. Muliplying this value by RepetitionsPerBlock
% gives us the total number of trials per block, in the original signal.
%
% As an example, consider a dataset produced by a P300Speller[1] 
% application. A value of RepetitionsPerBlock = 15 means that we expect to 
% have, on each block, 15 repetitions of each row/column of the speller 
% matrix. In this example we consider a block to be a set of 
% intensifications aimed at identifying one single letter. Each block will 
% have 12 different stimulus, one for each row/column, so StimlulusPerBlock 
% will be equal to 12. A block is then made out of all 12 stimulus, each 
% one presented 15 times, with a total of 12*15 trials per block.
%
% The actual number of trials used for averaging is specified through the 
% argument RepetitionsToAverage. If this value is less than 
% RepetitionsPerBlock, then only the first appareances of that stimulus 
% inside a same block will be used for the average; the rest will be 
% discarded. This argument can be used to perform an average with less 
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
% StimulusPerBlock (although the event types might change among 
% different blocks).
%
% NOTE 2: For accurate statistics when using cross-validation, use
%   'EvaluationScheme' = {'chron', block_size}, with
%   block_size = RepetitionsPerBlock * StimulusPerBlock
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
% >> signal = flt_avg_trials('Signal', signal, 'RepetitionsPerBlock', 15, 'StimulusPerBlock', 12, 'RepetitionsToAverage', 10);
%
% References
% ==========
%   [1] Farwell, Lawrence Ashley, and Emanuel Donchin. "Talking off the top of your head: toward
%       a mental prosthesis utilizing event-related brain potentials." 
%       Electroencephalography and clinical Neurophysiology 70.6 (1988): 510-523.
%   [2] Luck, Steven J. "An Introduction to the Event-Related Potential Technique". MIT Press, 2014.
%    


if ~exp_beginfun('filter'); return; end;

% -------------------------------
% Filter Properties and Arguments
% -------------------------------

declare_properties(...
    'name', 'AverageTrials', ...
    'depends', {'set_makepos', 'set_targetmarkers'}, ...    % Require epoched data and markers
    'independent_channels', true,...
    'independent_trials', false);

% Input arguments declaration
arg_define(varargin, ...
    arg_norep({'signal','Signal'}), ...
    arg({'reps_per_block','RepetitionsPerBlock'}, mandatory, [], ...
        'Repetitions per Block. Number of repetitions of a same stimulus that constitute a block.'),...
    arg({'num_stims','StimulusPerBlock'}, mandatory, [], ...
        'Stimulus per Block. Number of distinct stimulus that will be present on each block.'),...
    arg({'stim_2_avg','RepetitionsToAverage'}, [], [], ...
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
total_blocks = ceil(signal.trials / trials_per_block);

% Check if the assumption about each block having the same number of
% stimulus and repetitions per stimulus is correct (i.e. total_blocks is an
% integer)
% if rem(total_blocks, 1) ~= 0
%     error('Incomplete block found. Please check that the signal contains the same number of stimulus and repetitions per stimulus on each block.');
% end

% This matrix will say, for each block and stimulus, the position within 
% the signal where that stimulus was first seen. 
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
    block_end_ind = min(block_start_ind + trials_per_block - 1, signal.trials);     % TODO: some blocks may be incomplete
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

% Discard information about epochs that do not contain averages.
remaining_trials = stim_first_app(:);           % Indexes of epochs used for average
remaining_trials(remaining_trials == 0) = [];   % Delete zeros - we will index the signal with this array
remaining_trials = sort(remaining_trials);

% TODO: I get "Data unaligned" error in ml_calcloss if I delete 
% extra epochs. For now, I will just leave them with an event type
% that is not either target nor non-target.

%signal = exp_eval(set_selepos(signal, remaining_trials'));

epochs = {signal.epoch.type};
extra_trials = 1:length(epochs);
extra_trials(remaining_trials) = [];

% ...not sure how to do this without a loop
for i = extra_trials
   signal.epoch(i).type = {'__'};
end

% TODO: not sure how to change the event field either

exp_endfun;be 
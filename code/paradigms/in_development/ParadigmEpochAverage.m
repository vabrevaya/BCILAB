classdef ParadigmEpochAverage < ParadigmDataflowSimplified
    % This is temporary code, by now is just a copy of ParadigmWindowmeans,
    % with different comments
    
    % Standard paradigm for event-related potentials, based on the 
    % averaging of epochs belonging to a same stimulus.
    %
    % An event-related potential (ERP) is an electric potential recorded by
    % the EEG that appears as a result of a specific sensory, cognitive or 
    % motor event. A general approach when analyzing ERPs is to average 
    % over a certain number of signal segments, all of which are of the 
    % same size and belong to a same time-locked event (usually a stimulus). 
    % Averaging of waveforms answers to the following assumption: an EEG 
    % signal consists of an ERP waveform, which is the same on each trial 
    % belonging to a same stimulus, plus random noise, which, by its 
    % nature, varies from trial to trial. Because the ERP waveform remains 
    % constant, averaging should not modify it. Noise, on the other hand, 
    % can be approximated by a zero-mean gaussian random process and it's 
    % supposed to be completely unrelated to the time-locked event; thus, 
    % it will tend to zero as the number of trials to average increase. 
    % With this assumptions in mind, waveform averaging is expected to 
    % increase the signal-to-noise ratio, rendering the desired ERP 
    % component accessible for classification.
    %
    % The paradigm is implemented as a sequence of signal (pre-)processing,
    % feature extraction and machine learing stages. Signal processing 
    % usually includes spectral filtering (e.g., lowpass filtering) and 
    % occasionally spatial filtering, either for dimensionality reduction 
    % (e.g., by selecting channels) or for the extraction of sparsity, 
    % independence or other feature qualities (e.g., via independent 
    % component analysis). The defining property of the paradigm is the 
    % feature extraction, in which 
    % ...
    
    
    
    % References:
    %  [1] Luck, Steven J. "An Introduction to the Event-Related Potential Technique". MIT Press, 2014.
    %  [2] Farwell, Lawrence Ashley, and Emanuel Donchin. "Talking off the top of your head: toward
    %      a mental prosthesis utilizing event-related brain potentials." 
    %      Electroencephalography and clinical Neurophysiology 70.6 (1988): 510-523.
    %  [3] Benjamin Blankertz, Steven Lemm, Matthias Sebastian Treder, Stefan Haufe, and Klaus-Robert Mueller.
    %      "Single-trial analysis and classification of ERP components -- a tutorial."
    %      Neuroimage, 2010


    
    methods
      
        function defaults = preprocessing_defaults(self)
            defaults = {...
                'SpectralSelection', [0.1 5],...
                'EpochExtraction', [0 0.8],...
                'Resampling', 100};
        end
                
        function model = feature_adapt(self, varargin)
            arg_define(varargin, ...
                arg_norep('signal'), ...
                arg({'wnds','TimeWindows'},[-0.15 -0.10;-0.10 -0.05;-0.05 0],[],'Epoch intervals to take as features. Matrix containing one row for the start and end of each time window over which the signal mean (per every channel) is taken as a feature. Values in seconds.','cat','Feature Extraction'));
            model.wnds = wnds;
            model.chanlocs = signal.chanlocs;
            model.cov = cov(signal.data(:,:)');
        end
        
        function features = feature_extract(self,signal,featuremodel)
            features = reshape(utl_picktimes(signal.data,(featuremodel.wnds-signal.xmin)*signal.srate),[],size(signal.data,3))';
        end
        
        function visualize_model(self,varargin) %#ok<*INUSD>
            args = arg_define([0 3],varargin, ...
                arg_norep({'parent','Parent'},[],[],'Parent figure.'), ...
                arg_norep({'fmodel','FeatureModel'},[],[],'Feature model. This is the part of the model that describes the feature extraction.'), ...
                arg_norep({'pmodel','PredictiveModel'},[],[],'Predictive model. This is the part of the model that describes the predictive mapping.'), ...
                arg({'patterns','PlotPatterns'},false,[],'Plot patterns instead of filters. Whether to plot spatial patterns (forward projections) rather than spatial filters.'), ...
                arg({'paper','PaperFigure'},false,[],'Use paper-style font sizes. Whether to generate a plot with font sizes etc. adjusted for paper.'));
            arg_toworkspace(args);
            parent = args.parent;

            % no parent: create new figure
            if isempty(parent)
                myparent = figure('Name','Per-window weights'); end
            
            % number of pairs, and index of pattern per subplot
            np = size(fmodel.wnds,1);
            horz = ceil(sqrt(np));
            vert = ceil(np/horz);
            
            % get the weights
            if isfield(pmodel.model,'w')
                weights = pmodel.model.w;
            elseif isfield(pmodel.model,'W')
                weights = pmodel.model.W;
            elseif isfield(pmodel.model,'weights')
                weights = pmodel.model.weights;
            else
                error('Cannot find model weights.');
            end
            
            % check if weights contains a bias value
            if numel(weights)==length(fmodel.chanlocs)*np+1
                weights = weights(1:end-1);
            elseif numel(weights)~=length(fmodel.chanlocs)*np
                error('The model is probably not linear');
            end
            
            % turn into matrix, and optionally convert to forward projections
            weights = reshape(weights,length(fmodel.chanlocs),np);
            if patterns
                weights = fmodel.cov*weights;  end
            
            % display
            for p=1:np
                subplot(horz,vert,p,'Parent',parent);
                topoplot(weights(:,p),fmodel.chanlocs,'maplimits',[-max(abs(weights(:))) max(abs(weights(:)))]);
                t=title(['Window' num2str(p) ' (' num2str(fmodel.wnds(p,1)) 's to ' num2str(fmodel.wnds(p,2)) 's)']);
                if args.paper
                    set(t,'FontUnits','normalized');
                    set(t,'FontSize',0.1);                    
                    set(gca,'FontUnits','normalized');
                    set(gca,'FontSize',0.1);
                end
            end
        end
                
        function layout = dialog_layout_defaults(self)
            layout = {'SignalProcessing.Resampling.SamplingRate', 'SignalProcessing.EpochExtraction', ...
                'SignalProcessing.SpectralSelection.FrequencySpecification', '', ...
                'Prediction.FeatureExtraction.TimeWindows', '', 'Prediction.MachineLearning.Learner'};
        end
        
    end
end
                
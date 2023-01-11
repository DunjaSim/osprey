classdef FitObject < handle
    
    
    properties
        % Everything we need to perform a fit and store the results.
        step = [];
        Data = struct('fids', [], 'DwellTime', [] , 'SpectralWidth', [], 'txfrq', [], 't', [], 'ppm', [], 'nucleus', []);
        BasisSets = struct('fids', [], 'names', [], 'includeInFit', []);
        BaselineBasis = struct('specs', []);
        Options = {struct};
        Model = {struct};
        Results = struct;
    end
    
    
    
    methods
        
        function obj = FitObject(data, basis, options)
            % class constructor
            if(nargin > 0) % don't have to initialize the fields
                
                obj.step                = 0;
                %%% DATA %%%
                % Copy the information necessary to create appropriate time-
                % and frequency-domain signals:
                obj.Data.fids            = data.fids;
                obj.Data.DwellTime       = data.dwelltime(1);
                obj.Data.SpectralWidth   = data.spectralwidth(1);
                obj.Data.txfrq           = data.txfrq(1);
                obj.Data.t               = data.t;
                obj.Data.nucleus         = data.nucleus;
                
                % Calculate the ppm axis
                nptsData        = size(data.fids, 1);
                obj.Data.ppm    = calculatePPMAxis(nptsData, data.spectralwidth(1), data.txfrq(1), data.nucleus);
            
                %%% BASIS SET %%%
                % Assume that the basis set nucleus matches the data
                % nucleus
                basis.nucleus = data.nucleus;
                
                % Calculate the receiver frequency
                basis.txfrq  = basis.Bo * lookUpGyromagRatioForNucleus(basis.nucleus) * 1e6;

                % Check that basis set and data have the same resolution
                if abs(basis.dwelltime - obj.Data.DwellTime) > eps
                    warning('Dwell time does not agree between basis set (%5.2e) and data (%5.2e).', obj.Data.DwellTime, basis.dwelltime);
                    fprintf('Resampling the basis set for you. \n');
                    basis = fit_resampleBasis(data, basis);
                end
                if round(basis.spectralwidth) ~= round(obj.Data.SpectralWidth)
                    warning('Spectral width does not agree between basis set (%5.2e) and data (%5.2e).', obj.Data.DwellTime, basis.spectralwidth);
                    fprintf('Resampling the basis set for you. \n');
                    basis = fit_resampleBasis(data, basis);
                end
                
                % Copy the necessary information
                obj.BasisSets.fids  = basis.fids;
                obj.BasisSets.names = basis.name;
                obj.BasisSets.includeInFit = ones(size(basis.name));
                
                
                %%% OPTIONS %%%
                % Initialize an empty container
                if ~isfield(options, 'optimDomain')
                    options.optimDomain = 'FD'; % FD, TD, or FDTD
                else
                    if ~(strcmpi(options.optimDomain,'FD') ||...
                            strcmpi(options.optimDomain,'TD') ||...
                            strcmpi(options.optimDomain,'FDTD'))
                        error('Invalid optimization domain specification (options.optimDomain): (%s).', options.optimDomain)
                    end
                end
                
                if ismember(options.optimDomain, {'FD', 'FDTD'})
                    if ~isfield(options, 'optimFreqFitRange')
                        options.optimFreqFitRange = [0.5 4.0];
                    end
                end
                
                if ismember(options.optimDomain, {'TD', 'FDTD'})
                    if ~isfield(options, 'optimTimeFitRange')
                        options.optimTimeFitRange = [0 1];
                    end
                end
                
                if ~isfield(options, 'optimSignalPart')
                    options.optimSignalPart = 'R'; % R, I, or RI
                end
                
                % Save the property struct
                obj.Options{1} = options;
                
                % Setup baseline model 
                switch obj.Options{1}.baseline.type
                    case 'spline'
                        %%% CREATE BASELINE SPLINE BASIS %%%
                        % Combine real and imaginary part to form a complex spline array.
                        % Use the new, corrected function from here on
                        fitRange    = obj.Options{1}.optimFreqFitRange;
                        dkntmn      = obj.Options{1}.baseline.dkntmn;
                        [splineArray] = osp_gLCM_makeSplineBasis(data, fitRange, dkntmn);   
                        % Save into the property
                        obj.BaselineBasis = splineArray;
                    case 'poly'
                        %%% CREATE BASELINE POLYNOMIAL BASIS %%%
                        fitRange    = obj.Options{1}.optimFreqFitRange;
                        order      = obj.Options{1}.baseline.order;
                        [splineArray] = osp_gLCM_makePolyBasis(data, fitRange, order);   
                        % Save into the property
                        obj.BaselineBasis = splineArray;

                    case 'none'
                        %%% NO BASELINE %%%
                        obj.BaselineBasis = []; 
                end
            
            end
            
        end     
            
        
                                                
    end
    
    
    
    % Static methods, helper functions
    methods (Static)

        sse = initialFitLossFunction(x, tdData, basisSet, baselineBasis, ppm, t, fitRange)
        
        specs = transformBasis(fids, gaussLB, lorentzLB, freqShift, t)        
        
    end
    

end
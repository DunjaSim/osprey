function [out] = osp_editSubSpecAlign(varargin)
%% [varargout] = osp_editSubSpecAlign(varargin)
%   Aligns sub-spectra of (multiplexed) edited MRS data to minimize
%   subtraction artefacts.
%
%   USAGE:
%       [outA, outB, outC, outD] = osp_editSubSpecAlign(in, seq, target,unstableWater);
%
%   INPUTS:
%       in        = Input data structure with sub-spectrum A.
%       seq       = sequence type
%       target     = String. Can be 'GABA' or 'GSH'. (necessary if only two
%                    inputs inA and inB are provided)
%       unstableWater = Flag for unstable residual water. This ignores
%                       water for the optimization and uses Choline instead
%
%   OUTPUTS:
%       outA       = Output following alignment of averages.
%       outB       = Output following alignment of averages.
%       outC       = Output following alignment of averages. (optional)
%       outD       = Output following alignment of averages. (optional)
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-08-15)
%       goeltzs1@jhmi.edu
%       Dr. Mark Mikkelsen (Johns Hopkins University)
%       mmikkel5@jhmi.edu
%   
%   CREDITS:    
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-08-15: First version of the code.


% Determine whether there are 2 (MEGA) or 4 (HERMES/HERCULES) inputs
if nargin == 5
    in     = varargin{1};
    seqType = varargin{2};
    target1 = varargin{3};
    target2 = varargin{4};
    unstableWater = varargin{5};
elseif nargin == 4 && (strcmp(varargin{2},'HERMES') || strcmp(varargin{2},'HERCULES'))
    in     = varargin{1};
    seqType = varargin{2};
    target1 = varargin{3};
    target2 = varargin{4};
    unstableWater = 0;
elseif nargin == 4
    in     = varargin{1};
    seqType = varargin{2};
    target = varargin{3};
    unstableWater = varargin{4};
elseif nargin == 3 && strcmp(varargin{2},'MEGA')
    in     = varargin{1};
    seqType = varargin{2};
    target  = varargin{3};
    unstableWater = 0;
else
    error('Error in osp_editSubSpecAlign! For provide raw data struct, the sequence type, the name of the editing target, and the optional unstable water flag.')
end

% Check whether data is coil-combined. If not, throw error.
if ~in.flags.addedrcvrs
    error('ERROR:  I think it only makes sense to do this after you have combined the channels using op_addrcvrs.  ABORTING!!');
end

% Check whether data is averaged. If not, throw error.
if ~in.flags.averaged
    error('ERROR:  I think it only makes sense to do this after averaging using op_averaging.  ABORTING!!');
end

switch seqType
   case 'MEGA'
        inA=op_takesubspec(in,1);
        inB=op_takesubspec(in,2);
    case 'HERMES'
        inA=op_takesubspec(in,1);
        inB=op_takesubspec(in,2);
        inC=op_takesubspec(in,3);
        inD=op_takesubspec(in,4);
    case 'HERCULES'
        inA=op_takesubspec(in,1);
        inB=op_takesubspec(in,2);
        inC=op_takesubspec(in,3);
        inD=op_takesubspec(in,4);
end
        
    
%%% 1. SET UP REQUIRED VARIABLES %%%
% Define the frequency ranges over which water, NAA, and Cho subtraction artefacts
% are to be minimized. Also, get a good starting estimate for the frequency
% alignment shift by determining the difference between the two maxima in
% the respective peak range (water, NAA, or Cho).
freq = inA.ppm;
% Water
freqLim(1,:) = freq <= 4.68+0.22 & freq >= 4.68-0.22;
[~,i] = max([abs(real(inA.specs(freqLim(1,:)))) abs(real(inB.specs(freqLim(1,:))))]);
freq2 = freq(freqLim(1,:));
maxFreq = freq2(i);
for jj = 1:2
    tmp(jj,:) = freq <= maxFreq(jj)+0.22 & freq >= maxFreq(jj)-0.22;
end
freqLim(1,:) = or(tmp(1,:), tmp(2,:));
f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
x0(1,:) = [f0 0];
    
% NAA
freqLim(2,:) = freq <= 2.01+0.13 & freq >= 2.01-0.13;
peaks = '2.01 ppm (A/B)';
switch seqType
    case 'HERCULES'
        [~,i] = max([abs(real(inA.specs(freqLim(2,:)))) abs(real(inC.specs(freqLim(2,:))))]);
    case 'HERMES'
        [~,i] = max([abs(real(inA.specs(freqLim(2,:)))) abs(real(inC.specs(freqLim(2,:))))]);
    case 'MEGA'
        [~,i] = max([abs(real(inA.specs(freqLim(2,:)))) abs(real(inB.specs(freqLim(2,:))))]);
end
freq2 = freq(freqLim(2,:));
maxFreq = freq2(i);
for jj = 1:2
    tmp(jj,:) = freq <= maxFreq(jj)+0.13 & freq >= maxFreq(jj)-0.13;
end
freqLim(2,:) = or(tmp(1,:), tmp(2,:));
f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
x0(2,:) = [f0 0];

% In case the water peak is not well-behaved and has several peaks we are
% possibly detecting several peaks. This will lead to unreasonable shifts
% between the sub-spectra. In this case, we use the Choline peak.
if unstableWater

    freqLim(1,:) = freq <= 3.22+0.09 & freq >= 3.22-0.09;
    [~,i] = max([abs(real(inA.specs(freqLim(1,:)))) abs(real(inB.specs(freqLim(1,:))))]);
    freq2 = freq(freqLim(1,:));
    maxFreq = freq2(i);
    for jj = 1:2
        tmp(jj,:) = freq <= maxFreq(jj)+0.08 & freq >= maxFreq(jj)-0.08;
    end
    freqLim(1,:) = or(tmp(1,:), tmp(2,:));
    f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
    x0(1,:) = [f0 0];

end

% Optimization options
lsqnonlinopts = optimoptions(@lsqnonlin);
lsqnonlinopts = optimoptions(lsqnonlinopts,'Display','off','Algorithm','levenberg-marquardt');

% Initialize common variables
t           = inA.t;


%%% 2. PERFORM ALIGNMENT BASED ON SEQUENCE TYPE
if strcmp(seqType, 'HERMES') || strcmp(seqType, 'HERCULES') 
    if ~(exist('target1','var') && exist('target2','var'))
        %Fall back into default HERMES GABA GSH editing
        target1 = 'GABA';
        target2 = 'GSH';
    end
    
    target = [target1 target2];
    switch target
        case {'GABAGSH','GABALac','GABAEtOH'}  
            % For HERMES/HERCULES data, align the GSH-OFF spectra first, i.e.
            % minimize the residual water peak in the difference between them.

            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(1,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(1,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inB spectrum
            fidsB = inB.fids.*exp(1i*pi*(t'*param(1,1)*2+param(1,2)/180));
            specsB = fftshift(fft(fidsB, [], inB.dims.t), inB.dims.t);
            % Create output
            outA = inA;
            outB = inB;
            outB.fids = fidsB;
            outB.specs = specsB;

            % Then, align the GABA-OFF spectra, i.e minimize the residual NAA peak
            % in the difference between them.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inC.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inC, 1/a), freqLim(2,:), t, x);
            param(2,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inC spectrum
            fidsC = inC.fids.*exp(1i*pi*(t'*param(2,1)*2+param(2,2)/180));
            specsC = fftshift(fft(fidsC, [], inC.dims.t), inC.dims.t);
            % Create output
            outC = inC;
            outC.fids = fidsC;
            outC.specs = specsC;

            % Then, align the GABA-ON-GSH-ON spectra to the **corrected** GABA-OFF-GSH-ON
            % spectrum - this is something Mark/Georg independently from each other
            % found out to work best for HERMES/HERCULES data.

            % Find Cho peak and get starting estimate for the frequency shift
            freqLim(3,:) = freq <= 3.2+0.09 & freq >= 3.2-0.09;
            [~,i] = max([abs(real(outC.specs(freqLim(3,:)))) abs(real(inD.specs(freqLim(3,:))))]);
            freq2 = freq(freqLim(3,:));
            maxFreq = freq2(i);
            for jj = 1:2
                tmp(jj,:) = freq <= maxFreq(jj)+0.08 & freq >= maxFreq(jj)-0.08;
            end
            freqLim(3,:) = or(tmp(1,:), tmp(2,:));
            f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
            x0(3,:) = [f0 0];

            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(outC.specs)) abs(real(inD.specs))]));
            fun = @(x) objFunc(op_ampScale(outC, 1/a), op_ampScale(inD, 1/a), freqLim(3,:), t, x);
            param(3,:) = lsqnonlin(fun, x0(3,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inD spectrum
            fidsD = inD.fids.*exp(1i*pi*(t'*param(3,1)*2+param(3,2)/180));
            specsD = fftshift(fft(fidsD, [], inD.dims.t), inD.dims.t);

            % Create output
            outD = inD;
            outD.fids = fidsD;
            outD.specs = specsD;
        
        case 'NAANAAG' 
            % For HERMES/HERCULES data, align the GSH-OFF spectra first, i.e.
            % minimize the residual water peak in the difference between them.
            % NAA
            freqLim(1,:) = freq <= 2.01+0.13 & freq >= 2.01-0.13;
            [~,i] = max([abs(real(inA.specs(freqLim(1,:)))) abs(real(inB.specs(freqLim(1,:))))]);
            freq2 = freq(freqLim(1,:));
            maxFreq = freq2(i);
            for jj = 1:2
                tmp(jj,:) = freq <= maxFreq(jj)+0.13 & freq >= maxFreq(jj)-0.13;
            end
            freqLim(1,:) = or(tmp(1,:), tmp(2,:));
            f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
            x0(1,:) = [f0 0];
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(1,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(1,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inB spectrum
            fidsB = inB.fids.*exp(1i*pi*(t'*param(1,1)*2+param(1,2)/180));
            specsB = fftshift(fft(fidsB, [], inB.dims.t), inB.dims.t);
            % Create output
            outA = inA;
            outB = inB;
            outB.fids = fidsB;
            outB.specs = specsB;

            % Then, align the GABA-OFF spectra, i.e minimize the residual NAA peak
            % in the difference between them.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inC.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inC, 1/a), freqLim(2,:), t, x);
            param(2,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inC spectrum
            fidsC = inC.fids.*exp(1i*pi*(t'*param(2,1)*2+param(2,2)/180));
            specsC = fftshift(fft(fidsC, [], inC.dims.t), inC.dims.t);
            % Create output
            outC = inC;
            outC.fids = fidsC;
            outC.specs = specsC;

            % Then, align the GABA-ON-GSH-ON spectra to the **corrected** GABA-OFF-GSH-ON
            % spectrum - this is something Mark/Georg independently from each other
            % found out to work best for HERMES/HERCULES data.

            % Find Cho peak and get starting estimate for the frequency shift
            freqLim(3,:) = freq <= 2.01+0.13 & freq >= 2.01-0.13;
            [~,i] = max([abs(real(outC.specs(freqLim(3,:)))) abs(real(inD.specs(freqLim(3,:))))]);
            freq2 = freq(freqLim(3,:));
            maxFreq = freq2(i);
            for jj = 1:2
                tmp(jj,:) = freq <= maxFreq(jj)+0.13 & freq >= maxFreq(jj)-0.13;
            end
            freqLim(3,:) = or(tmp(1,:), tmp(2,:));
            f0 = (maxFreq(1) - maxFreq(2)) * inA.txfrq*1e-6;
            x0(3,:) = [f0 0];

            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(outC.specs)) abs(real(inD.specs))]));
            fun = @(x) objFunc(op_ampScale(outC, 1/a), op_ampScale(inD, 1/a), freqLim(3,:), t, x);
            param(3,:) = lsqnonlin(fun, x0(3,:), [], [], lsqnonlinopts);
            % Apply the calculated frequency/phase adjustment to the inD spectrum
            fidsD = inD.fids.*exp(1i*pi*(t'*param(3,1)*2+param(3,2)/180));
            specsD = fftshift(fft(fidsD, [], inD.dims.t), inD.dims.t);

            % Create output
            outD = inD;
            outD.fids = fidsD;
            outD.specs = specsD;
    end
    % Create output
    out = op_mergesubspec(outA,outB,outC,outD);

    % Add NIfTI-MRS provenance
    % Generate fields for provenance
    if unstableWater
       peaks = '3.2 ppm (A/B), 2.01 ppm (B/C), 3.2 (C/D)';
    else
       peaks = '4.68 ppm (A/B), 2.01 ppm (B/C), 3.2 (C/D)';
    end
    fields.Method   = 'Aligment of subtraction sub-spectra';
    fields.Details  = ['L2 optimization of HADAMARD spectra (Mikkelsen et al. 2018), dim = DIM_EDIT, reference = ' peaks];
    out = op_add_analysis_provenance(out,fields);
    
elseif strcmp(seqType, 'MEGA')
    % For MEGA-edited data, the 'reporter signal' that is used to align the
    % two sub-spectra will depend on the edited metabolite. Since the peak
    % needs to be identical in both acquisitions, we choose the residual
    % water peak for GABA-edited data, and the NAA peak for GSH-edited
    % data.
    switch target
        case 'GABA'
            % For GABA-edited data, align the GABA-ON spectrum using the
            % residual water peak.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(1,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(1,:), [], [], lsqnonlinopts);
            peaks = '4.7 ppm (A/B)';

        case 'GSH'
            % For GSH-edited data, align the GSH-ON spectrum using the
            % NAA peak.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(2,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);
            
        case 'Lac'
            % For Lac-edited data, align the Lac-ON spectrum using the
            % NAA peak.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(2,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);

        case 'PE322'
            % For Lac-edited data, align the Lac-ON spectrum using the
            % NAA peak.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(2,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);
 
        case 'PE398'
            % For Lac-edited data, align the Lac-ON spectrum using the
            % NAA peak.
            % Determine normalization factor so that normalized spectra are entered
            % into the optimization
            a = max(max([abs(real(inA.specs)) abs(real(inB.specs))]));
            fun = @(x) objFunc(op_ampScale(inA, 1/a), op_ampScale(inB, 1/a), freqLim(2,:), t, x);
            param(1,:) = lsqnonlin(fun, x0(2,:), [], [], lsqnonlinopts);

            
        otherwise
            error('Error in osp_editSubSpecAlign! Target string not recognized.');
    end

    % Apply the calculated frequency/phase adjustment to the inB spectrum
    fidsB = inB.fids.*exp(1i*pi*(t'*param(1,1)*2+param(1,2)/180));
    specsB = fftshift(fft(fidsB, [], inB.dims.t), inB.dims.t);
    
    % Create output
    outA = inA;
    outB = inB;
    outB.fids = fidsB;
    outB.specs = specsB;
    out=op_mergesubspec(outA,outB);

    % Add NIfTI-MRS provenance
    % Generate fields for provenance
    if unstableWater
       peaks = '3.68 ppm (A/B)';
    end
    fields.Method   = 'Aligment of subtraction sub-spectra';
    fields.Details  = ['L2 optimization of ON/OFF spectra (Mikkelsen et al. 2018), dim = DIM_EDIT, reference = ' peaks];
    out = op_add_analysis_provenance(out,fields);

    varargout{1} = out;
    
end

end


function out = objFunc(in1, in2, freqLim, t, x)

% This is the objective function that minimizes the difference over the 
% frequency range (freqLim) between the target spectrum (in1) and the 
% spectrum that is to be frequency-and-phase aligned (in2).

f   = x(1); % frequency correction
phi = x(2); % phase correction

y1 = in1.fids;
y2 = in2.fids .* exp(1i*pi*(t'*f*2+phi/180)); % apply to time-domain data

% fft
a = real(fftshift(fft(y1,[],1),1));
b = real(fftshift(fft(y2,[],1),1));

% return difference vector over defined frequency range
DIFF = a - b;
out = DIFF(freqLim);

end
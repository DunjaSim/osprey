function [MRSCont] = osp_LoadTwix(MRSCont)
%% [MRSCont] = osp_LoadTwix(MRSCont)
%   This function reads raw (un-combined) data from Siemens TWIX files.
%
%   USAGE:
%       [MRSCont] = osp_LoadTwix(MRSCont);
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-20)
%       goeltzs1@jhmi.edu
%
%   CREDITS:
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-02-20: First version of the code.

% Close any remaining open figures
close all;
if MRSCont.flags.hasMM
    if length(MRSCont.files_mm) ~= MRSCont.nDatasets(1)
        msg = 'Number of specified metabolite-nulled files does not match number of specified metabolite files.';
        fprintf(msg);
        error(msg);
    end
end
if MRSCont.flags.hasRef
    if length(MRSCont.files_ref) ~= MRSCont.nDatasets(1)
        msg = 'Number of specified reference files does not match number of specified metabolite files.';
        fprintf(msg);
        error(msg);
    end
end
if MRSCont.flags.hasWater
    if length(MRSCont.files_w) ~= MRSCont.nDatasets(1)
        msg = 'Number of specified water files does not match number of specified metabolite files.';
        fprintf(msg);
        error(msg);
    end
end

%% Get the data (loop over all datasets)
refLoadTime = tic;
if MRSCont.flags.isGUI
    progressText = MRSCont.flags.inProgress;
else
    progressText = '';
end

for kk = 1:MRSCont.nDatasets(1)
    for ll = 1: 1:MRSCont.nDatasets(2)
        [~] = printLog('OspreyLoad',kk,ll,MRSCont.nDatasets,progressText,MRSCont.flags.isGUI ,MRSCont.flags.isMRSI);

        if ~(MRSCont.flags.didLoad == 1 && MRSCont.flags.speedUp && isfield(MRSCont, 'raw') && (kk > length(MRSCont.raw))) || ~strcmp(MRSCont.ver.Osp,MRSCont.ver.CheckOsp)
            % Read in the raw metabolite data
            metab_ll = MRSCont.opts.MultipleSpectra.metab(ll);
            raw                         = io_loadspec_twix(MRSCont.files{metab_ll,kk});
            raw                         = op_leftshift(raw,raw.pointsToLeftshift);
            if strcmp(raw.seq,'SLASER_D')
                raw = op_truncate(raw,2068,0);
            end
            % Add NIfTI-MRS information
            raw                           = osp_add_nii_mrs_field(raw,MRSCont.ver.Osp);
            MRSCont.raw_uncomb{ll,kk}      = raw;
            % Read in the raw reference data. If a reference exists, perform the
            % coil combination based on the reference, and perform an eddy current
            % correction. If not, combine metabolite data based on its own signal.
            if MRSCont.flags.hasRef
                ref_ll = MRSCont.opts.MultipleSpectra.ref(ll);
                raw_ref                     = io_loadspec_twix(MRSCont.files_ref{ref_ll,kk});
                raw_ref                     = op_leftshift(raw_ref,raw_ref.pointsToLeftshift);
                % Add NIfTI-MRS information
                raw_ref                           = osp_add_nii_mrs_field(raw_ref,MRSCont.ver.Osp);
                MRSCont.raw_ref_uncomb{ref_ll,kk}  = raw_ref;
            else
                ref_ll = 1;
            end
            if MRSCont.flags.hasWater
                w_ll = MRSCont.opts.MultipleSpectra.w(ll);
                raw_w                       = io_loadspec_twix(MRSCont.files_w{w_ll,kk});
                raw_w                       = op_leftshift(raw_w,raw_w.pointsToLeftshift);
                % Add NIfTI-MRS information
                raw_w                           = osp_add_nii_mrs_field(raw_w,MRSCont.ver.Osp);
                MRSCont.raw_w_uncomb{w_ll,kk}    = raw_w;
            else
                w_ll = 1;
            end
            if MRSCont.flags.hasMM
                temp_ll = MRSCont.opts.MultipleSpectra.mm(ll);
                raw_mm                       = io_loadspec_twix(MRSCont.files_mm{temp_ll,kk});
                raw_mm                       = op_leftshift(raw_mm,raw_mm.pointsToLeftshift);
                % Add NIfTI-MRS information
                raw_mm                           = osp_add_nii_mrs_field(raw_mm,MRSCont.ver.Osp);
                MRSCont.raw_mm_uncomb{temp_ll,kk}    = raw_mm;
            end
            if MRSCont.flags.hasMMRef
                temp_ll = MRSCont.opts.MultipleSpectra.mm_ref(ll);
                raw_mm_ref                       = io_loadspec_twix(MRSCont.files_mm_ref{temp_ll,kk});
                raw_mm_ref                       = op_leftshift(raw_mm_ref,raw_mm_ref.pointsToLeftshift);
                % Add NIfTI-MRS information
                raw_mm_ref                           = osp_add_nii_mrs_field(raw_mm_ref,MRSCont.ver.Osp);
                MRSCont.raw_mm_ref_uncomb{temp_ll,kk}    = raw_mm_ref;
            end

            % Perform coil combination (SENSE-based reconstruction if PRIAM flag set)
            if ~MRSCont.flags.isPRIAM
                    [MRSCont] = osp_combineCoils(MRSCont,kk,metab_ll,ref_ll,w_ll);
            elseif MRSCont.flags.isPRIAM

                fprintf('Coming soon!');
                error('Coming soon!');
                %[MRSCont] = osp_senseRecon(MRSCont);
            end
        end
    end
end


% Delete un-combined data to free up memory
raw_fields = {'raw_uncomb','raw_ref_uncomb','raw_w_uncomb'};
for kk = 1:length(raw_fields)
    if isfield(MRSCont, raw_fields{kk})
        MRSCont = rmfield(MRSCont, raw_fields{kk});
    end
end
time = toc(refLoadTime);
[~] = printLog('done',time,ll,MRSCont.nDatasets,progressText,MRSCont.flags.isGUI ,MRSCont.flags.isMRSI);
MRSCont.runtime.Load = time;

end

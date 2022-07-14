% coreg_sdat.m
% Georg Oeltzschner, Johns Hopkins University 2019.
% 
% USAGE:
% [vol_mask] = coreg_sdat(in, vol_image, maskFile);
% 
% DESCRIPTION:
% Creates a SPM volume containing a voxel mask with the same dimensions 
% as the SPM volume containing a structural image. The voxel mask will be
% created with the geometry information stored in the FID-A structure "in".
% This routine works for the Philips SDAT format.
% 
% CREDITS:
% The routine for correct determination of the phase and readout
% directions of the MRS voxel is adapted from 
% vox2ras_rsolveAA.m
% (Dr. Rudolph Pienaar, Massachusetts General Hospital, Boston)
%
% INPUTS:
% in        = Input data structure.
% vol_image	= SPM volume of the structural image that the voxel defined in
%           the 'geometry' field of the input data structure 'in' is
%           supposed to be co-registered to.
% maskFile  = Filename under which the SPM volume of the co-registered
%           voxel mask is supposed to be saved.
% DualVoxel = struct with Dualvoxel information
%
% OUTPUTS:
% vol_mask  = SPM volume of the coregistered voxel mask.
% T1_max    = maximum intensity of the image volume.

function [vol_mask, T1_max, voxel_ctr, vol_mask_mrsi] = coreg_sdat(in, vol_image, maskFile,DualVoxel)

if nargin < 4
    DualVoxel = [];
end

% Deactivate MATLAB warnings and load geometry parameters
warning('off','MATLAB:nearlySingularMatrix');
warning('off','MATLAB:qhullmx:InternalWarning');
geom = in.geometry;

%%% 1. PREPARE THE STRUCTURAL IMAGE
if (vol_image.dim(1)* vol_image.mat(1,1) < geom.size.lr) || (vol_image.dim(2)* vol_image.mat(2,2) < geom.size.ap)
    diff_lr = round(abs(geom.size.lr - vol_image.dim(1)* vol_image.mat(1,1)));
    diff_ap = round(abs(geom.size.ap - vol_image.dim(2)* vol_image.mat(2,2)));
    [pad,ind] = max([diff_lr, diff_ap]);
    lr_ap_voxsize = [geom.size.lr/in.nXvoxels, geom.size.ap/in.nYvoxels];
    voxelsToAdd = round(pad/lr_ap_voxsize(ind))+1;
    pad = round(lr_ap_voxsize(ind)*voxelsToAdd);
    realignT1MRSI(vol_image.fname,pad);
    [path,file,ext]=fileparts(vol_image.fname);
    vol_image = spm_vol(fullfile(path, ['r',file,ext]));
end
% Create SPM volume and read in the NIfTI file with the structural image.
[T1,XYZ]    = spm_read_vols(vol_image);
T1_max      = max(T1(:));

%Shift imaging voxel coordinates by half an imaging voxel so that the XYZ matrix
%tells us the x,y,z coordinates of the MIDDLE of that imaging voxel.
[~,voxdim] = spm_get_bbox(vol_image,'fv');
voxdim = abs(voxdim)';
halfpixshift = -voxdim(1:3)/2;
halfpixshift(3) = -halfpixshift(3);
XYZ = XYZ + repmat(halfpixshift, [1 size(XYZ,2)]);


%%% 2. GENERATE THE COORDINATES OF THE VOXEL CORNERS
% Get information from SPAR - change later to be read in
ap_size = geom.size.ap;
lr_size = geom.size.lr;
if ~isstruct(DualVoxel) &&  ~isempty(DualVoxel) %MRSI
   cc_org =  geom.size.cc;
   cc_size = cc_org - ((DualVoxel(1)-1)*geom.slice_distance);
   cc_gap = geom.slice_distance - (cc_org-(DualVoxel(1)-1)*geom.slice_distance);
else
   cc_size = geom.size.cc;
end
ap_off  = geom.pos.ap;
lr_off  = geom.pos.lr;
if ~isstruct(DualVoxel) &&  ~isempty(DualVoxel) %MRSI 
    cc_off  = repmat(geom.pos.cc,DualVoxel(1));
    cc_off(1) = cc_off(1) + geom.slice_distance;
    cc_off(3) = cc_off(3) - geom.slice_distance;
else
    cc_off  = geom.pos.cc;
end
ap_ang  = geom.rot.ap;
lr_ang  = geom.rot.lr;
cc_ang  = geom.rot.cc;

% We need to flip ap and lr axes to match NIFTI convention
if ~isstruct(DualVoxel) &&  ~isempty(DualVoxel) %MRSI
%     ap_off = -ap_off+(pad* vol_image.mat(2,2)) - geom.size.ap/in.nYvoxels;
%     lr_off = -lr_off-(pad* vol_image.mat(1,1)) - geom.size.lr/in.nXvoxels;
    ap_off = -(ap_off-(pad* vol_image.mat(2,2)));
    lr_off = -(lr_off+(pad* vol_image.mat(1,1)));
else
    ap_off = -ap_off;
    lr_off = -lr_off;
end
ap_ang = -ap_ang;
lr_ang = -lr_ang;

% Define voxel coordinates before rotation and transition
vox_ctr = ...
    [lr_size/2 -ap_size/2  cc_size/2;
    -lr_size/2 -ap_size/2  cc_size/2;
    -lr_size/2  ap_size/2  cc_size/2;
     lr_size/2  ap_size/2  cc_size/2;
    -lr_size/2  ap_size/2 -cc_size/2;
     lr_size/2  ap_size/2 -cc_size/2;
     lr_size/2 -ap_size/2 -cc_size/2;
    -lr_size/2 -ap_size/2 -cc_size/2];

% Make rotations on voxel
rad = pi/180;
initrot = zeros(3,3);

xrot      = initrot;
xrot(1,1) = 1;
xrot(2,2) = cos(lr_ang *rad);
xrot(2,3) = -sin(lr_ang*rad);
xrot(3,2) = sin(lr_ang*rad);
xrot(3,3) = cos(lr_ang*rad);

yrot      = initrot;
yrot(1,1) = cos(ap_ang*rad);
yrot(1,3) = sin(ap_ang*rad);
yrot(2,2) = 1;
yrot(3,1) = -sin(ap_ang*rad);
yrot(3,3) = cos(ap_ang*rad);

zrot      = initrot;
zrot(1,1) = cos(cc_ang*rad);
zrot(1,2) = -sin(cc_ang*rad);
zrot(2,1) = sin(cc_ang*rad);
zrot(2,2) = cos(cc_ang*rad);
zrot(3,3) = 1;

% Apply rotation as prescribed
vox_rot = xrot * yrot * zrot * vox_ctr.';

% Shift rotated voxel by the center offset to its final position
if DualVoxel(1) == 1
    vox_ctr_coor = [lr_off ap_off cc_off];
    vox_ctr_coor = repmat(vox_ctr_coor.', [1,8]);
    vox_corner = vox_rot+vox_ctr_coor;
else
    vox_ctr_coor = zeros(3,8,DualVoxel(1));
    vox_corner = zeros(3,8,DualVoxel(1));
    for z = 1 : DualVoxel(1)
        vox_ctr_coor_temp = [lr_off ap_off cc_off(z)];
        vox_ctr_coor(:,:,z) = repmat(vox_ctr_coor_temp.', [1,8]);
        vox_corner(:,:,z) = vox_rot+vox_ctr_coor(:,:,z);
    end
end

% For PRIAM MRS we need to add the second voxel dimensions and locations
% Depending on the PRIAM offset direction parameter, calculate the voxel
% corner and voxel center coordinates
if isstruct(DualVoxel)
    % Calculate unit vectors pointing along the voxel edges in real space
    lr_vec = vox_corner(:,1) - vox_corner(:,2);
    ap_vec = vox_corner(:,4) - vox_corner(:,1);
    cc_vec = vox_corner(:,1) - vox_corner(:,7);
    lr_vec = lr_vec ./ (norm(lr_vec));
    ap_vec = ap_vec ./ (norm(ap_vec));
    cc_vec = cc_vec ./ (norm(cc_vec));
    
    secondVoxelOffset    = DualVoxel.priam_offset;
    secondVoxelDirection = DualVoxel.priam_direction;
    switch secondVoxelDirection
        case 'R'
            shift = secondVoxelOffset*lr_vec;
        case 'L'
            shift = -secondVoxelOffset*lr_vec;
        case 'A'
            shift = secondVoxelOffset*ap_vec;
        case 'P'
            shift = -secondVoxelOffset*ap_vec;
        case 'F'
            shift = -secondVoxelOffset*cc_vec;
        case 'H'
            shift = -secondVoxelOffset*cc_vec;
    end
    vox_corner(:,:,2) = vox_corner + shift;
    vox_ctr_coor(:,:,2) = vox_ctr_coor + shift;
end



%%% 3. CREATE AND SAVE THE VOXEL MASK
if isstruct(DualVoxel) %PRIAM
% Create a mask with all voxels that are inside the voxel
    for rr = 1:size(vox_ctr_coor,3)
        mask = zeros(1,size(XYZ,2));
        sphere_radius = sqrt((lr_size/2)^2+(ap_size/2)^2+(cc_size/2)^2);
        distance2voxctr = sqrt(sum((XYZ-repmat([vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)].',[1 size(XYZ,2)])).^2,1));
        sphere_mask(distance2voxctr <= sphere_radius) = 1;
    
        mask(sphere_mask == 1) = 1;
        XYZ_sphere = XYZ(:,sphere_mask == 1);
    
        tri = delaunayn([vox_corner(:,:,rr).'; [vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)]]);
        tn = tsearchn([vox_corner(:,:,rr).'; [vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)]], tri, XYZ_sphere.');
        isinside = ~isnan(tn);
        mask(sphere_mask==1) = isinside;
    
        % Take over the voxel dimensions from the structural
        mask = reshape(mask, vol_image.dim);
        
        if ~isstruct(DualVoxel) % For svs data create one voxel mask
            maskFileOut = maskFile;
            maskFileOut            = strrep(maskFile,'VoxelMask.nii',['Voxel_1_VoxelMask.nii']);     
            
        else  % For PRIAM data create two voxel masks        
            maskFileOut            = strrep(maskFile,'VoxelMask.nii',['Voxel_' num2str(rr) '_VoxelMask.nii']);       
        end
    
        % Fill in the SPM volume header information
        vol_mask.fname   = maskFileOut;
        vol_mask.dim     = vol_image.dim;
        vol_mask.dt      = vol_image.dt;
        vol_mask.mat     = vol_image.mat;
        if ~isstruct(DualVoxel) 
            vol_mask.descrip = 'MRS_voxel_mask';
        else % For PRIAM data create two voxel masks
            vol_mask.descrip = [ 'MRS_voxel_mask_' num2str(rr)];
        end
            
    
        % Write the SPM volume to disk
        if ~isstruct(DualVoxel) 
            vol_mask = spm_write_vol(vol_mask,mask);
        else % For PRIAM data store two voxel masks
            vol_mask_out{rr} = spm_write_vol(vol_mask,mask);
        end
       
    
        % Store voxel centre for output figure
        if ~isstruct(DualVoxel)
            voxel_ctr = [lr_off ap_off cc_off];
        else % For PRIAM data store two voxel center coordnates
            voxel_ctr(:,:,rr) = [lr_off ap_off cc_off]' + (rr -1) *shift;
        end
    end
else %MRSI
    for rr = 1:size(vox_ctr_coor,3)
        mask = zeros(1,size(XYZ,2));
        sphere_radius = sqrt((lr_size/2)^2+(ap_size/2)^2+(cc_size/2)^2);
        distance2voxctr = sqrt(sum((XYZ-repmat([vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)].',[1 size(XYZ,2)])).^2,1));
        sphere_mask(distance2voxctr <= sphere_radius) = 1;
    
        mask(sphere_mask == 1) = 1;
        XYZ_sphere = XYZ(:,sphere_mask == 1);
    
        tri = delaunayn([vox_corner(:,:,rr).'; [vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)]]);
        tn = tsearchn([vox_corner(:,:,rr).'; [vox_ctr_coor(1,1,rr) vox_ctr_coor(2,1,rr) vox_ctr_coor(3,1,rr)]], tri, XYZ_sphere.');
        isinside = ~isnan(tn);
        mask(sphere_mask==1) = isinside;
    
        % Take over the voxel dimensions from the structural
        mask = reshape(mask, vol_image.dim);
        
        maskFileOut = maskFile;
        maskFileOut            = strrep(maskFile,'VoxelMask.nii',['Voxel_1_VoxelMask_slice_' num2str(rr) '.nii']);     
    
    
        % Fill in the SPM volume header information
        vol_mask.fname   = maskFileOut;
        vol_mask.dim     = vol_image.dim;
        vol_mask.dt      = vol_image.dt;
        vol_mask.mat     = vol_image.mat;

        vol_mask.descrip = ['MRS_voxel_mask_slice' num2str(rr)];
            
    
        % Write the SPM volume to disk
        vol_mask = spm_write_vol(vol_mask,mask);

        mask_res = zeros(in.nXvoxels+2*voxelsToAdd,in.nYvoxels+2*voxelsToAdd,vol_mask.dim(3));
        for z = 1 : vol_mask.dim(3)
            mask_res(:,:,z)= imresize(double(squeeze(mask(:,:,z))),[in.nXvoxels+2*voxelsToAdd,in.nYvoxels+2*voxelsToAdd],'method','nearest');
        end

        checker_mask_res = mask_res;
        for z = 1 : size(mask_res,3)
            for y = 1 : 2: size(mask_res,2)
                checker_mask_res(1:2:end,y,z) = 2;

            end
            for y = 2 : 2: size(mask_res,2)
                checker_mask_res(2:2:end,y,z) = 2;
            end

        end
%         checker_mask_res = checker_mask_res.*mask_res;
        for z = 1 : vol_mask.dim(3)
            if sum(squeeze(mask_res(:,:,z)),'all') == 0
                checker_mask_res(:,:,z) = zeros(in.nXvoxels+2*voxelsToAdd,in.nYvoxels+2*voxelsToAdd);
            end
        end
        checker_mask_res = checker_mask_res.*mask_res;
        checker_mask_res = checker_mask_res/2;

        checker_mask = zeros(vol_mask.dim);
        for z = 1 : vol_mask.dim(3)
            checker_mask(:,:,z)= imresize(double(squeeze(checker_mask_res(:,:,z))),[vol_mask.dim(1),vol_mask.dim(2)],'method','nearest');
        end

       checker_maskFileOut            = strrep(maskFile,'VoxelMask.nii',['Voxel_1_CheckerVoxelMask_slice_' num2str(rr) '.nii']);     
    
    
        % Fill in the SPM volume header information
        vol_checker_mask.fname   = checker_maskFileOut;
        vol_checker_mask.dim     = vol_image.dim;
        vol_checker_mask.dt      = vol_image.dt;
        vol_checker_mask.mat     = vol_image.mat;

        vol_checker_mask.descrip = ['MRS_checker_voxel_mask_slice' num2str(rr)];
        % Write the SPM volume to disk
        vol_checker_mask = spm_write_vol(vol_checker_mask,checker_mask);

%         [MRSImaskPath,MRSImaskFile,MRSImaskExt] = fileparts(maskFileOut);
%         MRSImaskFileOut            = fullfile(MRSImaskPath,['LI_slice_' num2str(rr) MRSImaskExt]);
%         if isfile(MRSImaskFileOut)
%             vol_mask_mrsi = spm_vol(MRSImaskFileOut);
%             mrsi_mask = spm_read_vols(vol_mask_mrsi);
%             mrsi_mask(mrsi_mask<0.29)=0;
%             mrsi_mask(mrsi_mask>0.29)=1;
%             vol_mask_mrsi.fname = fullfile(MRSImaskPath,['LIthresh_slice_' num2str(rr)' MRSImaskExt]);
%             vol_mask_mrsi = spm_write_vol(vol_mask_mrsi,mrsi_mask);
%             checker_mask = mrsi_mask;
%             for z = 1 : size(mrsi_mask,3)
%                 for y = 1 : 2: size(mrsi_mask,2)
%                     checker_mask(1:2:end,y,z) = 2;
%     
%                 end
%                 for y = 2 : 2: size(mrsi_mask,2)
%                     checker_mask(2:2:end,y,z) = 2;
%                 end
%     
%             end
%             checker_mask = checker_mask.*mrsi_mask;
%             checker_mask = checker_mask/2;
%             MRSImaskFileOut            = fullfile(MRSImaskPath,['LICheck_slice_' num2str(rr)' MRSImaskExt]); 
%             vol_mask_mrsi.fname = MRSImaskFileOut;
%             vol_mask_mrsi = spm_write_vol(vol_mask_mrsi,checker_mask);
%     
%             num_mask = mrsi_mask;
%             for z = 1 : size(mrsi_mask,3)
%                 vox =1;
%                 for y = 1 : size(mrsi_mask,2)
%                     for x = 1 : size(mrsi_mask,1)
%                         if mrsi_mask(x,y,z)
%                             num_mask(x,y,z) = vox;
%                             vox = vox +1;
%                         end
%                     end
%                 end
%     
%             end
%             num_mask = num_mask.*mrsi_mask;
%             num_mask = num_mask/(vox-1);
%             MRSImaskFileOut            = fullfile(MRSImaskPath,['LINum_slice_' num2str(rr)' MRSImaskExt]); 
%             vol_mask_mrsi.fname = MRSImaskFileOut;
%             vol_mask_mrsi = spm_write_vol(vol_mask_mrsi,num_mask);
%         end
    
        % Store voxel centre for output figure
        voxel_ctr(:,:,rr) = [lr_off ap_off cc_off(rr,1)];
    end
end
if exist('vol_mask_out','var')
    vol_mask = vol_mask_out;
end
if exist('vol_mask_out_mrsi','var')
    vol_mask_mrsi = vol_mask_out_mrsi;
else
    vol_mask_mrsi = [];
end
% Reactivate MATLAB warnings
warning('on','MATLAB:nearlySingularMatrix');
warning('on','MATLAB:qhullmx:InternalWarning');

end


function realignT1MRSI(T1file,pad)
V = spm_vol(T1file);
vol = spm_read_vols(V);
vol_pad = padarray(vol,[pad pad],0,'both');
V_pad = V;
V_pad.mat(1,4) = V_pad.mat(1,4)-(pad*1.000);
V_pad.mat(2,4) = V_pad.mat(2,4)-(pad*1.0002);
% V_pad.mat(3,4) = V_pad.mat(3,4)-(1.0*1.0002);
V_pad.fname = strrep(V.fname,'.nii','_pad.nii');
V_pad.dim = size(vol_pad);
V_pad=spm_write_vol(V_pad,vol_pad);



matlabbatch{1}.spm.spatial.realign.estwrite.data = {
                                                    {[V_pad.fname ',1']},
                                                    {[V.fname ',1']}
                                                    }';
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = 2;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

spm_jobman('run',matlabbatch);

end

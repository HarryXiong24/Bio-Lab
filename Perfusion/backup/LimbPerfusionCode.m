 % addpath 'Z:\Alireza\limb\addpath_code'));

%% Load paths
ROOT = 'Z:\Alireza\limb\Limb_NEW_Project\4-19-23';
ACQ = 'Flow_130\ACQ1';
path = [ROOT '/' ACQ ];
register_path =  [ROOT '/' ACQ '/REGISTERED/'];

% Generate MAT file for V2            
gen_mat(path);
myMAT = [path '/' '/MAT/'];
movefile(myMAT, register_path)

mask_whole_limb_load_path =  [ROOT '/' ACQ '/SEGMENT_dcm/'];
%% Rest
 mask_limb_path = [ROOT '/' ACQ '/SEGMENT_dcm/Limb_dcm'];   
 Limb_segment = ImportDICOMSequence(mask_limb_path); % 80 +_ 60
 Limb_segment(Limb_segment < -1000) = 0;
 Limb_segment = flipdim(Limb_segment,3);
 Whole_Limb_BW = logical(Limb_segment);
% Whole_Limb_BW(:,:,1:180)=0;
 
 save( [mask_whole_limb_load_path '/WHOLE_LIMB.mat'], 'Whole_Limb_BW');
 mask_whole_limb_path = [mask_whole_limb_load_path '/WHOLE_LIMB.mat'];

 %% Assignment

% fullMYO = AssignLIMB([ROOT], [ROOT '/' 'VESSELS_dcm'],  false, ['\SEGMENT_dcm\WHOLE_LIMB.mat'] );  

%  % Erode vessel segmentation - AIF
FA_segment = ImportDICOMSequence([ROOT '/' ACQ '/SEGMENT_dcm/FA_dcm']);  
FA_segment(FA_segment < -1000) = 0;
FA_segment = flipdim(FA_segment,3);
FA_segment_BW = logical(FA_segment);

FA_segment_mask = zeros(size(FA_segment_BW));
image_size = size(FA_segment_BW);
structure_element = strel('disk' ,1,8);

 for  i = 1:image_size(3)

    FA_segment_mask(:,:,i) = imerode(FA_segment_BW(:,:,i),structure_element); 
 end 
 
save( [[ROOT '/' ACQ '/SEGMENT_dcm/'] '/FA_dcm.mat'], 'FA_segment_mask');

%% PERFUSION1
params.xlsx_path = 'Z:\Alireza\Limb_NEW_Project\4-19-23\Flow_130\ACQ1\Results.xlsx';
params.tissue_rho = 1.053;         % tissue deensity : g/cm^2
params.aif_path = [ROOT '/' ACQ '/SEGMENT_dcm/FA_dcm'];   
params.vol_idx = [1 2];  

%pro
 delta_time =  genMAT_BT(path);
params.delta_time = [delta_time];
time_vec_SS = loadMAT([ROOT '/' ACQ '/time_vector_SureStart.mat']);
time_vec_SS = time_vec_SS - time_vec_SS(1)*ones(length(time_vec_SS),1) ;
time_vec_fit = [time_vec_SS; delta_time + time_vec_SS(end)];   % BT time vec +  V2 time
save([ROOT '/' ACQ '/time_vec_GAMMA.mat'], 'time_vec_fit');
%generate_TAC_from_SureStart(path);
aif_vec =loadMAT([ROOT '/' ACQ '/REGISTERED/FA_dcm_AIF_VolumePerfusion.mat']);
aif_vec_SS =loadMAT([ROOT '/' ACQ '/SureStart.mat']);
aif_vec_fit = [aif_vec_SS; aif_vec(2)];   % BT aif vec +  V2 aif
save([ROOT '/' ACQ '/FA_dcm_AIF_GAMMA.mat'], 'aif_vec_fit');
% 

%Specify the AIF, TIME, and MYO VEC path
params.aif_path =  [ROOT '/' ACQ '/FA_dcm_AIF_GAMMA.mat'];
params.time_vec_path = [ROOT '/' ACQ '/time_vec_GAMMA.mat'];
% params_v1_trigger_hu = 60;   % delta HU for trigger

params.input_conc_type = 'GAMMA';
params.v2_trigger_dt = delta_time;


% % Check dimensions
% mat_file  = loadMAT([register_path 'mat\01.mat']);
% mat_size = size(mat_file);
% seg_size = size(Whole_Limb_BW);
% fa_file = loadMAT([ROOT '/' ACQ '/SEGMENT_dcm/FA_dcm.mat']);
% fa_size = size(fa_file);
% 
% if mat_size(3) < seg_size(3)
%     seg_resize = zeros(mat_size);
%     whole_limb_bw = Whole_Limb_BW(:, :, 1:mat_size(3));
%     save( [mask_whole_limb_load_path '/whole_limb_resize.mat'], 'whole_limb_bw');
%     mask_whole_limb_path = [mask_whole_limb_load_path '/whole_limb_resize.mat'];
% end
% if mat_size(3) < fa_size(3)
%     fa_resize = zeros(mat_size);
%     fa_bw = fa_file(:, :, 1:mat_size(3));
%     save([ROOT '/' ACQ '/SEGMENT_dcm/fa_resize.mat'], 'fa_bw');
%     params.aif_path  = [ROOT '/' ACQ '/SEGMENT_dcm/fa_resize.mat'];
% end

% Save
mat_file  = loadMAT([register_path 'mat\02.mat']);
% fullMYO = loadMAT([ROOT '/' ACQ '\ASSIGN_DCM\limb_bed_FULL.mat']);
% limb_tissue_bw = zeros(size(mat_file));
% fullMYO_resize = fullMYO(:,:,1:size(mat_file,3));
% limb_tissue_bw(fullMYO_resize == 1) = 1;

mask_whole_limb_path = [mask_whole_limb_load_path 'WHOLE_LIMB.mat'];
% seg_path =  [mask_whole_limb_load_path '/limb_tissue.mat'];
params.myo_tac_path =  mask_whole_limb_path;

% save([seg_path], 'limb_tissue_bw');

 [perf, perf_maps, ~, flow, flow_maps] = SingleVolumePerfusion_beta(register_path, mask_whole_limb_path, params);
% 
% SingleVolumePerfusion_beta
% VolumePerfusion

% limb_flow = sum(flow_map(logical(limb_tissue_bw)))/numel(flow_map(logical(limb_tissue_bw)));
% 
% limb_flow2 = numel(flow_map(logical(limb_tissue_bw)))/numel(logical(fullMYO)) .* flow.whole_organ;
perf_map = perf_maps.whole_organ;
save([ROOT '/' ACQ '/perf_map.mat'], 'perf_map')
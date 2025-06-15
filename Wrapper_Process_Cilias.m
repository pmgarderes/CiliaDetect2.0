%% Detect cilia in nd2 stack 
% cilia are assumed to be in the 3rd channel
% this is a wrapper file for the semi automated detection of cilia
% author pmgarderes@gmail.com, ( and chatgpt 4o)
  
%% Full GUI
% Full_GUI

%% Prepare a bacth of reduced files: 
% foldername = 'D:\NIkon SoRA\IH25bis_VASP exp2-3_11-10-23' ; % 'D:\Image Coralie\IH19_pVASP_test2_7-24-23\SelectedND2\';
% DSfactor = 25;
% batch_downsample_nd2_folder(foldername, DSfactor, true);

%% file to be processed
filename  = 'C:\Data\Images_Coralie\74617_Sim1creMC4RgfpOb+-AAVmScarlet-ARL13b-IH4s1x60PVli.nd2';
% filename = 'D:\NIkon SoRA\IH25bis_VASP exp2-3_11-10-23\reduced_stack\79381_#11_IH25_s1_x60_PVNl-low_HOECHST-pVASP-mScarlet-ADCY3_reduced.mat';% 'C:\Users\calex\Box\Nikon SoRa_Coralie\IH19_pVASP_test2_7-24-23\tiff\MAX\MAX_76467_IH19_s2_x60_PVNli_HEOCHST-pVASP-mScarlet-ADCY3.tif';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% -- List of all parameters  --
% Downsampling factor for averaging the Z-stack 
params.load_reduced =1; 
params.DSfactor = 25;  % 25
params.reload_previous_Detection = 0; % 1 or 0 % use 0 to overwrite previous detection

% parameters for the GUI (ROI detection) 
params.windowSize = 100;  % Size of the ROI window
params.minArea = 10;     % Minimum area of cilia
params.maxArea = 1500;   % Maximum area of cilia
params.minElongation = 2.0;  % Minimum elongation ratio
params.minThinness = 2.0;  % Try values between 1.5 and 3 % Minimum thinness ratio\
params.adaptiveSensitivity = 0.4; % Try values between 0.3 and 0.7 % Sensitivity for adaptive thresholding
params.maxroiOverlap = 0.8; % DO NOT CHANGE 0.5 is 50% roi overlap ; above this number, only one roi is kept

% Spread for background mask dilation ( in pixel) 
params.backgroundSpread = 10;        % Spread for background mask dilation

% parameter quantificaiton 
params.fluorescenceMode ='sum' ;  %  'mean' or 'sum' 

%% Half GUI !!
% Half_GUI(imgStack, params, uniqueDetections, filename);

%% Load data  +- previous detection file 
addpath(genpath('.\'))
tic
% first load the images, downsampled by averaging  
if params.load_reduced==0 
    [imgStack, metadata] = load_nd2_image_downsampled(filename, params);   else ;    load(filename) ; end
if params.reload_previous_Detection 
    uniqueDetections = load_cilia_detections(filename, ciliaDetections, uniqueDetections);   else;     uniqueDetections = [];  end
toc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% start the GUI to detect rois ! 
close all
view_nd2_with_cilia_gui(imgStack, params, uniqueDetections);


% uniqueDetections contains the deduplicated entries
uniqueDetections = deduplicate_cilia_detections2(ciliaDetections, params.maxroiOverlap);

% save the detected cilias ! 
 [nd2Dir, baseName, ~] = fileparts(filename); 
save_cilia_detections(filename, ciliaDetections, uniqueDetections);
% or load them if you already did this 
 
% visualize mask 
visualize_cilia_masks(imgStack, uniqueDetections, params);

%  quantify over the gran average mask
results = quantify_cilia_fluorescence2(imgStack, uniqueDetections, params);


% Convert results to a table &  Write the table to an Excel file
resultsTable = struct2table(results);
outputFilename = fullfile([fileparts(filename), filesep ,  'MatlabQuantif', filesep,   baseName 'cilia_quantification_results.xlsx'] );
writetable(resultsTable, outputFilename);
% save the xls for statistical comparison ! 


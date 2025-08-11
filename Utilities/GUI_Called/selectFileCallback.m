function selectFileCallback(hObject, ~)
handles = guidata(hObject);  % Retrieve the handles structure
if isfield(handles, 'workingDir')
    initialDir = handles.workingDir;  % Use the stored working directory
else
    initialDir = pwd;  % Default to current directory if not set
end
[fileName, filePath] = uigetfile({'*.*', 'All Files'}, 'Select a File', initialDir);
if isequal(fileName, 0)
    disp('File selection canceled.');
    return;
end
fullFileName = fullfile(filePath, fileName);
disp(['Selected file: ', fullFileName]);
% TODO: Add code here to process the selected file
load(fullFileName)
% Upddate working dir handle
handles.workingDir = filePath;  % Store the selected directory
% Update variables
handles.stack = imgStack; % is loaded from the filename
handles.numChannels = numel(imgStack);
handles.currentChannel = 1;
handles.numSlices = size(imgStack{1}, 3);
handles.currentZ = 1;
handles.filePath = filePath;
handles.fileName = fileName; 

handles.LW_by_channel = nan(handles.numChannels,2);  % [L W] per channel

% autmatically load cilias

fullFileName = fullfile(handles.filePath, handles.fileName);
% Extract directory and base name
[nd2Dir, baseName, ~] = fileparts(fullFileName);
% Construct the save filename
saveFileName = [baseName '_cilia_detections.mat'];
savePath = fullfile([nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName]);
% Call the external function to LOAD detections
if exist(savePath)
    load(savePath,'ciliaDetections');  
    handles.ciliaDetections = ciliaDetections;
end

% Update the handles structure
guidata(hObject, handles);


% Refresh the display or perform additional updates as needed
[clim] = updateDisplay(hObject);
handles.clim = clim;
handles.windowLevel = mean([clim(1) clim(2)]);
handles.windowWidth = clim(2) - clim(1);


msg = sprintf('WAIT, Currently redrawing cilia detections .');  % or any dynamic message
set(handles.status, 'String', msg);
drawnow;  % forces immediate GUI update

handles = redrawAllDetections(handles);
guidata(hObject, handles);
updateCiliaCount(hObject);
msg = sprintf('All cilia detections have been redrawn.');  % or any dynamic message
set(handles.status, 'String', msg);
drawnow;  % forces immediate GUI update



end
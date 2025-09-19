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

set(handles.WAITstatus, 'String', 'WAIT');
msg = sprintf(' ... Loading reduced file .');  % or any dynamic message
updateStatusText(handles.status,  msg, '');

% erase status operation
updateStatusText(handles.status_Operation, '', '');


% disp(['Selected file: ', fullFileName]);
% TODO: Add code here to process the selected file
try
% %     % Try to load the file
% %     S = load(fullFileName);
% %     % (optional) check that expected variables exist
% %     if ~isfield(S,'imgStack')
% %         error('The selected file does not contain variable "imgStack".');
% %     end


    load(fullFileName)
    % Upddate working dir handle
    handles.workingDir = filePath;  % Store the selected directory
    % Update variables
    handles.stack = imgStack; % is loaded from the filename
    if exist('metadata')
        handles.metadata = metadata; % is loaded from the filename
        msgFile = 'Stack and Metadata loaded';
    else
        msgFile = 'Stack but not Metadata loaded';
        handles.metadata = [];
    end
    handles.numChannels = numel(imgStack);
    handles.currentChannel = 1;
    handles.numSlices = size(imgStack{1}, 3);
    handles.currentZ = 1;
    handles.filePath = filePath;
    handles.fileName = fileName;

    handles.LW_by_channel = nan(handles.numChannels,2);  % [L W] per channel

    % Erase previous cilia detection
    %     clearDetectionsCallback(hObject)
    if 1
        
        % Delete all ROI graphical objects
        if isfield(handles, 'roiHandles') && ~isempty(handles.roiHandles)
            for i = 1:numel(handles.roiHandles)
                for h = handles.roiHandles{i}
                    if isvalid(h)
                        delete(h);
                    end
                end
            end
        end
        
        % Clear the detections and ROI handles
        handles.ciliaDetections = {};
        handles.roiHandles = {};
        
        % Update the cilia count display
        updateCiliaCount(hObject);
        
        % erase autodetect tested popints
        % Delete any plotted red dots (they were not stored in roiHandles)
        ax = handles.ax;
        % Find objects with red marker '.' on this axis
        dots = findobj(ax, 'Type','line', 'Marker','.', 'Color',[1 0 0]);
        if ~isempty(dots)
            delete(dots);
        end
        % Reset the testedPoints table
        handles.testedPoints = table('Size',[0 8], ...
            'VariableTypes',{'double','double','double','double','double','double','logical','double'}, ...
            'VariableNames',{'x','y','z','intensity','area','elong','passed','channel'});
        
        
        % Save the updated handles structure
        guidata(hObject, handles);
    end
    
    
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


    msg = sprintf(' ... Redrawing cilia detections .');  % or any dynamic message
    % set(handles.status, 'String', msg);
    updateStatusText(handles.status, msgFile, msg);
    drawnow;  % forces immediate GUI update

    handles = redrawAllDetections(handles);
    guidata(hObject, handles);
    updateCiliaCount(hObject);

    set(handles.WAITstatus, 'String', '');
    msg = sprintf('All cilia detections have been redrawn.');  % or any dynamic message
    % set(handles.status, 'String', msg);
    updateStatusText(handles.status, msgFile, msg);
    drawnow;  % forces immediate GUI update

catch
    % If loading fails, show user-friendly error in GUI
    set(handles.WAITstatus, 'String', 'ERROR');
    msg = sprintf(' ... Failed to load file, did you pick a _reduced.mat file ?');  % or any dynamic message
    updateStatusText(handles.status, '', msg);

%     errMsg = sprintf('Failed to load file: %s\nReason: %s', fullFileName, ME.message);
%     updateStatusText(handles.status, '', errMsg);
% 
%     % Also show modal error dialog
%     errordlg(errMsg, 'File Load Error');
end


end
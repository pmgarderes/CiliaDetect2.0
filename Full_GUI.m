function Full_GUI()
% stack: cell array of {Y x X x Z} images per channel
% params: struct with detection parameters:
%   .windowSize, .minArea, .maxArea, .minElongation
close all
addpath(genpath('.'))

%% -- List of defaults  parameters  --
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

% Parameters for aumated detection 
params.tophatRadius = 5;
params.maxEccentricity = 1;
params.minEccentricity = 0.8;

% parameter quantificaiton
params.fluorescenceMode ='sum' ;  %  'mean' or 'sum'
stack= {ones(1,1,1)};
uniqueDetections= [] ;



adaptiveSensitivity = params.adaptiveSensitivity;
numChannels = numel(stack);
currentChannel = 1;
numSlices = size(stack{1}, 3);
currentZ = 1;

% Store detections
ciliaDetections = {};
roiHandles = {};  % One per detection

% Create fullscreen figure
fig = figure('Name', 'GUI + Cilia Detection', ...
    'WindowKeyPressFcn', @keyHandler, ...
    'Color', 'k', ...
    'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1]);

handles.fig = fig;

ax = axes('Parent', fig);
handles.ax = ax;

% if ciliaDetections is already defined
ciliaDetections = uniqueDetections;

%% Define control buttons
% Set working folder and
selectFileBtn = uicontrol('Style', 'pushbutton', ...
    'String', 'Select File', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.8, 0.1, 0.05], ...
    'Callback', @selectFileCallback);
%
uicontrol('Style', 'pushbutton', ...
    'String', 'Set Working Dir', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.7, 0.1, 0.05], ...
    'Callback', @setWorkingDirCallback);

% Save detection
uicontrol('Style', 'pushbutton', ...
    'String', 'Save Detections', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.6, 0.1, 0.05], ...
    'Callback', @saveDetectionsCallback);

% Visualize Masks
uicontrol('Style', 'pushbutton', ...
    'String', 'Visualize Masks', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.53, 0.1, 0.05], ... % Adjusted position below the "Save Detections" button
    'Callback', @(hObject, ~) visualizeMasksCallback(hObject));

% Quantify fluorescence ( and save
uicontrol('Style', 'pushbutton', ...
    'String', 'Quantify & Save Fluorescence', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.46, 0.1, 0.05], ... % Adjusted position below the "Visualize Masks" button
    'Callback', @(hObject, ~) quantifyAndSaveCallback(hObject));

% Create 'Auto-Detect Seeds' push button
uicontrol('Style', 'pushbutton', ...
          'String', 'Auto-Detect Seeds', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.4, 0.1, 0.05], ...  % Adjust position as needed
          'Callback', @autoDetectSeedsCallback);
      
      
handles.EditParams =uicontrol('Style', 'pushbutton', ...
          'String', 'Edit Parameters', ...
          'Units', 'normalized', ...
          'Position', [0.01, 0.05, 0.2, 0.05], ...
          'Callback', @(hObject, event) editParamsCallback(hObject)); % 'Callback', @(hObject, ~) editParamsCallback(hObject); %
      
handles.clearButton = uicontrol('Style', 'pushbutton', ...
    'String', 'Clear Detections', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.15, 0.2, 0.05], ... % Adjust position and size as needed
    'Callback', @(hObject, ~) clearDetectionsCallback(hObject));

%% Add the shortcut instruction on the left
shortcutText = [ ...
    'Keyboard Shortcuts:', newline, ...
    '--------------------------', newline, ...
    '[Space]   - Add cilium at mouse click', newline, ...
    '[→ / ←]   - Switch channel', newline, ...
    '[↑ / ↓]   - Navigate Z-slices', newline, ...
    '[+ / -]   - Adjust sensitivity', newline, ...
    '[u]       - Undo last detection', newline, ...
    '[s]       - Suppress nearest ROI', newline, ...
    '[m]       - Merge two nearest ROIs', newline, ...
    '[r]       - Redraw all ROIs', newline, ...
    '[q]       - Quit application' ...
    ];
shortcutPanel = uicontrol('Style', 'text', ...
    'String', shortcutText, ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.5, 0.2, 0.4], ...  % Adjust position and size as needed
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left');


imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', ax);
colormap('gray');
axis image off;

title(ax, sprintf('Channel %d | Z-plane %d/%d', ...
    currentChannel, currentZ, numSlices), ...
    'Color', 'w', 'FontSize', 18);

% Create a text label for the cilia count
handles.countLabel = uicontrol('Style', 'text', ...
    'String', 'Cilia Count: 0', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.2, 0.2, 0.4], ...
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left');

% Create axes and image display
handles.ax = axes('Parent', fig);
handles.imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', handles.ax);
colormap('gray');
axis image off;

% Store other relevant data
handles.stack = stack;
handles.currentChannel = currentChannel;
handles.currentZ = currentZ;
handles.numSlices = numSlices;
handles.params = params;
handles.ciliaDetections = ciliaDetections;
handles.roiHandles = roiHandles;
% handles.countLabel

% Save the handles structure
guidata(fig, handles);


% Key handler
    function keyHandler(hObject, event)
        handles = guidata(hObject);  % Retrieve the handles structure
       params = handles.params;
        switch event.Key
            case 'add'  % '+' key on main keyboard
                handles.adaptiveSensitivity = min(handles.adaptiveSensitivity + 0.05, 1.0);
                fprintf('Increased sensitivity: %.2f\n', handles.adaptiveSensitivity);
            case 'subtract'  % '-' key on main keyboard
                handles.adaptiveSensitivity = max(handles.adaptiveSensitivity - 0.05, 0.05);
                fprintf('Decreased sensitivity: %.2f\n', handles.adaptiveSensitivity);
            case 'rightarrow'
                handles.currentChannel = mod(handles.currentChannel, handles.numChannels) + 1;
                guidata(hObject, handles);
                updateDisplay(hObject);
                disp(handles.currentChannel);
            case 'leftarrow'
                handles.currentChannel = mod(handles.currentChannel - 2, handles.numChannels) + 1;
                guidata(hObject, handles);
                updateDisplay(hObject);
            case 'uparrow'
                handles.currentZ = min(handles.currentZ + 1, handles.numSlices);
                guidata(hObject, handles);
                updateDisplay(hObject);
            case 'downarrow'
                handles.currentZ = max(handles.currentZ - 1, 1);
                guidata(hObject, handles);
                updateDisplay(hObject);
            case 'u'  % Undo last detection
                if ~isempty(handles.ciliaDetections)
                    % Remove detection
                    handles.ciliaDetections(end) = [];
                    
                    % Delete graphical objects
                    lastHandles = handles.roiHandles{end};
                    for h = lastHandles
                        if isvalid(h)
                            delete(h);
                        end
                    end
                    handles.roiHandles(end) = [];
                    
                    disp('Last detection undone.');
                else
                    disp('No detections to undo.');
                end
            case 'space'
                % Get mouse location in image coordinates
                cp = get(handles.ax, 'CurrentPoint');
                x = round(cp(1,1));
                y = round(cp(1,2));
                
                % Validate position
                sz = size(handles.stack{handles.currentChannel});
                if x < 1 || x > sz(2) || y < 1 || y > sz(1)
                    disp('Click was out of bounds. Ignoring.');
                    return;
                end
                
                % Get current image
                currentFrame = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
                
                % Run cilia detection
                mask = detect_cilium_from_seed2(currentFrame, [x, y], handles.params, handles.params.adaptiveSensitivity);
                disp(['area ' num2str(sum(mask(:)))]);
                
                % Save result
                detectionStruct = struct( ...
                    'channel', handles.currentChannel, ...
                    'zplane', handles.currentZ, ...
                    'click', [x, y], ...
                    'mask', mask);
                handles.ciliaDetections{end+1} = detectionStruct;
                
                % Overlay boundary of the new mask
                hold(handles.ax, 'on');
                
                updateCiliaCount(hObject);
                
                % Find boundary points
                boundaries = bwboundaries(mask);
                roiGroup = gobjects(0); % Collect handles for this detection
                for k = 1:length(boundaries)
                    B = boundaries{k};
                    h = plot(handles.ax, B(:,2), B(:,1), 'g-', 'LineWidth', 1.5);
                    roiGroup(end+1) = h;
                end
                hPoint = plot(handles.ax, x, y, 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                roiGroup(end+1) = hPoint;
                % Store handles and detection
                
                handles.roiHandles{end+1} = roiGroup;
            case 's'  % 's' for select/suppress
                % Get current mouse position
                cp = get(handles.ax, 'CurrentPoint');
                xClick = cp(1,1);
                yClick = cp(1,2);
                
                % Find nearest ROI
                [selectedIdx, minDistance] = findNearestROI(xClick, yClick, handles.ciliaDetections);
                
                if isempty(selectedIdx) || minDistance > 20
                    disp('No ROI close enough to be selected.');
                else
                    fprintf('Suppressing ROI #%d (%.2f pixels away)\n', selectedIdx, minDistance);
                    
                    % Delete ROI graphics
                    if ~isempty(handles.roiHandles{selectedIdx})
                        for h = handles.roiHandles{selectedIdx}
                            if isvalid(h)
                                delete(h);
                            end
                        end
                    end
                    
                    % Remove from detections
                    handles.ciliaDetections(selectedIdx) = [];
                    handles.roiHandles(selectedIdx) = [];
                    
                    disp('ROI suppressed.');
                    updateCiliaCount(hObject);
                end
            case 'r'  % 'r' for refresh/redraw
                % Clear existing ROI plots
                for i = 1:numel(handles.roiHandles)
                    for h = handles.roiHandles{i}
                        if isvalid(h)
                            delete(h);
                        end
                    end
                end
                handles.roiHandles = {};
                
                % Redraw all cilia detections
                hold(handles.ax, 'on');
                for i = 1:numel(handles.ciliaDetections)
                    det = handles.ciliaDetections{i};
                    mask = det.mask;
                    zplane = det.zplane;
                    channel = det.channel;
                    
                    % Find the contour of the mask
                    B = bwboundaries(mask);
                    roiGroup = gobjects(0); % Collect handles for this detection
                    for k = 1:length(B)
                        boundary = B{k};
                        h = plot(handles.ax, boundary(:,2), boundary(:,1), 'g-', 'LineWidth', 1.5);
                        roiGroup(end+1) = h;
                    end
                    % Plot the original click point
                    hPoint = plot(handles.ax, det.click(1), det.click(2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                    roiGroup(end+1) = hPoint;
                    
                    % Store handles
                    handles.roiHandles{end+1} = roiGroup;
                    updateCiliaCount(hObject);
                end
                hold(handles.ax, 'off');
                disp('All cilia detections have been redrawn.');
            case 'm'  % 'm' for merge
                % Get current mouse position
                cp = get(handles.ax, 'CurrentPoint');
                xClick = cp(1,1);
                yClick = cp(1,2);
                
                % Find the two closest ROIs to the click position
                [idx1, idx2] = findTwoClosestROIs(xClick, yClick, handles.ciliaDetections);
                
                if isempty(idx1) || isempty(idx2)
                    disp('Not enough ROIs to merge.');
                    return;
                end
                
                % Retrieve the masks
                mask1 = handles.ciliaDetections{idx1}.mask;
                mask2 = handles.ciliaDetections{idx2}.mask;
                
                % Check for overlap (or at least proximity )
                overlapMask = mask1 & mask2;
                if any(overlapMask(:))
                    proceedToMerge = true;
                else
                    % Calculate minimum distance between ROI boundaries
                    B1 = bwboundaries(mask1);
                    B2 = bwboundaries(mask2);
                    boundary1 = B1{1};
                    boundary2 = B2{1};
                    D = pdist2(boundary1, boundary2);
                    minDist = min(D(:));
                    proximityThreshold = 5;  % Define your threshold here
                    proceedToMerge = minDist <= proximityThreshold;
                end
                
                if proceedToMerge
                    % Merge the masks
                    mergedMask = mask1 | mask2;
                    
                    % Create new detection
                    newDetection = struct( ...
                        'channel', handles.ciliaDetections{idx1}.channel, ...
                        'zplane', handles.ciliaDetections{idx1}.zplane, ...
                        'click', round((handles.ciliaDetections{idx1}.click + handles.ciliaDetections{idx2}.click)/2), ...
                        'mask', mergedMask);
                    
                    % Remove old detections and add new one
                    idxToRemove = sort([idx1, idx2], 'descend');
                    for i = 1:length(idxToRemove)
                        % Delete ROI graphics
                        if ~isempty(handles.roiHandles{idxToRemove(i)})
                            for h = handles.roiHandles{idxToRemove(i)}
                                if isvalid(h)
                                    delete(h);
                                end
                            end
                        end
                        % Remove from detections
                        handles.ciliaDetections(idxToRemove(i)) = [];
                        handles.roiHandles(idxToRemove(i)) = [];
                    end
                    
                    % Add new detection
                    handles.ciliaDetections{end+1} = newDetection;
                    % (Optional) Add code here to display the new ROI and update roiHandles
                    
                    % Update display and count
                    updateDisplay(handles);
                    updateCiliaCount(hObject);
                    disp('Merged two closest ROIs.');
                else
                    disp('Selected ROIs are not overlapping or within the proximity threshold.');
                end
            case {'escape', 'q'}
                close(handles.fig);
        end
        
        guidata(hObject, handles);  % Save the updated handles structure
    end


% On close: save detections to base workspace
set(fig, 'CloseRequestFcn', @closeHandler);
    function closeHandler(~, ~)
        assignin('base', 'ciliaDetections', ciliaDetections);
        delete(fig);
        disp('Cilia detections saved to variable: ciliaDetections');
    end


end

%% HELPER FUNCTION 



function [selectedIdx, minDistance] = findNearestROI(xClick, yClick, ciliaDetections)
minDistance = Inf;
selectedIdx = [];

for i = 1:numel(ciliaDetections)
    det = ciliaDetections{i};
    clickPos = det.click;  % det.click = [x, y]
    
    dist = sqrt( (xClick - clickPos(1))^2 + (yClick - clickPos(2))^2 );
    
    if dist < minDistance
        minDistance = dist;
        selectedIdx = i;
    end
end
end

function [idx1, idx2, minDist] = findTwoClosestROIs(xClick, yClick, ciliaDetections)
% Initialize
numROIs = numel(ciliaDetections);
if numROIs < 2
    idx1 = [];
    idx2 = [];
    minDist = [];
    return;
end

% Extract ROI centroids
centroids = zeros(numROIs, 2);
for i = 1:numROIs
    centroids(i, :) = ciliaDetections{i}.click;  % [x, y]
end

% Compute distances from click to each centroid
distances = sqrt((centroids(:,1) - xClick).^2 + (centroids(:,2) - yClick).^2);

% Find the index of the closest ROI
[~, idx1] = min(distances);

% Exclude the closest ROI and find the next closest
distances(idx1) = inf;
[minDist, idx2] = min(distances);
end

% % % %% BUtton helper functions
% % % function updateCiliaCount(hObject)
% % %     % Retrieve the handles structure
% % %     handles = guidata(hObject);
% % % 
% % %     % Calculate the number of cilia detections
% % %     count = numel(handles.ciliaDetections);
% % % 
% % %     % Update the count label in the GUI
% % %     set(handles.countLabel, 'String', sprintf('Cilia Count: %d', count));
% % % 
% % %     % Save the updated handles structure
% % %     guidata(hObject, handles);
% % % end


% % function selectFileCallback(hObject, ~)
% % handles = guidata(hObject);  % Retrieve the handles structure
% % if isfield(handles, 'workingDir')
% %     initialDir = handles.workingDir;  % Use the stored working directory
% % else
% %     initialDir = pwd;  % Default to current directory if not set
% % end
% % [fileName, filePath] = uigetfile({'*.*', 'All Files'}, 'Select a File', initialDir);
% % if isequal(fileName, 0)
% %     disp('File selection canceled.');
% %     return;
% % end
% % fullFileName = fullfile(filePath, fileName);
% % disp(['Selected file: ', fullFileName]);
% % % TODO: Add code here to process the selected file
% % load(fullFileName)
% % % Upddate working dir handle
% % handles.workingDir = filePath;  % Store the selected directory
% % % Update variables
% % handles.stack = imgStack; % is loaded from the filename
% % handles.numChannels = numel(imgStack);
% % handles.currentChannel = 1;
% % handles.numSlices = size(imgStack{1}, 3);
% % handles.currentZ = 1;
% % 
% % % Update the handles structure
% % guidata(hObject, handles);
% % 
% % % Refresh the display or perform additional updates as needed
% % updateDisplay(hObject);
% % 
% % end

% % function setWorkingDirCallback(hObject, ~)
% % handles = guidata(hObject);  % Retrieve the handles structure
% % selectedDir = uigetdir(pwd, 'Select Working Directory');
% % if selectedDir ~= 0
% %     handles.workingDir = selectedDir;  % Store the selected directory
% %     guidata(hObject, handles);         % Save the updated handles structure
% %     disp(['Working directory set to: ', selectedDir]);
% % else
% %     disp('Directory selection canceled.');
% % end
% % end


% % function saveDetectionsCallback(hObject, ~)
% % handles = guidata(hObject);  % Retrieve the handles structure
% % 
% % fullFileName = fullfile(filePath, fileName);
% % 
% % % Extract directory and base name
% % [nd2Dir, baseName, ~] = fileparts(fullFileName);
% % 
% % % Construct the save filename
% % saveFileName = [baseName '_cilia_detections.mat'];
% % if ~isfolder([nd2Dir, filesep 'MatlabQuantif'])
% %     mkdir([nd2Dir, filesep 'MatlabQuantif']);
% % end
% % savePath = fullfile([nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName]);
% % % Call the external function to save detections
% % save_cilia_detections(fullFileName, ciliaDetections, uniqueDetections);
% % 
% % disp(['Cilia detections saved to ', fullFileName]);
% % end


% % function updateCiliaCount(hObject)
% % count = numel(ciliaDetections);
% % set(countLabel, 'String', sprintf('Cilia Count: %d', count));
% % end

% % function editParamsCallback(hObject)
% %     handles = guidata(hObject);  % Retrieve the handles structure
% %     newParams = openParamEditor(handles.params);  % Open the editor
% %     if ~isempty(newParams)
% %         handles.params = newParams;  % Update parameters
% %         guidata(hObject, handles);  % Save the updated handles structure
% %         disp('Parameters updated.');
% %     end
% % end

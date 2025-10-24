function Full_GUI()
% stack: cell array of {Y x X x Z} images per channel
% params: struct with detection parameters:
%   .windowSize, .minArea, .maxArea, .minElongation
close all
 addpath(genpath('.'))


%% Create fullscreen figure
fig = figure('Name', 'GUI + Cilia Detection', ...
    'WindowKeyPressFcn', @keyHandler, ...
    'Color', 'k', ...
    'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1]);

handles.fig = fig;

ax = axes('Parent', fig);
handles.ax = ax;


%% -- List of defaults  parameters  --


% initialize
stack= {ones(1,1,1)};
uniqueDetections= [] ;


% Downsampling factor for averaging the Z-stack
params = load_or_init_params();

adaptiveSensitivity = params.adaptiveSensitivity;
numChannels = numel(stack);
currentChannel = 1;
numSlices = size(stack{1}, 3);
currentZ = 1;

% Store detections
ciliaDetections = {};
roiHandles = {};  % One per detection



% if ciliaDetections is already defined
ciliaDetections = uniqueDetections;

%% Define control buttons

% Pre-processing many files
uicontrol('Style', 'pushbutton', ...
    'String', 'Preprocess (Downsample)', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.85, 0.12, 0.05], ...
    'Callback', @preprocessCallback);



% nd select file
selectFileBtn = uicontrol('Style', 'pushbutton', ...
    'String', 'Select File', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.75, 0.12, 0.05], ...
    'Callback', @selectFileCallback);

% Save detection
uicontrol('Style', 'pushbutton', ...
    'String', 'Save Detections', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.69, 0.1, 0.05], ...
    'Callback', @saveDetectionsCallback);

% Visualize Masks
uicontrol('Style', 'pushbutton', ...
    'String', 'Visualize Masks', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.63, 0.1, 0.05], ... % Adjusted position below the "Save Detections" button
    'Callback', @(hObject, ~) visualizeMasksCallback(hObject));

% Quantify fluorescence ( and save
uicontrol('Style', 'pushbutton', ...
    'String', 'Quantify & Save Fluorescence', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.57, 0.1, 0.05], ... % Adjusted position below the "Visualize Masks" button
    'Callback', @(hObject, ~) quantifyAndSaveCallback(hObject));

 %  % % % More automation group  %  % % % 

% nd select file
handles.EditParams =uicontrol('Style', 'pushbutton', ...
          'String', 'Tune parameters for shape detection', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.44, 0.12, 0.05], ...
          'Callback', @(hObject, event) ParametrizeCallback(hObject)); % 'Callback', @(hObject, ~) editParamsCallback(hObject); %

% recompute ROI from seeds with loaded/ new parameters
uicontrol('Style','pushbutton', ...
    'String','Recompute ROIs from current parameters', ...
    'Units','normalized', ...
    'Position',[0.85, 0.38, 0.12, 0.05], ...
    'Callback', @onRecomputeROIsButton);

% Create 'Auto-Detect Seeds' push button
uicontrol('Style', 'pushbutton', ...
          'String', 'Auto-Detect Seeds', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.32, 0.12, 0.05], ...  % Adjust position as needed
          'Callback', @autoDetectSeedsCallback);      




handles.EditParams =uicontrol('Style', 'pushbutton', ...
          'String', 'Edit any Parameters', ...
          'Units', 'normalized', ...
          'Position', [0.85, 0.12, 0.12, 0.05], ...
          'Callback', @(hObject, event) editParamsCallback(hObject)); % 'Callback', @(hObject, ~) editParamsCallback(hObject); %



handles.clearButton = uicontrol('Style', 'pushbutton', ...
    'String', 'Clear Detections', ...
    'Units', 'normalized', ...
    'Position', [0.85, 0.05, 0.12, 0.05], ... % Adjust position and size as needed
    'Callback', @(hObject, ~) clearDetectionsCallback(hObject));

%% Add the shortcut instruction on the left
shortcutText = [ ...
    'Keyboard Shortcuts:', newline, ...
    '--------------------------', newline, ...
    'ROI actions:', newline, ...
    '[Space]        - Add cilium at mouse click', newline, ...
    '[u]            - Undo last detection', newline, ...
    '[s]            - Suppress nearest ROI', newline, ...
    '[m]            - Merge two nearest ROIs', newline, ...
    '[r]            - Redraw all ROIs', newline, ...
    newline, ...
    'Navigation:', newline, ...
    '[→ / ←]        - Switch channel', newline, ...
    '[↑ / ↓]        - Navigate Z-slices', newline, ...
    newline, ...
    'Display adjustments:', newline, ...
    '[+ / -]        - Brightness up / down', newline, ...
    '[* / /]        - Increase / decrease contrast (numpad)', newline, ...
     newline, ...
    'Other:', newline, ...
    '[q]            - Quit application' ...
    ];

% Create a text label for the current operations
shortcutPanel = uicontrol('Style', 'text', ...
    'String', shortcutText, ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.05, 0.2, 0.4], ...  % Adjust position and size as needed
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left');
%% Add interacting text to inform the user 

 % dipslay interacting text - WAIT Status
handles.WAITstatus = uicontrol('Style','text', ...
  'Units','normalized', ...
  'Position',[0.01, 0.91, 0.25, 0.08], ...
  'BackgroundColor','k', ...
  'ForegroundColor','w', ...
  'FontSize',28, ...
  'HorizontalAlignment','left', ...
  'String','');  % start empty     

 % dipslay interacting text - status
handles.status = uicontrol('Style','text', ...
  'Units','normalized', ...
  'Position',[0.01, 0.8, 0.25, 0.10], ...
  'BackgroundColor','k', ...
  'ForegroundColor','w', ...
  'FontSize',12, ...
  'HorizontalAlignment','left', ...
  'String','');  % start empty     
      
 % dipslay interacting text - details of the operation
handles.status_Operation = uicontrol('Style','text', ...
  'Units','normalized', ...
  'Position',[0.01, 0.65, 0.25, 0.15], ...
  'BackgroundColor','k', ...
  'ForegroundColor','w', ...
  'FontSize',12, ...
  'HorizontalAlignment','left', ...
  'String','');  % start empty    

imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', ax);
colormap('gray');
axis image off;

% Create a text label for the cilia count
handles.countLabel = uicontrol('Style', 'text', ...
    'String', 'Cilia Count: 0', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.5, 0.2, 0.1], ...
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'FontSize', 16, ...
    'HorizontalAlignment', 'left');

% Create axes and image display
handles.ax = axes('Parent', fig);
handles.imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', handles.ax);
colormap('gray');
axis image off;

% % % Compute a robust initial window from percentiles
% % I = double(get(handles.imgHandle,'CData'));
% % lo = 0;% prctile(I(:),1);  
% % hi = 0; % prctile(I(:),99);
% % % Apply and freeze CLim (manual) so changing CData doesn't auto-rescale
% % caxis(handles.ax, [lo hi]);             % R2022a+; use caxis(handles.ax,[lo hi]) on older releases
% % set(handles.ax, 'CLimMode', 'manual');
% % % Store window/level in handles
% % handles.windowLevel = mean([lo hi]);   % brightness center
% % handles.windowWidth = max(hi-lo, eps); % contrast width; avoid 0
handles.wStepFrac  = 0.05;             % 5% step per key press (tweak to taste)
handles.clim = [0 0];

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
%             case 'add'  % '+' key on main keyboard
%                 handles.adaptiveSensitivity = min(handles.adaptiveSensitivity + 0.05, 1.0);
%                 fprintf('Increased sensitivity: %.2f\n', handles.adaptiveSensitivity);
%             case 'subtract'  % '-' key on main keyboard
%                 handles.adaptiveSensitivity = max(handles.adaptiveSensitivity - 0.05, 0.05);
%                 fprintf('Decreased sensitivity: %.2f\n', handles.adaptiveSensitivity);
            % ---------- Brightness (window LEVEL) ----------
            case 'add'        % '+' -> brighter
                handles.windowLevel = handles.windowLevel - handles.wStepFrac * handles.windowWidth;
                applyWindowLevel(handles);
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
            case 'subtract'   % '-'  -> darker
                handles.windowLevel = handles.windowLevel + handles.wStepFrac * handles.windowWidth;
                applyWindowLevel(handles);
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
            % ---------- Contrast  (window LEVEL) ----------
            case 'multiply'   % ']' -> increase contrast (narrower window)
                handles.windowWidth = handles.windowWidth * (1 - handles.wStepFrac);
                applyWindowLevel(handles);
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
            case 'divide'    % '[' -> decrease contrast (wider window)
                handles.windowWidth = handles.windowWidth * (1 + handles.wStepFrac);
                applyWindowLevel(handles);
                disp(handles.windowWidth)%
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
            case 'rightarrow'
                % save current channel's L/W before leaving
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];

                handles.currentChannel = mod(handles.currentChannel, handles.numChannels) + 1;

                % load slice
                img = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
                set(handles.imgHandle,'CData',img);

                % restore L/W if known, else initialize from robust stretch once
                LW = handles.LW_by_channel(handles.currentChannel,:);
                if all(isfinite(LW))
                    handles.windowLevel = LW(1);
                    handles.windowWidth = LW(2);
                else
                    I = double(img);
                    lo = prctile(I(:),0.1); hi = prctile(I(:),99.9);
                    handles.windowLevel = (lo+hi)/2;
                    handles.windowWidth = max(hi-lo, eps);
                    handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
                end
                applyLW(handles);
                title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
                    handles.currentChannel, handles.currentZ, handles.numSlices), ...
                    'Color', 'w', 'FontSize', 18);
                guidata(hObject, handles);

            case 'leftarrow'
                handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
                handles.currentChannel = mod(handles.currentChannel - 2, handles.numChannels) + 1;

                img = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
                set(handles.imgHandle,'CData',img);

                LW = handles.LW_by_channel(handles.currentChannel,:);
                if all(isfinite(LW))
                    handles.windowLevel = LW(1);
                    handles.windowWidth = LW(2);
                else
                    I = double(img);
                    lo = prctile(I(:),0.1); hi = prctile(I(:),99.9);
                    handles.windowLevel = (lo+hi)/2;
                    handles.windowWidth = max(hi-lo, eps);
                    handles.LW_by_channel(handles.currentChannel,:) = [handles.windowLevel, handles.windowWidth];
                end
                applyLW(handles);
                title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
                    handles.currentChannel, handles.currentZ, handles.numSlices), ...
                    'Color', 'w', 'FontSize', 18);
                guidata(hObject, handles);
            case 'uparrow'
                handles.currentZ = min(handles.currentZ + 1, handles.numSlices);
                % just swap the slice, keep same window
                img = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
                set(handles.imgHandle,'CData',img);
                applyLW(handles);   % same L/W across planes
                title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
                    handles.currentChannel, handles.currentZ, handles.numSlices), ...
                    'Color', 'w', 'FontSize', 18);
                guidata(hObject, handles);

            case 'downarrow'
                handles.currentZ = max(handles.currentZ - 1, 1);
                img = handles.stack{handles.currentChannel}(:,:,handles.currentZ);
                set(handles.imgHandle,'CData',img);
                applyLW(handles);
                title(handles.ax, sprintf('Channel %d | Z-plane %d/%d', ...
                    handles.currentChannel, handles.currentZ, handles.numSlices), ...
                    'Color', 'w', 'FontSize', 18);
                guidata(hObject, handles);
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
                    msg = sprintf('No ROI close enough to be selected.'); 
                    set(handles.status, 'String', msg);
                    drawnow;  % forces immediate GUI update
                else
%                     fprintf('Suppressing ROI #%d (%.2f pixels away)\n', selectedIdx, minDistance);
                    msg = sprintf('Suppressing ROI #%d (%.2f pixels away)\n', selectedIdx, minDistance);      set(handles.status, 'String', msg);   drawnow;  % forces immediate GUI update
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

                    msg = sprintf('ROI suppressed.');  % or any dynamic message
                    set(handles.status, 'String', msg);
                    drawnow;  % forces immediate GUI update
                    updateCiliaCount(hObject);
                end
            case 'r'  % 'r' for refresh/redraw
                set(handles.WAITstatus, 'String', 'WAIT');
                msg = sprintf('WAIT, Currently redrawing cilia detections .');  % or any dynamic message
                set(handles.status, 'String', msg, 'FontSize', 12);
%                 set(handles.WAITstatus, 'String', 'WAIT', 'FontSize', 24);
                drawnow;  % forces immediate GUI update
                
                
                handles = redrawAllDetections(handles);
                guidata(hObject, handles);
                 updateCiliaCount(hObject);
                msg = sprintf('All cilia detections have been redrawn.');  % or any dynamic message
%                 set(handles.WAITstatus, 'String', 'WAIT');
                set(handles.WAITstatus, 'String', '');
                set(handles.status, 'String', msg, 'FontSize', 12);
                drawnow;  % forces immediate GUI update

            case 'm'  % 'm' for merge
                % Get current mouse position
                cp = get(handles.ax, 'CurrentPoint');
                xClick = cp(1,1);
                yClick = cp(1,2);
                
                % Find the two closest ROIs to the click position
                [idx1, idx2] = findTwoClosestROIs(xClick, yClick, handles.ciliaDetections);
                
                if isempty(idx1) || isempty(idx2)
                    msg = sprintf('Not enough ROIs to merge.');  % or any dynamic message
                    set(handles.status, 'String', msg);
                    drawnow;  % forces immediate GUI update
                    return;
                end
                
                % Retrieve the masks
                mask1 = handles.ciliaDetections{idx1}.mask;
                mask2 = handles.ciliaDetections{idx2}.mask;
                
                % Check for overlap (or at least proximity )
                overlapMask = mask1 & mask2;
                if any(overlapMask(:))
                    proceedToMerge = true;
                    proximityThreshold = 5; 
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
%                     mergedMask = mask1 | mask2;
                    
                    unionMask = mask1 | mask2;
                    % Attempt minimal bridge:
                    tmp = bwmorph(unionMask, 'bridge');
                    if ~isequal(tmp, unionMask)
                        mergedMask = tmp;
                    else
                        % Use closing to bridge small gap
                        se = strel('disk', proximityThreshold);
                        mergedMask = imclose(unionMask, se);
                    end
    
    
                    % Create new detection
                    newDetection = struct( ...
                        'channel', handles.ciliaDetections{idx1}.channel, ...
                        'zplane', handles.ciliaDetections{idx1}.zplane, ...
                        'click', round((handles.ciliaDetections{idx1}.click + handles.ciliaDetections{idx2}.click)/2), ...
                        'mask', mergedMask);
                    
                    % Remove old detections
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
                    
                    % plot the new detection 
                    B = bwboundaries(mergedMask);
                    roiGroup = gobjects(0); % Collect handles for this detection
                    for k = 1:length(B)
                        boundary = B{k};
                        h = plot(handles.ax, boundary(:,2), boundary(:,1), 'g-', 'LineWidth', 1.5);
                        roiGroup(end+1) = h;
                    end
                    % Plot the original click point
                    hPoint = plot(handles.ax, newDetection.click(1), newDetection.click(2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                    roiGroup(end+1) = hPoint;
                    
                    % Store handles
                    handles.roiHandles{end+1} = roiGroup;
                    
                    % Add new detection
                    handles.ciliaDetections{end+1} = newDetection;
                   
                    % Update display and count
%                     updateDisplay(hObject);
%                     applyWindowLevel(handles);
                    updateCiliaCount(hObject);
%                     disp('Merged two closest ROIs.');
                    
                    msg = sprintf('Merged two closest ROIs');  % or any dynamic message
                    set(handles.status, 'String', msg);
                    drawnow;  % forces immediate GUI update
                else
                    msg = sprintf('Selected ROIs are not overlapping or within the proximity threshold.');  % or any dynamic message
                    set(handles.status, 'String', msg);
                    drawnow;  % forces immediate GUI update
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


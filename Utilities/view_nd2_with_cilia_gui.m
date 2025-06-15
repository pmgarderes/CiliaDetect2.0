function view_nd2_with_cilia_gui(stack, params, uniqueDetections)
% stack: cell array of {Y x X x Z} images per channel
% params: struct with detection parameters:
%   .windowSize, .minArea, .maxArea, .minElongation

adaptiveSensitivity = params.adaptiveSensitivity;
FirstTime = 1; 
numChannels = numel(stack);
currentChannel = 1;
numSlices = size(stack{1}, 3);
currentZ = 1;

% Store detections
ciliaDetections = {};
roiHandles = {};  % One per detection

% Create fullscreen figure
fig = figure('Name', 'GUI + Cilia Detection', ...
    'KeyPressFcn', @keyHandler, ...
    'Color', 'k', ...
    'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1]);

ax = axes('Parent', fig);
% if ciliaDetections is already defined
ciliaDetections = uniqueDetections;


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
    'FontSize', 10, ...
    'HorizontalAlignment', 'left');


imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', ax);
colormap('gray');
axis image off;

title(ax, sprintf('Channel %d | Z-plane %d/%d', ...
    currentChannel, currentZ, numSlices), ...
    'Color', 'w', 'FontSize', 18);

% Create a text label for the cilia count
countLabel = uicontrol('Style', 'text', ...
    'String', 'Cilia Count: 0', ...
    'Units', 'normalized', ...
    'Position', [0.01, 0.2, 0.2, 0.4], ...  % Adjust position and size as needed[0.85, 0.95, 0.1, 0.03], ... % Adjust position as needed
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left');

    function updateCiliaCount()
        count = numel(ciliaDetections);
        set(countLabel, 'String', sprintf('Cilia Count: %d', count));
    end

% Helper function to update display
    function updateDisplay()
        imgHandle.CData = stack{currentChannel}(:,:,currentZ);
        title(ax, sprintf('Channel %d | Z-plane %d/%d', ...
            currentChannel, currentZ, numSlices), ...
            'Color', 'w', 'FontSize', 18);
    end

% Key handler
    function keyHandler(~, event)
        switch event.Key
            case 'add'  % '+' key on main keyboard
                adaptiveSensitivity = min(adaptiveSensitivity + 0.05, 1.0);
                fprintf('Increased sensitivity: %.2f\n', adaptiveSensitivity);
            case 'subtract'  % '-' key on main keyboard
                adaptiveSensitivity = max(adaptiveSensitivity - 0.05, 0.05);
                fprintf('Decreased sensitivity: %.2f\n', adaptiveSensitivity);
            case 'rightarrow'
                currentChannel = mod(currentChannel, numChannels) + 1;
                updateDisplay();
            case 'leftarrow'
                currentChannel = mod(currentChannel - 2, numChannels) + 1;
                updateDisplay();
            case 'uparrow'
                currentZ = min(currentZ + 1, numSlices);
                updateDisplay();
            case 'downarrow'
                currentZ = max(currentZ - 1, 1);
                updateDisplay();
            case 'u'  % Undo last detection
                if ~isempty(ciliaDetections)
                    % Remove detection
                    ciliaDetections(end) = [];
                    
                    % Delete graphical objects
                    lastHandles = roiHandles{end};
                    for h = lastHandles
                        if isvalid(h)
                            delete(h);
                        end
                    end
                    roiHandles(end) = [];
                    
                    disp('Last detection undone.');
                else
                    disp('No detections to undo.');
                end
            case 'space'
                % Get mouse location in image coordinates
                cp = get(ax, 'CurrentPoint');
                x = round(cp(1,1));
                y = round(cp(1,2));
                
                % Validate position
                sz = size(stack{currentChannel});
                if x < 1 || x > sz(2) || y < 1 || y > sz(1)
                    disp('Click was out of bounds. Ignoring.');
                    return;
                end
                
                % Get current image
                currentFrame = stack{currentChannel}(:,:,currentZ);
                
                % Run cilia detection
                mask = detect_cilium_from_seed2(currentFrame, [x, y], params,adaptiveSensitivity);
                disp([ 'area ' num2str(sum(mask(:)))]) ; %  ciliaDetections{1}.mask(:)))])
                
                % Save result
                detectionStruct = struct( ...
                    'channel', currentChannel, ...
                    'zplane', currentZ, ...
                    'click', [x, y], ...
                    'mask', mask);
                ciliaDetections{end+1} = detectionStruct;
                
                
                % Overlay boundary of the new mask
                hold(ax, 'on');
                
                updateCiliaCount();
                
                % Find boundary points
                boundaries = bwboundaries(mask);
                roiGroup = gobjects(0); % Collect handles for this detection
                for k = 1:length(boundaries)
                    B = boundaries{k};
                    h = plot(ax, B(:,2), B(:,1), 'g-', 'LineWidth', 1.5);
                    roiGroup(end+1) = h;
                end
                hPoint = plot(ax, x, y, 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                roiGroup(end+1) = hPoint;
                % Store handles and detection

                roiHandles{end+1} = roiGroup;
            case 's'  % 's' for select/suppress
                % Get current mouse position
                cp = get(ax, 'CurrentPoint');
                xClick = cp(1,1);
                yClick = cp(1,2);
                
                % Find nearest ROI
                [selectedIdx, minDistance] = findNearestROI(xClick, yClick, ciliaDetections);
                
                if isempty(selectedIdx) || minDistance > 20
                    disp('No ROI close enough to be selected.');
                else
                    fprintf('Suppressing ROI #%d (%.2f pixels away)\n', selectedIdx, minDistance);
                    
                    % Delete ROI graphics
                    if ~isempty(roiHandles{selectedIdx})
                        for h = roiHandles{selectedIdx}
                            if isvalid(h)
                                delete(h);
                            end
                        end
                    end
                    
                    % Remove from detections
                    ciliaDetections(selectedIdx) = [];
                    roiHandles(selectedIdx) = [];
                    
                    disp('ROI suppressed.');
                    updateCiliaCount();
                end
            case 'r'  % 'r' for refresh/redraw
                % Clear existing ROI plots
                for i = 1:numel(roiHandles)
                    for h = roiHandles{i}
                        if isvalid(h)
                            delete(h);
                        end
                    end
                end
                roiHandles = {};
                
                % Redraw all cilia detections
                hold(ax, 'on');
                for i = 1:numel(ciliaDetections)
                    det = ciliaDetections{i};
                    mask = det.mask;
                    zplane = det.zplane;
                    channel = det.channel;
                    
                    % Find the contour of the mask
                    B = bwboundaries(mask);
                    roiGroup = gobjects(0); % Collect handles for this detection
                    for k = 1:length(B)
                        boundary = B{k};
                        h = plot(ax, boundary(:,2), boundary(:,1), 'g-', 'LineWidth', 1.5);
                        roiGroup(end+1) = h;
                    end
                    % Plot the original click point
                    hPoint = plot(ax, det.click(1), det.click(2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                    roiGroup(end+1) = hPoint;
                    
                    % Store handles
                    roiHandles{end+1} = roiGroup;
                    updateCiliaCount();
                end
                hold(ax, 'off');
                disp('All cilia detections have been redrawn.');
            case 'm'  % 'm' for merge
                % Get current mouse position
                cp = get(ax, 'CurrentPoint');
                xClick = cp(1,1);
                yClick = cp(1,2);
                
                % Find the two closest ROIs to the click position
                [idx1, idx2] = findTwoClosestROIs(xClick, yClick, ciliaDetections);
                
                if isempty(idx1) || isempty(idx2)
                    disp('Not enough ROIs to merge.');
                    return;
                end
                
                % Retrieve the masks
                mask1 = ciliaDetections{idx1}.mask;
                mask2 = ciliaDetections{idx2}.mask;
                
                % Check for overlap
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
                        'channel', ciliaDetections{idx1}.channel, ...
                        'zplane', ciliaDetections{idx1}.zplane, ...
                        'click', round((ciliaDetections{idx1}.click + ciliaDetections{idx2}.click)/2), ...
                        'mask', mergedMask);
                    
                    % Remove old detections and add new one
                    idxToRemove = sort([idx1, idx2], 'descend');
                    for i = 1:length(idxToRemove)
                        % Delete ROI graphics
                        if ~isempty(roiHandles{idxToRemove(i)})
                            for h = roiHandles{idxToRemove(i)}
                                if isvalid(h)
                                    delete(h);
                                end
                            end
                        end
                        % Remove from detections
                        ciliaDetections(idxToRemove(i)) = [];
                        roiHandles(idxToRemove(i)) = [];
                    end
                    
                    % Add new detection
                    ciliaDetections{end+1} = newDetection;
                    % (Optional) Add code here to display the new ROI and update roiHandles
                    
                    % Update display and count
                    updateDisplay();
                    updateCiliaCount();
                    disp('Merged two closest ROIs.');
                else
                    disp('Selected ROIs are not overlapping or within the proximity threshold.');
                end


            case {'escape', 'q'}
                close(fig);
                
        end
   
    end

% On close: save detections to base workspace
set(fig, 'CloseRequestFcn', @closeHandler);
    function closeHandler(~, ~)
        assignin('base', 'ciliaDetections', ciliaDetections);
        delete(fig);
        disp('Cilia detections saved to variable: ciliaDetections');
    end
end




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



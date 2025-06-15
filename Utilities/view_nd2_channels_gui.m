function view_nd2_channels_gui(stack, params)
% INPUTS:
%   stack: cell array of {Y x X x Z} per channel
%   params: struct with detection parameters:
%       - windowSize
%       - minArea
%       - maxArea
%       - minElongation

numChannels = numel(stack);
currentChannel = 1;
numSlices = size(stack{1}, 3);
currentZ = 1;

% Storage for detected cilia masks
ciliaDetections = {};

% Create fullscreen figure
fig = figure('Name', 'ND2 Viewer + Cilia Detector', ...
    'KeyPressFcn', @keyHandler, ...
    'WindowButtonDownFcn', @mouseClickHandler, ...
    'Color', 'k', ...
    'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1]);

ax = axes('Parent', fig);
imgHandle = imagesc(stack{currentChannel}(:,:,currentZ), 'Parent', ax);
colormap('gray');
axis image off;

title(ax, sprintf('Channel %d | Z-plane %d/%d', ...
    currentChannel, currentZ, numSlices), ...
    'Color', 'w', 'FontSize', 18);

    function updateDisplay()
        imgHandle.CData = stack{currentChannel}(:,:,currentZ);
        title(ax, sprintf('Channel %d | Z-plane %d/%d', ...
            currentChannel, currentZ, numSlices), ...
            'Color', 'w', 'FontSize', 18);
    end

    function keyHandler(~, event)
        switch event.Key
            case 'rightarrow'
                currentChannel = mod(currentChannel, numChannels) + 1;
            case 'leftarrow'
                currentChannel = mod(currentChannel - 2, numChannels) + 1;
            case 'uparrow'
                currentZ = min(currentZ + 1, numSlices);
            case 'downarrow'
                currentZ = max(currentZ - 1, 1);
            case {'escape', 'q'}
                close(fig);
                return;
        end
        updateDisplay();
    end

    function mouseClickHandler(~, ~)
        % Only respond to LEFT clicks (normal click == 1)
        clickType = get(fig, 'SelectionType');
        if ~strcmp(clickType, 'normal')
            return;
        end
        
        % Get mouse click coordinates
        cp = get(ax, 'CurrentPoint');
        x = round(cp(1,1));
        y = round(cp(1,2));
        
        % Ensure click is within bounds
        sz = size(stack{currentChannel});
        if x < 1 || x > sz(2) || y < 1 || y > sz(1)
            return;
        end
        
        % Get current frame
        currentFrame = stack{currentChannel}(:,:,currentZ);
        
        % Detect cilium at clicked location
        mask = detect_cilium_from_seed(currentFrame, [x, y], params);
        
        % Save result
        detectionStruct = struct( ...
            'channel', currentChannel, ...
            'zplane', currentZ, ...
            'click', [x, y], ...
            'mask', mask);
        ciliaDetections{end+1} = detectionStruct;
        
        % Overlay mask boundary
        hold(ax, 'on');
        visboundaries(ax, mask, 'Color', 'r', 'LineWidth', 1.5);
    end


% Optional output variable on close
set(fig, 'CloseRequestFcn', @closeHandler);
    function closeHandler(~, ~)
        assignin('base', 'ciliaDetections', ciliaDetections);
        delete(fig);
        disp('Cilia detections saved to variable: ciliaDetections');
    end
end

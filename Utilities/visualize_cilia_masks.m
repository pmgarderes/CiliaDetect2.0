function visualize_cilia_masks(stack, uniqueDetections, params)
    % visualize_cilia_masks overlays cilia and background masks on a reference image.
    %
    % Inputs:
    %   - stack: Cell array where each cell contains a 3D image stack for a channel.
    %   - uniqueDetections: Cell array of detection structs with fields:
    %       - mask: Binary mask of the cilium.
    %       - channel: Channel number.
    %       - zplane: Z-plane number.
    %       - click: [x, y] coordinates of the user click.
    %   - params: Struct with parameters, must include:
    %       - backgroundSpread: Scalar specifying the spread for background mask dilation.

    % Validate inputs
    if nargin < 3
        error('Function requires three inputs: stack, uniqueDetections, and params.');
    end
    if ~isfield(params, 'backgroundSpread')
        params.backgroundSpread = 5; % Default spread in pixels
    end

    % Determine image dimensions
    [rows, cols, ~] = size(stack{3});
    numDetections = numel(uniqueDetections);

    % Create sum projection for the reference image (e.g., channel 1)
    refImage = sum(stack{3}, 3);
    refImage = mat2gray(refImage); % Normalize for display

    % Initialize RGB images for overlays
    ciliaOverlay = repmat(refImage, [1, 1, 3]);
    backgroundOverlay = repmat(refImage, [1, 1, 3]);

    % Generate distinct colors for each detection
    colors = lines(numDetections); % MATLAB's built-in colormap

    % Create structuring element for background mask dilation
    se = strel('disk', params.backgroundSpread);

    % Overlay masks
    for i = 1:numDetections
        det = uniqueDetections{i};
        mask = logical(det.mask);

        % Skip if mask is empty
        if ~any(mask(:))
            continue;
        end

        % Assign color
        color = colors(i, :);

        % Overlay cilia mask
        for c = 1:3
            channel = ciliaOverlay(:, :, c);
            channel(mask) = color(c);
            ciliaOverlay(:, :, c) = channel;
        end

        % Create background mask
        dilatedMask = imdilate(mask, se);
        backgroundMask = dilatedMask & ~mask;

        % Overlay background mask
        for c = 1:3
            channel = backgroundOverlay(:, :, c);
            channel(backgroundMask) = color(c);
            backgroundOverlay(:, :, c) = channel;
        end
    end

    % Display the overlays
    figure('units','normalized','outerposition',[0 0 1 1])
    subplot(1,2, 1);
    imshow(ciliaOverlay);
    title('Cilia Masks Overlay');

    subplot(1,2, 2);
    imshow(backgroundOverlay);
    title('Background Masks Overlay');
    

end

function results = quantify_cilia_fluorescence2(stack, uniqueDetections, params)
    % Parameters
    if ~isfield(params, 'backgroundSpread')
        params.backgroundSpread = 5; % Default spread in pixels
    end
    if ~isfield(params, 'fluorescenceMode')
        params.fluorescenceMode = 'mean'; % Options: 'mean' or 'sum'
    end

    numChannels = numel(stack);
    [rows, cols, ~] = size(stack{1});
    numDetections = numel(uniqueDetections);

    % Precompute sum projections for each channel
    sumProjections = cell(1, numChannels);
    for ch = 1:numChannels
        sumProjections{ch} = sum(stack{ch}, 3);
    end

    % Initialize results struct array
    results = struct( ...
        'click', [], ...
        'zplane', [], ...
        'sourceChannel', [], ...
        'ciliaArea', [], ...
        'backgroundArea', [], ...
        'meanCilia', zeros(1, numChannels), ...
        'meanBackground', zeros(1, numChannels), ...
        'corrected', zeros(1, numChannels), ...
        'totalCorrected', zeros(1, numChannels) ...
    );

    % Process each detection
    for i = 1:numDetections
        det = uniqueDetections{i};
        mask = logical(det.mask);

        % Check size
        if ~isequal(size(mask), [rows, cols])
            error('Mask size does not match image dimensions.');
        end

        % Compute areas
        ciliaArea = sum(mask(:));
        se = strel('disk', params.backgroundSpread);
        dilatedMask = imdilate(mask, se);
        backgroundMask = dilatedMask & ~mask;
        backgroundArea = sum(backgroundMask(:));

        % Initialize per-channel outputs
        meanCilia = zeros(1, numChannels);
        meanBackground = zeros(1, numChannels);
        corrected = zeros(1, numChannels);
        totalCorrected = zeros(1, numChannels);

        for ch = 1:numChannels
            img = sumProjections{ch};
            ciliaPixels = double(img(mask));
            backgroundPixels = double(img(backgroundMask));

            if strcmp(params.fluorescenceMode, 'sum')
                meanCilia(ch) = sum(ciliaPixels);
                meanBackground(ch) = sum(backgroundPixels);
                corrected(ch) = meanCilia(ch) - meanBackground(ch)*(ciliaArea/backgroundArea);
                totalCorrected(ch) = corrected(ch); % Same as corrected in sum mode
            else
                meanCilia(ch) = mean(ciliaPixels);
                meanBackground(ch) = mean(backgroundPixels);
                corrected(ch) = meanCilia(ch) - meanBackground(ch);
                totalCorrected(ch) = corrected(ch) * ciliaArea;
            end
        end

        % Store everything in struct
        results(i).click = det.click;
        results(i).zplane = det.zplane;
        results(i).sourceChannel = det.channel;
        results(i).ciliaArea = ciliaArea;
        results(i).backgroundArea = backgroundArea;
        results(i).meanCilia = meanCilia;
        results(i).meanBackground = meanBackground;
        results(i).corrected = corrected;
        results(i).totalCorrected = totalCorrected;
    end
end

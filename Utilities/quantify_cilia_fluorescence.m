function results = quantify_cilia_fluorescence(stack, uniqueDetections, params)
    % Parameters
    if ~isfield(params, 'backgroundSpread')
        params.backgroundSpread = 5; % Default spread in pixels
    end

    numChannels = numel(stack);
    [rows, cols, ~] = size(stack{1});
    numDetections = numel(uniqueDetections);

    % Initialize results
    results = struct('channel', [], 'zplane', [], 'click', [], ...
                     'meanCilia', [], 'meanBackground', [], ...
                     'correctedMean', [], 'totalCorrected', []);

    % Create sum projections for each channel
    sumProjections = cell(1, numChannels);
    for ch = 1:numChannels
        sumProjections{ch} = sum(stack{ch}, 3);
    end

    % Process each detection
    for i = 1:numDetections
        det = uniqueDetections{i};
        ch = det.channel;
        mask = det.mask;

        % Ensure mask is logical and matches image size
        mask = logical(mask);
        if ~isequal(size(mask), [rows, cols])
            error('Mask size does not match image dimensions.');
        end

        % Create background mask
        se = strel('disk', params.backgroundSpread);
        dilatedMask = imdilate(mask, se);
        backgroundMask = dilatedMask & ~mask;

        % Extract intensities
        img = sumProjections{ch};
        ciliaPixels = img(mask);
        backgroundPixels = img(backgroundMask);

        % Compute statistics
        meanCilia = mean(ciliaPixels);
        meanBackground = mean(backgroundPixels);
        correctedMean = meanCilia - meanBackground;
        totalCorrected = correctedMean * sum(mask(:));

        % Store results
        results(i).channel = ch;
        results(i).zplane = det.zplane;
        results(i).click = det.click;
        results(i).meanCilia = meanCilia;
        results(i).meanBackground = meanBackground;
        results(i).correctedMean = correctedMean;
        results(i).totalCorrected = totalCorrected;
    end
end

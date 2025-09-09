function results = quantify_cilia_fluorescence3(stack, uniqueDetections, params, Metadata)
% QUANTIFY_CILIA_FLUORESCENCE2
% Computes two fluorescence measures for each detection:
%   (1a) Full-stack SUM with global background → F_StackSum_ch#
%   (1b) Single-plane MEAN with local background → F_plan_ch#
%
% INPUTS
%   stack            : cell array {nChannels}, each [Y x X x Z]
%   uniqueDetections : cell array of detections with fields .mask, .zplane, .channel, .click
%   params.backgroundSpread   : radius for local background dilation (px)
%   params.backgroundPadding  : radius for background exclusion (px)
%   Metadata         : for morphology attachment
%
% OUTPUTS
%   results : struct array, one per detection, with fields:
%       .click, .zplane, .sourceChannel, .ciliaArea, .backgroundArea
%       .F_StackSum_ch1..N
%       .F_plan_ch1..N
%       morphology fields (via attach_cilium_morphology)

    numChannels = numel(stack);
    [rows, cols, ~] = size(stack{1});
    numDetections = numel(uniqueDetections);

    % Precompute full-stack sum projections (global signal)
    sumProjections = cell(1, numChannels);
    for ch = 1:numChannels
        sumProjections{ch} = sum(stack{ch}, 3);
    end

    % Initialize result struct array
    results = repmat(struct( ...
        'click', [], ...
        'zplane', [], ...
        'sourceChannel', [], ...
        'ciliaArea', [], ...
        'backgroundArea', [], ...
        'F_StackSum', [], ...
        'F_plan', []), numDetections, 1);

    % Loop detections
    for i = 1:numDetections
        det = uniqueDetections{i};
        mask = logical(det.mask);
        z    = det.zplane;

        % Check mask dimensions
        if ~isequal(size(mask), [rows, cols])
            error('Mask size does not match image dimensions.');
        end

        % ROI areas
        ciliaArea = sum(mask(:));
        se = strel('disk', params.backgroundSpread);
        sePad = strel('disk', params.backgroundPadding);
        dilatedMask = imdilate(mask, se);
        padMask     = imdilate(mask, sePad);
        backgroundMask = dilatedMask & ~padMask;
        backgroundArea = sum(backgroundMask(:));

        % Initialize arrays
        F_StackSum = zeros(1, numChannels);
        F_plan     = zeros(1, numChannels);

        % Per channel
        for ch = 1:numChannels
            % --- FullStack SUM (global) ---
            imgFull = sumProjections{ch};
            ciliaPixelsF = double(imgFull(mask));
            bgPixelsF    = double(imgFull(backgroundMask));

            sumCilia = sum(ciliaPixelsF);
            sumBg    = sum(bgPixelsF);
            corrSum  = sumCilia - sumBg * (ciliaArea / backgroundArea);
            F_StackSum(ch) = corrSum;

            % --- SubStack MEAN (local plane) ---
            imgPlane = stack{ch}(:,:,z);
            ciliaPixelsP = double(imgPlane(mask));
            bgPixelsP    = double(imgPlane(backgroundMask));

            meanCilia = mean(ciliaPixelsP);
            meanBg    = mean(bgPixelsP);
            corrMean  = (meanCilia - meanBg) * ciliaArea;
            F_plan(ch) = corrMean;
        end

        % Store
        results(i).click         = det.click;
        results(i).zplane        = det.zplane;
        results(i).sourceChannel = det.channel;
        results(i).ciliaArea     = ciliaArea;
        results(i).backgroundArea= backgroundArea;

        % Named fields for export (comprehensible labels)
        for ch = 1:numChannels
            results(i).(['F_StackSum_ch' num2str(ch)]) = F_StackSum(ch);
            results(i).(['F_plan_ch' num2str(ch)])     = F_plan(ch);
        end

        % Attach morphology metrics
        results = attach_cilium_morphology(results, i, mask, Metadata);
    end
end

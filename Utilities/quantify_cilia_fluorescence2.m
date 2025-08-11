function results = quantify_cilia_fluorescence2(stack, uniqueDetections, params)
% Parameters
%     if ~isfield(params, 'backgroundSpread')
%         params.backgroundSpread = 5; % Default spread in pixels
%     end
%     if ~isfield(params, 'fluorescenceMode')
%         params.fluorescenceMode = 'mean'; % Options: 'mean' or 'sum'
%     end
if ~isfield(params, 'fluorescenceMode')
    params.fluorescenceMode = 'sum sub'; % Options: 'mean' or 'sum'
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
if strcmp(params.QuantificationDepth, 'Volume')
     results = quantifyCiliaFluorescenceVolume(stack, uniqueDetections, params);
else
    for i = 1:numDetections
        det = uniqueDetections{i};
        mask = logical(det.mask);
        %         ch = det.channel;
        z = det.zplane;
        
        
        % Check size
        if ~isequal(size(mask), [rows, cols])
            error('Mask size does not match image dimensions.');
        end
        
        % Compute areas
        ciliaArea = sum(mask(:));
        se = strel('disk', params.backgroundSpread);
        dilatedMask = imdilate(mask, se);
        padMask = imdilate(mask, sePad);
        % background mask excludes the padded region
        backgroundMask = dilatedMask & ~padMask;
        backgroundArea = sum(backgroundMask(:));
        
        % Initialize per-channel outputs
        meanCilia = zeros(1, numChannels);
        meanBackground = zeros(1, numChannels);
        corrected = zeros(1, numChannels);
        totalCorrected = zeros(1, numChannels);
        
        
        for ch = 1:numChannels
            
            if strcmp(params.QuantificationDepth, 'FullStack')
                img = sumProjections{ch};
            elseif strcmp(params.QuantificationDepth, 'SubStack')
                img = stack{ch}(:,:,z);
            end
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


% % function results = quantify_cilia_fluorescence2(stack, uniqueDetections, params)
% %
% % if ~isfield(params, 'backgroundSpread')
% %     params.backgroundSpread = 5;
% % end
% % if ~isfield(params, 'backgroundPadding')
% %     params.backgroundPadding = 2;
% % end
% %
% % numChannels = numel(stack);
% % numDetections = numel(uniqueDetections);
% % results = struct(...
% %     'channel', [], 'zplane', [], 'click', [], ...
% %     'meanCilia', [], 'meanBackground', [], ...
% %     'correctedMean', [], 'totalCorrected', [], ...
% %     'areaCilia', [], 'areaBackground', []);
% %
% % seSpread = strel('disk', params.backgroundSpread);
% % sePad = strel('disk', params.backgroundPadding);
% %
% % for i = 1:numDetections
% %     det = uniqueDetections{i};
% %     ch = det.channel;
% %     z = det.zplane;
% %     mask = logical(det.mask);
% %
% %     img = stack{ch}(:,:,z);  % Use only the clicked plane
% %
% %     % Create padded ROI to exclude ambiguous pixels:
% %     paddedROI = imdilate(mask, sePad);
% %     dilatedMask = imdilate(mask, seSpread);
% %     backgroundMask = dilatedMask & ~paddedROI;
% %
% %     ciliaPixels = img(mask);
% %     backgroundPixels = img(backgroundMask);
% %
% %     areaCilia = sum(mask(:));
% %     areaBackground = sum(backgroundMask(:));
% %     meanCilia = mean(ciliaPixels);
% %     meanBackground = mean(backgroundPixels);
% %     correctedMean = meanCilia - meanBackground;
% %
% %     if strcmpi(params.fluorescenceMode, 'sum')
% %         totalCorrected = correctedMean * areaCilia;
% %     else
% %         totalCorrected = correctedMean;
% %     end
% %
% %     results(i) = struct(...
% %         'channel', ch, ...
% %         'zplane', z, ...
% %         'click', det.click, ...
% %         'meanCilia', meanCilia, ...
% %         'meanBackground', meanBackground, ...
% %         'correctedMean', correctedMean, ...
% %         'totalCorrected', totalCorrected, ...
% %         'areaCilia', areaCilia, ...
% %         'areaBackground', areaBackground);
% % end
% % end
% %

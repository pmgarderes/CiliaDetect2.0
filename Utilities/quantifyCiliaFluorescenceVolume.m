function results = quantifyCiliaFluorescenceVolume(stack, uniqueDetections, params)
% 3D fluorescence quantification within volumetric ROI and background.
%
% stack            - cell array of size numChannels, each with size [Y×X×Z]
% uniqueDetections - cell array of detection structs (with .mask per plane and channel)
% params            - struct including:
%                     .backgroundSpread
%                     .backgroundPadding
%                     .fluorescenceMode ('sum' or 'mean')
  
if ~isfield(params, 'backgroundSpread'); params.backgroundSpread = 1; end
if ~isfield(params, 'backgroundPadding'); params.backgroundPadding = 0; end

numChannels = numel(stack);
numDetections = numel(uniqueDetections);

seSpread = strel('sphere', params.backgroundSpread);
sePad = strel('sphere', params.backgroundPadding);

results = struct('channel',[], 'zplane',[], 'click',[], ...
                 'volumeCilia',[], 'volumeBackground',[], ...
                 'meanCilia',[], 'meanBackground',[], ...
                 'correctedMean',[], 'totalCorrected',[]);

for i = 1:numDetections
    det = uniqueDetections{i};
    ch = det.channel;
    z0 = det.zplane;
    mask2d = logical(det.mask);

    % Build 3D mask by stacking the same 2D mask across Z if consistent across planes,
    % or ideally use full 3D segmentation (advanced)
    volMask = false(size(stack{ch}));
    volMask(:,:,z0) = mask2d;

    % Optionally dilate each slice to capture neighbor planes? leave for advanced.
    padded = imerode(volMask, sePad);
    dilated = imdilate(volMask, seSpread);
    backgroundMask = dilated & ~padded;

    volumeCilia = sum(volMask(:));
    volumeBackground = sum(backgroundMask(:));

    valuesCilia = double(stack{ch}(volMask));
    valuesBack = double(stack{ch}(backgroundMask));

    meanC = mean(valuesCilia);
    meanB = mean(valuesBack);
    corrMean = meanC - meanB;

    if strcmpi(params.fluorescenceMode,'sum')
        tot = sum(valuesCilia) - meanB * volumeCilia;
    else
        tot = corrMean * volumeCilia;
    end

    results(i) = struct('channel', ch, 'zplane', z0, 'click', det.click, ...
                        'volumeCilia', volumeCilia, 'volumeBackground', volumeBackground, ...
                        'meanCilia', meanC, 'meanBackground', meanB, ...
                        'correctedMean', corrMean, 'totalCorrected', tot);
end
end

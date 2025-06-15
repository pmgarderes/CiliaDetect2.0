function seedPoints = detectCiliaSeeds(inputImg, params)
%DETECTCILIASEEDS Detects putative cilia seed points in a single image.
%
%   seedPoints = detectCiliaSeeds(inputImg, params)
%
%   Inputs:
%       inputImg - Grayscale image (2D matrix) of the sample.
%       params   - Structure containing detection parameters:
%           .gaussianSigma       - Standard deviation for Gaussian filter.
%           .tophatRadius        - Radius for top-hat filtering.
%           .minArea             - Minimum area of detected blobs.
%           .maxArea             - Maximum area of detected blobs.
%           .minEccentricity     - Minimum eccentricity of blobs.
%           .maxEccentricity     - Maximum eccentricity of blobs.
%
%   Output:
%       seedPoints - Nx2 array of [x, y] coordinates of detected seed points.

    % 1. Preprocessing
    smoothedImg = imgaussfilt(inputImg, params.gaussianSigma);
    
    backgroundCorrected = imtophat(smoothedImg, strel('disk', params.tophatRadius));

    % 2. Adaptive Thresholding
    binaryImg = imbinarize(backgroundCorrected, 'adaptive', 'ForegroundPolarity', 'bright', 'Sensitivity', 0.5);

    % 3. Morphological Filtering
    binaryImg = bwareaopen(binaryImg, params.minArea);
    binaryImg = imclose(binaryImg, strel('disk', 1));

    % 4. Connected Component Analysis
    cc = bwconncomp(binaryImg);
    stats = regionprops(cc, 'Area', 'Eccentricity', 'Centroid');

    % Skeletonization
    skeleton = bwskel(binaryImg);
    
    % Pruning: remove branches shorter than minBranchLength
    prunedSkeleton = bwskel(binaryImg, 'MinBranchLength', params.minBranchLength);
    
    figure;
    subplot(1,3,1);
    imshow(binaryImg);
    title('Original Binary Image');
    
    subplot(1,3,2);
    imshow(skeleton);
    title('Skeletonized Image');
    
    subplot(1,3,3);
    imshow(prunedSkeleton);
    title('Pruned Skeleton');


    % 5. Candidate Filtering
    seedPoints = [];
    for i = 1:length(stats)
        area = stats(i).Area;
        ecc = stats(i).Eccentricity;
        if area >= params.minArea && area <= params.maxArea && ...
           ecc >= params.minEccentricity && ecc <= params.maxEccentricity
            seedPoints = [seedPoints; stats(i).Centroid];
        end
    end
end

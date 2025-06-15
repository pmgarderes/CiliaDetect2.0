function ciliaMask = detect_cilium_from_seed2(img, seedPos, params, adaptiveSensitivity)
% img: 2D grayscale image (single Z-plane, single channel)
% seedPos: [x, y] from user click
% params: structure with fields:
%   - windowSize: scalar, size of square ROI (e.g., 30)
%   - minArea: minimum area of candidate (e.g., 10)
%   - maxArea: maximum area of candidate (e.g., 200)
%   - minElongation: minimum elongation (e.g., 2.0)

x = round(seedPos(1));
y = round(seedPos(2));
w = round(params.windowSize / 2);

% Crop ROI around seed
[H, W] = size(img);
x1 = max(1, x - w); x2 = min(W, x + w);
y1 = max(1, y - w); y2 = min(H, y + w);
roi = img(y1:y2, x1:x2);

% Normalize & smooth (optional)
roi = mat2gray(roi);
roiFiltered = imgaussfilt(roi, 1);

% Threshold adaptively
bw = imbinarize(roiFiltered, 'adaptive', 'Sensitivity', adaptiveSensitivity);
bw = bwareaopen(bw, params.minArea);

% Label and filter by shape
stats = regionprops(bw, roiFiltered, ...
    'Area', 'Eccentricity', 'BoundingBox', 'PixelIdxList', 'Centroid');

ciliaMask = false(size(img));

for i = 1:numel(stats)
    % Create binary mask from thresholded and filtered region
    bw = imbinarize(roiFiltered, 'adaptive', 'Sensitivity', adaptiveSensitivity);
    bw = bwareaopen(bw, params.minArea);
    
    % Map click coordinates into ROI coordinates
    cx = x - x1 + 1;
    cy = y - y1 + 1;
    
    if cx < 1 || cy < 1 || cx > size(bw,2) || cy > size(bw,1)
        warning('Click was outside ROI.');
        ciliaMask = false(size(img));
        return;
    end
    
    % Label connected components
    labeled = bwlabel(bw);
    clickedLabel = labeled(cy, cx);
    
    if clickedLabel == 0
        % No object at click location
        ciliaMask = false(size(img));
        return;
    end
    
    % Create mask for clicked region only
    roiMask = (labeled == clickedLabel);
    
    % Measure area
    A = sum(roiMask(:));
    if A < params.minArea || A > params.maxArea
        ciliaMask = false(size(img));
        return;
    end
    
    % Skeleton and thinness test
    skel = bwmorph(roiMask, 'skel', Inf);
    skeletonLength = sum(skel(:));
    thinness = skeletonLength / sqrt(A);
    if thinness < params.minThinness
        ciliaMask = false(size(img));
        return;
    end
    
    % Reproject to full image coordinates
    [yy, xx] = find(roiMask);
    yy = yy + y1 - 1;
    xx = xx + x1 - 1;
    linIdx = sub2ind(size(img), yy, xx);
    ciliaMask = false(size(img));
    ciliaMask(linIdx) = true;
    
end
end

function ciliaMask = detect_cilium_from_seed(img, seedPos, params)
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
    bw = imbinarize(roiFiltered, 'adaptive', 'Sensitivity', 0.5);
    bw = bwareaopen(bw, params.minArea);

    % Label and filter by shape
    stats = regionprops(bw, roiFiltered, ...
        'Area', 'Eccentricity', 'BoundingBox', 'PixelIdxList', 'Centroid');

    ciliaMask = false(size(img));

    for i = 1:numel(stats)
        A = stats(i).Area;
        if A < params.minArea || A > params.maxArea
            continue;
        end

        % Create a binary mask of the region in the local ROI
        bwRegion = false(size(bw));
        bwRegion(stats(i).PixelIdxList) = true;

        % Skeletonize the region
        skel = bwmorph(bwRegion, 'skel', Inf);
        skeletonLength = sum(skel(:));

        % Thinness = skeleton length / sqrt(area)
        thinness = skeletonLength / sqrt(A);
        if thinness < params.minThinness
            continue;
        end


        % Map detected region back to full image
        [yy, xx] = ind2sub(size(bw), stats(i).PixelIdxList);
        yy = yy + y1 - 1;
        xx = xx + x1 - 1;
        linIdx = sub2ind(size(img), yy, xx);
        ciliaMask(linIdx) = true;
    end
end

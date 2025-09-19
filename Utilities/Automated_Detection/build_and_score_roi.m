function [mask, area, elong, ecc, passed] = build_and_score_roi(stackCh, seedXYZ, params)
    % seedXYZ = [x y z]
    x = seedXYZ(1); y = seedXYZ(2); z = seedXYZ(3);
    [H,W,~] = size(stackCh);

    win = params.windowSize;
    half = floor(win/2);
    x1 = max(1, x-half); x2 = min(W, x+half);
    y1 = max(1, y-half); y2 = min(H, y+half);

    patch = stackCh(y1:y2, x1:x2, z);
    patch = double(patch);

    % preprocess (tophat + mild blur) for segmentation
    if isfield(params,'tophatRadius') && params.tophatRadius > 0
        patch = imtophat(patch, strel('disk', params.tophatRadius));
    end
    patchF = imgaussfilt(patch, 0.8);

    % adaptive threshold
    sens = 0.5; if isfield(params,'adaptiveSensitivity'), sens = params.adaptiveSensitivity; end
    T = adaptthresh(mat2gray(patchF), sens);
    bw = imbinarize(mat2gray(patchF), T);

    % keep components that include the seed and are "bright-ish"
    bw = bwareafilt(bw, [max(3, params.minArea) inf]);      % crude area prefilter
    % ensure connectivity of the seed pixel within the patch
    seedLocal = [x - x1 + 1, y - y1 + 1];
    CC = bwconncomp(bw);
    keep = false(1, CC.NumObjects);
    for i = 1:CC.NumObjects
        linIdx = CC.PixelIdxList{i};
        [yy, xx] = ind2sub(size(bw), linIdx);
        if any(xx == seedLocal(1) & yy == seedLocal(2))
            keep(i) = true;
        end
    end
    bw2 = false(size(bw));
    bw2(vertcat(CC.PixelIdxList{keep})) = true;

    % refine shape (close small holes, smooth edges)
    bw2 = imfill(bw2, 'holes');
    bw2 = bwareaopen(bw2, max(1, round(params.minArea/2)));
    bw2 = imclose(bw2, strel('disk',1));

    % measure
    S = regionprops(bw2, 'Area','MajorAxisLength','MinorAxisLength','Eccentricity');
    area = 0; elong = 0; ecc = 0;
    mask = false(size(stackCh,1), size(stackCh,2));
    passed = false;
    if isempty(S), return; end

    % keep largest blob
    [~, idxMax] = max([S.Area]);
    area = S(idxMax).Area;
    ecc  = S(idxMax).Eccentricity;
    if S(idxMax).MinorAxisLength > 0
        elong = S(idxMax).MajorAxisLength / S(idxMax).MinorAxisLength;
    else
        elong = inf;
    end

    % score using your criteria
    okArea  = area >= params.minArea & area <= params.maxArea;
    okElong = elong >= params.minElongation;
    okThin  = true;
    if isfield(params,'minThinness') && ~isempty(params.minThinness)
        % optional thinness proxy via axis ratio (already elong), or implement your own
        okThin = elong >= params.minThinness;
    end
    okEcc = true;
    if isfield(params,'minEccentricity'), okEcc = okEcc & (ecc >= params.minEccentricity); end
    if isfield(params,'maxEccentricity'), okEcc = okEcc & (ecc <= params.maxEccentricity); end

    passed = okArea & okElong & okThin & okEcc;

    % place mask back in full image coordinates
    if passed
        full = false(size(bw2));
        full(bw2) = true;
        mask(y1:y2, x1:x2) = full;
    end
end

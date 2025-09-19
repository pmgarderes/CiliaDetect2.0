function forbidden = build_forbidden_mask(forbidden, detections, testedPoints, radius, seedCh, z0)
% Mark pixels within 'radius' of every detection center and every tested point
% on the specified channel (seedCh) and z-plane (z0).

    [H,W] = size(forbidden);
    [xx,yy] = meshgrid(1:W, 1:H);
    acc = false(H,W);

    % ---- Existing detections (same channel & z)
    for i = 1:numel(detections)
        det = detections{i};
        if isempty(det) || det.channel~=seedCh || det.zplane~=z0, continue; end

        % Prefer explicit click center; otherwise fall back to mask center
        if isfield(det,'click') && ~isempty(det.click)
            cx = det.click(1); cy = det.click(2);
        elseif exist('get_detection_center','file') == 2
            [cy,cx] = get_detection_center(det.mask);
        else
            [r,c] = find(det.mask);
            cx = round(mean(c)); cy = round(mean(r));
        end

        acc = acc | ((xx - cx).^2 + (yy - cy).^2 <= radius^2);
    end

    % ---- Previously tested points (same channel & z)
    if exist('testedPoints','var') && ~isempty(testedPoints)
        sel = testedPoints.channel==seedCh & testedPoints.z==z0;
        xs = testedPoints.x(sel); ys = testedPoints.y(sel);
        for k = 1:numel(xs)
            cx = xs(k); cy = ys(k);
            acc = acc | ((xx - cx).^2 + (yy - cy).^2 <= radius^2);
        end
    end

    forbidden = forbidden | acc;
end

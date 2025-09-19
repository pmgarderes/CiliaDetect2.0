function forbidden = forbid_existing_centers(forbidden, detections, radius)
% Mark pixels within 'radius' of each detection center as forbidden.
%
% forbidden  : logical mask (HxW)
% detections : cell array of detection structs with field 'mask'
% radius     : scalar radius in pixels

    [H,W] = size(forbidden);
    [xx,yy] = meshgrid(1:W, 1:H);
    for i = 1:numel(detections)
        mask = detections{i}.mask;
        if isempty(mask), continue; end
        [r,c] = find(mask);
        cx = round(mean(c));  % detection center X
        cy = round(mean(r));  % detection center Y
        dist2 = (xx - cx).^2 + (yy - cy).^2;
        forbidden = forbidden | (dist2 <= radius^2);
    end
end

function tf = overlaps_existing(maskNew, detections, maxOverlap)
    % Return true if maskNew overlaps too much with any existing detection
    tf = false;
    if isempty(detections), return; end
    Anew = sum(maskNew(:));
    for i = 1:numel(detections)
        m = logical(detections{i}.mask);
        inter = sum((maskNew & m)(:));
        over1 = inter / max(1,Anew);
        over2 = inter / max(1,sum(m(:)));
        if max([over1, over2]) >= maxOverlap
            tf = true; return;
        end
    end
end

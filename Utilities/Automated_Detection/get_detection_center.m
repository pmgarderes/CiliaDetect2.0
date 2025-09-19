function c = get_detection_center(mask)
    s = regionprops(mask, 'Centroid');
    if isempty(s), c = [NaN,NaN]; else, c = s(1).Centroid; end
end
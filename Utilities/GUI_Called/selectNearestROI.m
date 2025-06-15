function selectNearestROI(xClick, yClick)
    global ciliaDetections; % or pass it into your GUI properly

    minDistance = Inf;
    selectedIndex = [];

    for i = 1:numel(ciliaDetections)
        det = ciliaDetections{i};
        clickPos = det.click;  % det.click = [x, y]

        dist = sqrt( (xClick - clickPos(1))^2 + (yClick - clickPos(2))^2 );

        if dist < minDistance
            minDistance = dist;
            selectedIndex = i;
        end
    end

    % Threshold to actually select (e.g., within 20 pixels)
    if minDistance < 20  % you can adjust this threshold
        fprintf('Selected ROI #%d at distance %.2f pixels\n', selectedIndex, minDistance);

        % Highlight the selected ROI here if you want
        highlightSelectedROI(selectedIndex);
    else
        disp('No ROI close enough to be selected.');
    end
end

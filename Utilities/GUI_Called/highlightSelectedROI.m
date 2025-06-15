function highlightSelectedROI(idx)
    global roiHandles; % assuming you saved plot handles earlier

    % First reset all to normal appearance
    for i = 1:numel(roiHandles)
        if isvalid(roiHandles{i})
            set(roiHandles{i}, 'Color', 'g', 'LineWidth', 1.5); % normal
        end
    end

    % Highlight selected ROI
    if isvalid(roiHandles{idx})
        set(roiHandles{idx}, 'Color', 'r', 'LineWidth', 2.5); % highlighted
    end
end

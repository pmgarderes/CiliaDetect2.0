function handles = redrawAllDetections(handles)
    % Clear existing ROI overlays
    
    for i = 1:numel(handles.roiHandles)
        for h = handles.roiHandles{i}
            if isvalid(h)
                delete(h);
                
            end
        end
    end
    handles.roiHandles = {};
    % Plot each detection contour + click marker
    hold(handles.ax, 'on');
    for i = 1:numel(handles.ciliaDetections)
        det = handles.ciliaDetections{i};
        B = bwboundaries(det.mask);
        roiGroup = gobjects(0);
        for k = 1:length(B)
            boundary = B{k};
            h = plot(handles.ax, boundary(:,2), boundary(:,1), 'g-', 'LineWidth', 1.5);
            roiGroup(end+1) = h;
        end
        hPoint = plot(handles.ax, det.click(1), det.click(2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
        roiGroup(end+1) = hPoint;

        handles.roiHandles{end+1} = roiGroup;
    end

    hold(handles.ax, 'off');

%     % Update count display
%     updateCiliaCount(handles);
end

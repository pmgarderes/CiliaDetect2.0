function clearDetectionsCallback(hObject)
    % Retrieve the handles structure
    handles = guidata(hObject);

    % Delete all ROI graphical objects
    if isfield(handles, 'roiHandles') && ~isempty(handles.roiHandles)
        for i = 1:numel(handles.roiHandles)
            for h = handles.roiHandles{i}
                if isvalid(h)
                    delete(h);
                end
            end
        end
    end

    % Clear the detections and ROI handles
    handles.ciliaDetections = {};
    handles.roiHandles = {};

    % Update the cilia count display
    updateCiliaCount(hObject);

    % Save the updated handles structure
    guidata(hObject, handles);

    disp('All cilia detections have been cleared.');
end

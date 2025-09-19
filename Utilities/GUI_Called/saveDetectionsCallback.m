function saveDetectionsCallback(hObject, ~)
handles = guidata(hObject);  % Retrieve the handles structure
    % display messages : 
    set(handles.WAITstatus, 'String', 'WAIT');

fullFileName = fullfile(handles.filePath, handles.fileName);

% Call the external function to save detections
uniqueDetections = handles.ciliaDetections;
save_cilia_detections(fullFileName, handles.ciliaDetections, uniqueDetections);

% disp(['Cilia detections saved to ', fullFileName]);

    % display messages : 
    set(handles.WAITstatus, 'String', '');
        msg = sprintf(' Done SAving detections.');  %
    updateStatusText(handles.status,  msg, '');
    
end

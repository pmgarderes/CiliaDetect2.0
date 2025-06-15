function saveDetectionsCallback(hObject, ~)
handles = guidata(hObject);  % Retrieve the handles structure

fullFileName = fullfile(handles.filePath, handles.fileName);

% Call the external function to save detections
uniqueDetections = handles.ciliaDetections;
save_cilia_detections(fullFileName, handles.ciliaDetections, uniqueDetections);

% disp(['Cilia detections saved to ', fullFileName]);
end

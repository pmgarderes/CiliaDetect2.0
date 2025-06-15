function updateCiliaCount(hObject)
    handles = guidata(hObject);  % Retrieve the updated handles structure
    count = numel(handles.ciliaDetections);
    set(handles.countLabel, 'String', sprintf('Cilia Count: %d', count));
    guidata(hObject, handles);  % Save any changes to handles
end

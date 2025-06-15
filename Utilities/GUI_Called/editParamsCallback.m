function editParamsCallback(hObject)
    handles = guidata(hObject);  % Retrieve the handles structure
    newParams = openParamEditor(handles.params);  % Open the editor
    if ~isempty(newParams)
        handles.params = newParams;  % Update parameters
        guidata(hObject, handles);  % Save the updated handles structure
        disp('Parameters updated.');
    end
end
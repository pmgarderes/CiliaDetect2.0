function setWorkingDirCallback(hObject, ~)
handles = guidata(hObject);  % Retrieve the handles structure
selectedDir = uigetdir(pwd, 'Select Working Directory');
if selectedDir ~= 0
    handles.workingDir = selectedDir;  % Store the selected directory
    guidata(hObject, handles);         % Save the updated handles structure
    disp(['Working directory set to: ', selectedDir]);
else
    disp('Directory selection canceled.');
end
end

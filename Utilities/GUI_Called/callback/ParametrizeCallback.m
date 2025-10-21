function ParametrizeCallback(hObject, ~)
    handles = guidata(hObject);
    oldParams = handles.params;

%     % Open editor (assume it returns a struct or [] if cancelled)  
    newParams = openCiliaParamTunerFromHandles(oldParams, handles);

    if isempty(newParams), return; end

    % Optional: migrate / validate before saving
    newParams = migrate_params(newParams);

    % Update handles
    handles.params = newParams;
    guidata(hObject, handles);

    % Save to disk (config/params.json)
    try
        save_params(handles.params);
        disp('Parameters updated and saved to config/params.json');
        % If you have a status UI:
        % updateStatusText(handles.status, '', 'Parameters saved.');
    catch ME
        % Keep changes in memory but report save failure
        warning('Could not save parameters: %s', ME.message);
        % updateStatusText(handles.status, '', ['Save FAILED: ' ME.message]);
        errordlg(['Could not save parameters: ' ME.message], 'Save Error');
    end
end
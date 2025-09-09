function visualizeMasksCallback(hObject)
    % Retrieve the handles structure
    handles = guidata(hObject);

    % Call the external function to save detections
    uniqueDetections = handles.ciliaDetections;
        
    % display messages 
    set(handles.WAITstatus, 'String', 'WAIT');
    msg = sprintf(' ... Displaying Mask for illustration.');  %
    updateStatusText(handles.status,  msg, '');

    % Call the visualization function with the necessary parameters
    visualize_cilia_masks(handles.stack,  uniqueDetections, handles.params);
    
    % save the cilia mask to a picture somwhere  
    fullFileName = fullfile(handles.filePath, handles.fileName);
        % Extract directory and base name
        [nd2Dir, baseName, ~] = fileparts(fullFileName);
        % Construct the save filename
        saveFileName = [baseName '_cilia_masks.png'];
        if ~isfolder([nd2Dir, filesep 'MatlabQuantif'])
            mkdir([nd2Dir, filesep 'MatlabQuantif']);
        end
        savePath = fullfile([nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName]);

        % finally save the image
        exportgraphics(gcf, savePath, 'Resolution', 300);
        
        % close this new figure
        %     pause
        figure(handles.fig);


    set(handles.WAITstatus, 'String', '');
    msg = sprintf('Done.');  % or any dynamic message
    
end

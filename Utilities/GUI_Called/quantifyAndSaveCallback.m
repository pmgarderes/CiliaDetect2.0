function quantifyAndSaveCallback(hObject)
    % Retrieve the handles structure
    handles = guidata(hObject);
    
    uniqueDetections = handles.ciliaDetections;

    % display messages 
    set(handles.WAITstatus, 'String', 'WAIT');
    msg = sprintf(' ... Quantifying fluorescence and morphology.');  %
    updateStatusText(handles.status,  msg, '');

    % Perform quantification
    results = quantify_cilia_fluorescence3(handles.stack, uniqueDetections, handles.params, handles.metadata );

    % Convert results to a table
    resultsTable = struct2table(results);
    
    %  Extract directory and base name
    fullFileName = fullfile(handles.filePath, handles.fileName);
    % Construct the output filename
    [nd2Dir, baseName, ~] = fileparts(fullFileName);
    outputDir = fullfile(nd2Dir, 'MatlabQuantif');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    outputFilename = fullfile(outputDir, [baseName '_cilia_quantification_results.xlsx']);

    % Write the table to an Excel file
    writetable(resultsTable, outputFilename);

    set(handles.WAITstatus, 'String', '');
    msg = sprintf('Quantification has been done.');  % or any dynamic message
    updateStatusText(handles.status,  msg, '');

%     % Notify the user
%     msgbox(['Fluorescence quantification saved to: ' outputFilename], 'Save Successful');
end

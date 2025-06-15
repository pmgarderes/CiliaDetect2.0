function uniqueDetections = load_cilia_detections(nd2FilePath, ciliaDetections, uniqueDetections)
    % Save cilia detections to the parent folder of the ND2 file.    % Extract the parent directory of the ND2 file
    [nd2Dir, baseName, ~] = fileparts(nd2FilePath);
    parentDir = fileparts(nd2Dir);  % One level up

    % Construct the save filename
    saveFileName = [baseName '_cilia_detections.mat'];
    if ~isfolder([nd2Dir, filesep 'MatlabQuantif'])
        mkdir([nd2Dir, filesep 'MatlabQuantif']);
    end
%     savePath = fullfile([nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName]);
    loadpath = [nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName];
    load(loadpath)
end
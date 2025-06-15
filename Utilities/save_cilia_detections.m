function save_cilia_detections(nd2FilePath, ciliaDetections, uniqueDetections)
    % Save cilia detections to the parent folder of the ND2 file.
    %
    % Inputs:
    %   nd2FilePath      - Full path to the original ND2 file (string)
    %   ciliaDetections  - Cell array of all cilia detection structs
    %   uniqueDetections - Cell array of deduplicated cilia detection structs

    % Validate inputs
    if nargin < 3
        error('Function requires three inputs: nd2FilePath, ciliaDetections, and uniqueDetections.');
    end

    % Extract the parent directory of the ND2 file
    [nd2Dir, baseName, ~] = fileparts(nd2FilePath);
%     parentDir = fileparts(nd2Dir);  % One level up

    % Construct the save filename
    saveFileName = [baseName '_cilia_detections.mat'];
    if ~isfolder([nd2Dir, filesep 'MatlabQuantif'])
        mkdir([nd2Dir, filesep 'MatlabQuantif']);
    end
    savePath = fullfile([nd2Dir, filesep 'MatlabQuantif' filesep  saveFileName]);
      
    % Save the detections
    try
        save(savePath, 'ciliaDetections', 'uniqueDetections');
        fprintf('Cilia detections saved to: %s\n', savePath);
    catch ME
        warning('Failed to save cilia detections: %s', ME.message);
    end
end

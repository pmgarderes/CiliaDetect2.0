function uniqueDetections = deduplicate_cilia_detections2(ciliaDetections, overlapThreshold)
    % deduplicate_cilia_detections removes overlapping and zero-area cilia detections.
    %
    % Inputs:
    %   ciliaDetections   - Cell array of detection structs with fields:
    %       - mask: binary mask of the cilium
    %       - channel: channel number
    %       - zplane: Z-plane number
    %       - click: [x, y] coordinates of the user click
    %   overlapThreshold  - Scalar between 0 and 1 indicating the minimum
    %                       overlap ratio to consider detections as duplicates
    %
    % Output:
    %   uniqueDetections  - Cell array of deduplicated detection structs with added 'area' field

    if nargin < 2
        overlapThreshold = 0.5; % Default threshold
    end

    % Step 1: Remove detections with zero-area masks and compute area
    validDetections = {};
    for i = 1:numel(ciliaDetections)
        mask = ciliaDetections{i}.mask;
        area = sum(mask(:));
        if area > 0
            det = ciliaDetections{i};
            det.area = area;  % Add area field
            validDetections{end+1} = det; %#ok<AGROW>
        end
    end

    numDetections = numel(validDetections);
    keepFlags = true(1, numDetections);

    % Step 2: Deduplicate based on overlap
    for i = 1:numDetections
        if ~keepFlags(i)
            continue;
        end
        mask1 = validDetections{i}.mask;
        area1 = validDetections{i}.area;

        for j = i+1:numDetections
            if ~keepFlags(j)
                continue;
            end
            % Check if detections are in the same channel and Z-plane
            if validDetections{i}.channel ~= validDetections{j}.channel || ...
               validDetections{i}.zplane ~= validDetections{j}.zplane
                continue;
            end

            mask2 = validDetections{j}.mask;
            area2 = validDetections{j}.area;

            % Compute overlap
            overlap = sum(mask1(:) & mask2(:));
            minArea = min(area1, area2);
            overlapRatio = overlap / minArea;

            if overlapRatio > overlapThreshold
                % Remove the detection with the smaller area
                if area1 >= area2
                    keepFlags(j) = false;
                else
                    keepFlags(i) = false;
                    break; % No need to compare i with other detections
                end
            end
        end
    end

    uniqueDetections = validDetections(keepFlags);
end

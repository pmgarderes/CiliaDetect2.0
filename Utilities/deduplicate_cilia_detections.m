function uniqueDetections = deduplicate_cilia_detections(ciliaDetections, overlapThreshold)
    % deduplicate_cilia_detections removes overlapping cilia detections.
    %
    % Inputs:
    %   ciliaDetections - cell array of detection structs with fields:
    %       - mask: binary mask of the cilium
    %       - channel: channel number
    %       - zplane: Z-plane number
    %       - click: [x, y] coordinates of the user click
    %   overlapThreshold - scalar between 0 and 1 indicating the minimum
    %                      overlap ratio to consider detections as duplicates
    %
    % Output:
    %   uniqueDetections - cell array of deduplicated detection structs

    if nargin < 2
        overlapThreshold = 0.5; % Default threshold
    end

    numDetections = numel(ciliaDetections);
    keepFlags = true(1, numDetections);

    for i = 1:numDetections
        if ~keepFlags(i)
            continue;
        end
        mask1 = ciliaDetections{i}.mask;
        area1 = sum(mask1(:));

        for j = i+1:numDetections
            if ~keepFlags(j)
                continue;
            end
            % Check if detections are in the same channel and Z-plane
            if ciliaDetections{i}.channel ~= ciliaDetections{j}.channel || ...
               ciliaDetections{i}.zplane ~= ciliaDetections{j}.zplane
                continue;
            end

            mask2 = ciliaDetections{j}.mask;
            area2 = sum(mask2(:));

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

    uniqueDetections = ciliaDetections(keepFlags);
end

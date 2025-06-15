% Extract click coordinates from each detection
clicks = cell2mat(cellfun(@(d) d.click, uniqueDetections, 'UniformOutput', false));

% Identify unique click coordinates
[uniqueClicks, ~, idx] = unique(clicks, 'rows');

% Determine if any duplicates exist
if size(uniqueClicks, 1) < size(clicks, 1)
    disp('Some click coordinates are duplicated.');
    
    % Find indices of duplicate entries
    [~, ~, ic] = unique(clicks, 'rows');
    duplicateIndices = find(histc(ic, 1:max(ic)) > 1);
    
    % Display duplicate click coordinates
    disp('Duplicate click coordinates:');
    disp(uniqueClicks(duplicateIndices, :));
else
    disp('All click coordinates are unique.');
end

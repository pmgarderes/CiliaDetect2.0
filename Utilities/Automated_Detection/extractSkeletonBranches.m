function [branches, seedPoints] = extractSkeletonBranches(binaryImage)
% EXTRACTSKELETONBRANCHES Extracts individual branches from a skeletonized image.
%
%   [branches, seedPoints] = extractSkeletonBranches(binaryImage)
%
%   Inputs:
%       binaryImage - 2D binary image (logical matrix) representing the structures.
%
%   Outputs:
%       branches    - Cell array where each cell contains a binary image of an individual branch.
%       seedPoints  - Nx2 array of [x, y] coordinates representing seed points for each branch.

    % Ensure the image is binary
    binaryImage = logical(binaryImage);

    % Step 1: Skeletonize the image
    skeleton = bwmorph(binaryImage, 'skel', Inf);

    % Step 2: Identify branch points and endpoints
    branchPoints = bwmorph(skeleton, 'branchpoints');
    endPoints = bwmorph(skeleton, 'endpoints');

    % Step 3: Remove branch points to separate branches
    skeletonWithoutBranches = skeleton & ~branchPoints;

    % Step 4: Label connected components (individual branches)
    labeledBranches = bwlabel(skeletonWithoutBranches);

    % Step 5: Extract individual branches and their seed points
    numBranches = max(labeledBranches(:));
    branches = cell(numBranches, 1);
    seedPoints = zeros(numBranches, 2); % Preallocate for speed

    for k = 1:numBranches
        % Create binary image for the k-th branch
        branchImage = (labeledBranches == k);
        branches{k} = branchImage;

        % Find coordinates of pixels in the branch
        [yCoords, xCoords] = find(branchImage);

        % Compute the centroid as the seed point
        seedX = mean(xCoords);
        seedY = mean(yCoords);
        seedPoints(k, :) = [seedX, seedY];
    end
end

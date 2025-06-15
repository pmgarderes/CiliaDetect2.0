function [skeleton, prunedSkeleton] = skeletonizeAndPrune(binaryImage, minBranchLength)
% SKELETONIZEANDPRUNE Skeletonizes and prunes a binary image.
%
%   [skeleton, prunedSkeleton] = skeletonizeAndPrune(binaryImage, minBranchLength)
%
%   Inputs:
%       binaryImage      - 2D binary image (logical matrix).
%       minBranchLength  - Minimum branch length to retain (in pixels).
%
%   Outputs:
%       skeleton         - Skeletonized image.
%       prunedSkeleton   - Pruned skeletonized image.

    % Validate input image
    if ~islogical(binaryImage)
        error('Input must be a binary image of type logical.');
    end

    % Skeletonization
    skeleton = bwskel(binaryImage);

    % Pruning: remove branches shorter than minBranchLength
    prunedSkeleton = bwskel(binaryImage, 'MinBranchLength', minBranchLength);
end

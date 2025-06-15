% Load grayscale image
inputImg = imgStack{4}(:,:,1);%imread('sample_image.tif');

% Define detection parameters
params.gaussianSigma = 1.0;
params.tophatRadius = 10;
params.minArea = 10;
params.maxArea = 1500;
params.minEccentricity = 0.8;
params.maxEccentricity = 1.0;
params.minBranchLength = 10;

% Detect cilia seed points
seedPoints = detectCiliaSeeds(inputImg, params);

% Visualize results
imshow(inputImg, []); hold on;
plot(seedPoints(:,1), seedPoints(:,2), 'r+', 'MarkerSize', 10, 'LineWidth', 1.5);
title('Detected Cilia Seed Points');
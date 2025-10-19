function [imgStack, metadata] = load_tiff_stack_downsampled_native(filepath, param)
% Native TIFF reader + closest-group downsampling (grayscale multipage).
% Returns imgStack as {1} = [Y x X x nGroups], and a minimal metadata struct.

if ~isfield(param,'DSfactor') || param.DSfactor < 1
    error('param.DSfactor must be >= 1');
end
DS = round(param.DSfactor);

info = imfinfo(filepath);
nPages = numel(info);

% Read first page to inspect
A1 = imread(filepath, 1, 'Info', info);
if ndims(A1) == 3 && size(A1,3) == 3
    % Single RGB page -> grayscale
    A1 = rgb2gray(A1);
end
[H,W] = size(A1);

% Build 3D stack (grayscale)
if nPages == 1
    Z = 1;
    Vol = zeros(H,W,1, class(A1));
    Vol(:,:,1) = A1;
else
    Z = nPages;
    Vol = zeros(H,W,Z, class(A1));
    Vol(:,:,1) = A1;
    for k = 2:Z
        Ak = imread(filepath, k, 'Info', info);
        if ndims(Ak) == 3 && size(Ak,3) == 3
            Ak = rgb2gray(Ak);
        end
        Vol(:,:,k) = Ak;
    end
end

% Grouping along Z: closest to DS (no drops)
[bounds, sizes] = make_groups(Z, DS, 'closest');
nG = size(bounds,1);

% Accumulate per group (mean)
out = zeros(H,W,nG, 'double');
for g = 1:nG
    a = bounds(g,1); b = bounds(g,2);
    block = double(Vol(:,:,a:b));
    out(:,:,g) = mean(block, 3);
end

imgStack = { uint16(out) };  % single-channel cell for consistency

% ---- Metadata
metadata = struct();
metadata.series = 1;
metadata.sizeX = W; metadata.sizeY = H;
metadata.sizeZ = Z; metadata.sizeC = 1; metadata.sizeT = 1;
metadata.format = 'TIFF';
[px_um, py_um] = tiff_pixel_size_um(info(1));
metadata.pixelSizeX_um = px_um;
metadata.pixelSizeY_um = py_um;
metadata.pixelSizeZ_um = NaN;     % not available in plain TIFF
metadata.pixelSize_units = struct('X','derived','Y','derived','Z','');
metadata.grouping = 'closest';
metadata.group_sizes = { sizes }; % per "channel"
end

% ---------- helpers ----------




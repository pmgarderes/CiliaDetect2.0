function [imgStack, metadata] = load_czi_image_downsampled(filepath, param)
% Requires bfmatlab on path
if ~isfield(param,'DSfactor'), param.DSfactor = 1; end
if ~isfield(param,'series'),   param.series   = 1; end
if ~isfield(param,'channel'),  param.channel  = 1; end
if ~isfield(param,'time'),     param.time     = 1; end

import loci.formats.Memoizer
import loci.formats.ImageReader
import loci.formats.services.OMEXMLServiceImpl

r = bfGetReader(filepath);
cleanupObj = onCleanup(@() r.close());

% Select series
nSeries = r.getSeriesCount();
s = min(param.series, max(1,nSeries));
r.setSeries(s-1);

% Sizes
SZ = r.getSizeZ(); SC = r.getSizeC(); ST = r.getSizeT();
H  = r.getSizeY(); W  = r.getSizeX();

c  = min(param.channel, max(1,SC));
t  = min(param.time,    max(1,ST));

% Prefer Z dimension; if SZ==1 but T>1, use T as stack
useZ = SZ > 1 || ST == 1;
stackLen = useZ * max(1,SZ) + (~useZ) * max(1,ST);

imgStack = zeros(H, W, stackLen, 'uint16');

for k = 1:stackLen
    if useZ
        z = k;
        index = r.getIndex(z-1, c-1, t-1) + 1;
    else
        z = 1;
        tNow = k;
        index = r.getIndex(z-1, c-1, tNow-1) + 1;
    end
    plane = bfGetPlane(r, index);
    if ~isa(plane,'uint16'), plane = im2uint16(mat2gray(plane)); end
    imgStack(:,:,k) = plane;
end

% Downsample if needed
if param.DSfactor > 1
    scale = 1/param.DSfactor;
    for k = 1:size(imgStack,3)
        imgStack(:,:,k) = imresize(imgStack(:,:,k), scale, 'bilinear');
    end
end

% Metadata
ome = r.getMetadataStore();
metadata = struct();
metadata.pixelSizeX_um = tryDouble(@() ome.getPixelsPhysicalSizeX(0).value().doubleValue()) * 1e6;
metadata.pixelSizeY_um = tryDouble(@() ome.getPixelsPhysicalSizeY(0).value().doubleValue()) * 1e6;
metadata.pixelSizeZ_um = tryDouble(@() ome.getPixelsPhysicalSizeZ(0).value().doubleValue()) * 1e6;
metadata.sizeZ = SZ; metadata.sizeC = SC; metadata.sizeT = ST;
metadata.series = s; metadata.channel = c; metadata.time = t;
metadata.originalSizeYX = [H W];
metadata.format = 'CZI';

% Adjust pixel sizes if downsampled
if param.DSfactor > 1
    f = param.DSfactor;
    if ~isnan(metadata.pixelSizeX_um), metadata.pixelSizeX_um = metadata.pixelSizeX_um * f; end
    if ~isnan(metadata.pixelSizeY_um), metadata.pixelSizeY_um = metadata.pixelSizeY_um * f; end
end
end

function v = tryDouble(f)
try, v = f(); catch, v = NaN; end
end

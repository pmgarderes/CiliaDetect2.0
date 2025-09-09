function [imgStack, metadata] = load_nd2_image_downsampled(filename, param)
% Load ND2, average/sum contiguous planes per channel with near-uniform group sizes.
%
% INPUTS
%   filename : full path to .nd2
%   param.DSfactor : target planes-per-average (e.g., 10)
%   param.fluorescenceMode : 'mean' (default) or 'sum'
%   param.grouping : 'balanced' (default) | 'fixed_include_remainder' | 'fixed_truncate'
%
% OUTPUTS
%   imgStack : cell of length C; each is [Y x X x nGroups] (uint16)
%   metadata : struct with sizes, pixel sizes (µm), group sizes per channel, etc.

    assert(isfield(param,'DSfactor') && param.DSfactor>=1, 'Please define param.DSfactor >= 1');
    if ~isfield(param,'fluorescenceMode'), param.fluorescenceMode = 'mean'; end
%     if ~isfield(param,'grouping'),         param.grouping         = 'balanced'; end
    if ~isfield(param,'grouping'), param.grouping = 'closest'; end
    assert(exist('bfGetReader','file')==2, 'Bio-Formats not found. Add bfmatlab to your path.');

    % --- Reader
    r = bfGetReader(filename);
    cleanupObj = onCleanup(@() r.close());
    r.setSeries(0);  % first series

    SX = r.getSizeX(); SY = r.getSizeY();
    SZ = max(1, r.getSizeZ());
    SC = r.getSizeC();
    ST = max(1, r.getSizeT());
    nPlanes = r.getImageCount();

    fprintf('ND2: %s | [%d x %d], Z=%d, C=%d, T=%d, Planes=%d\n', ...
        filename, SX, SY, r.getSizeZ(), SC, r.getSizeT(), nPlanes);

    % --- Metadata (read value+unit and convert to µm; NO hard-coded 1e6)
    ome = r.getMetadataStore();
    [px_um, px_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeX(0)));
    [py_um, py_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeY(0)));
    [pz_um, pz_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeZ(0)));

    metadata = struct();
    metadata.sizeX = SX; metadata.sizeY = SY;
    metadata.sizeZ = r.getSizeZ(); metadata.sizeC = SC; metadata.sizeT = r.getSizeT();
    metadata.format = 'ND2';
    metadata.pixelSizeX_um = px_um; metadata.pixelSizeY_um = py_um; metadata.pixelSizeZ_um = pz_um;
    metadata.pixelSize_units = struct('X',px_unit,'Y',py_unit,'Z',pz_unit); % for traceability
    metadata.grouping = param.grouping;
    metadata.group_sizes = cell(SC,1);

    % --- Build per-channel plane order (Z changes fastest, then T)
    % This is a consistent "contiguous" order per channel.
    % If you prefer to replicate *acquisition* order exactly, we can
    % iterate over r.getImageCount() and filter by channel via getZCTCoords.
    imgStack = cell(SC,1);
    for c = 1:SC
        idxList = zeros(SZ*ST, 1);
        k = 0;
        for t = 1:ST
            for z = 1:SZ
                k = k + 1;
                idxList(k) = r.getIndex(z-1, c-1, t-1) + 1; % 1-based for MATLAB
            end
        end
        idxList = idxList(:);
        n = numel(idxList);

        % --- Make groups
        DS = max(1, round(param.DSfactor));
        [bounds, sizes] = make_groups(n, DS, param.grouping); % inclusive [start,end]
        metadata.group_sizes{c} = sizes;

        % --- Read & accumulate
        nGroups = size(bounds,1);
        out = zeros(SY, SX, nGroups, 'double');
        for g = 1:nGroups
            a = bounds(g,1); b = bounds(g,2);
            acc = zeros(SY, SX, 'double');
            for ii = a:b
                plane = double(bfGetPlane(r, idxList(ii)));
                acc = acc + plane;
            end
            if strcmpi(param.fluorescenceMode,'sum')
                out(:,:,g) = acc;
            else
                out(:,:,g) = acc / (b - a + 1);
            end
        end
        imgStack{c} = uint16(out);
    end
end

% ----------------- helpers -----------------

function x = tryGet(fun)
    try, x = fun(); catch, x = []; end
end

function [val_um, unit_str] = readLenUM(lenObj)
% Convert an OME Length object to micrometers, preserving unit label
% lenObj may be [] or may lack unit; we handle robustly.
    if isempty(lenObj), val_um = NaN; unit_str = ''; return; end
    try
        v = lenObj.value().doubleValue();
        u = char(lenObj.unit().getSymbol());  % e.g. 'µm', 'nm', 'mm', 'm'
    catch
        % Some older BF versions use getUnit() differently; fall back
        try
            v = lenObj.value().doubleValue();
            u = 'µm';  % assume micrometers if unit unavailable
        catch
            val_um = NaN; unit_str = ''; return;
        end
    end
    unit_str = u;

    switch lower(strrep(u,'μ','µ'))  % normalize mu char
        case {'µm','um','micrometer','micrometre'}
            f = 1;
        case 'nm'
            f = 1e-3;
        case 'mm'
            f = 1e3;
        case 'm'
            f = 1e6;
        otherwise
            % Unknown unit; assume µm
            f = 1;
    end
    val_um = v * f;
end

% ---- helpers ------------------------------------------------------------

function [bounds, sizes] = make_groups(n, DS, policy)
% Partition 1..n into contiguous groups closest to target size DS.
% Returns [start,end] (inclusive) and vector of group sizes.

    switch lower(policy)
        case 'closest'
            % Pick number of groups so that the average group size n/G is
            % closest to DS, then distribute as evenly as possible.
            G = max(1, round(n / DS));
            q = floor(n / G);          % base size
            r = n - q*G;               % first r groups get +1
            sizes = [repmat(q+1, r, 1); repmat(q, G-r, 1)];

            bounds = zeros(G,2);
            s = 1;
            for g = 1:G
                e = s + sizes(g) - 1;
                bounds(g,:) = [s, e];
                s = e + 1;
            end

        case 'fixed_include_remainder'
            G = ceil(n / DS);
            sizes = repmat(DS, G, 1);
            sizes(end) = n - DS*(G-1);   % last group may be < DS
            bounds = zeros(G,2);
            s = 1;
            for g = 1:G
                e = s + sizes(g) - 1;
                bounds(g,:) = [s, e];
                s = e + 1;
            end

        case 'fixed_truncate'
            G = floor(n / DS);
            sizes = repmat(DS, G, 1);
            bounds = [(0:G-1)'*DS + 1, (1:G)'*DS];

        otherwise
            error('Unknown grouping policy: %s', policy);
    end
end


% function px_um = safePx(fun)
% % Convert OME physical size (in meters) to microns if available.
%     try
%         val = fun();
%         if isempty(val)
%             px_um = NaN;
%         else
%             px_um = val.value().doubleValue() * 1e6;  % meters -> µm
%         end
%     catch
%         px_um = NaN;
%     end
% end


% % function [imgStack, metadata] = load_nd2_image_downsampled(filename, param)
% %     % INPUTS:
% %     %   filename: full path to .nd2 file
% %     %   para: struct with at least field para.DSfactor (e.g., 10)
% %     %
% %     % OUTPUTS:
% %     %   imgStack: 4D cell array, one per channel (each is Y x X x Downsampled Z/T)
% %     %   metadata: Bio-Formats metadata store for reference
% % 
% %     assert(isfield(param, 'DSfactor'), 'Please define para.DSfactor');
% %     
% %     if ~isfield(param, 'fluorescenceMode')
% %         param.fluorescenceMode = 'mean'; % Options: 'mean' or 'sum'
% %     end
% %     
% %     % Add Bio-Formats to path if not already
% %     assert(exist('bfGetReader', 'file') == 2, 'Bio-Formats not found. Add bfmatlab to your path.');
% %     
% %     % Initialize reader
% %     reader = bfGetReader(filename);
% %     
% %         % Extract plain MATLAB metadata:
% %         metadata = bf_metadata_to_struct(reader);
% %         
% %      
% %     OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
% %     metadataStore = reader.getMetadataStore();
% % 
% %     reader.setSeries(0); % Only load the first series
% %     sizeX = reader.getSizeX();
% %     sizeY = reader.getSizeY();
% %     sizeZ = reader.getSizeZ();
% %     sizeC = reader.getSizeC();
% %     sizeT = reader.getSizeT();
% %     numPlanes = reader.getImageCount(); % typically Z * C * T
% % 
% %     fprintf('Loaded ND2: [%d x %d], Z=%d, C=%d, T=%d, Planes=%d\n', ...
% %         sizeX, sizeY, sizeZ, sizeC, sizeT, numPlanes);
% % 
% %     % Preallocate image stack for each channel
% %     imgStack = cell(sizeC, 1);
% %     for c = 1:sizeC
% %         imgStack{c} = [];
% %     end
% % 
% %     % Infer layout: assume data ordered as ZCT or T-C-Z depending on acquisition
% %     stackBy = sizeZ * sizeT;
% % 
% %     % Get all planes per channel
% %     planesPerChannel = numPlanes / sizeC;
% %     planesPerGroup = param.DSfactor;
% % 
% %     if mod(planesPerChannel, param.DSfactor) ~= 0
% %         warning('Number of planes per channel (%d) is not divisible by DSfactor (%d). Truncating extra frames.', ...
% %             planesPerChannel, param.DSfactor);
% %     end
% % 
% %     numGroups = floor(planesPerChannel / param.DSfactor);
% %     for c = 1:sizeC
% %         % Allocate average stack
% %         avgStack = zeros(sizeY, sizeX, numGroups, 'double'); % use double for averaging
% % 
% %         for g = 1:numGroups
% %             sumStack = zeros(sizeY, sizeX, 'double');
% %             for i = 1:param.DSfactor
% %                 planeIdx = (c-1) + sizeC * ( (g-1)*param.DSfactor + (i-1) ) + 1;
% %                 plane = double(bfGetPlane(reader, planeIdx));
% %                 sumStack = sumStack + plane;
% %             end
% %             if strcmp(param.fluorescenceMode, 'sum')
% %                 avgStack(:,:,g) = sumStack; % / para.DSfactor;
% %             else
% %                 avgStack(:,:,g) = sumStack/ param.DSfactor;
% %             end
% %         end
% %         imgStack{c} = uint16(avgStack); % Convert back to integer
% %     end
% % 
% % %     metadata = metadataStore;
% %     reader.close();
% % end

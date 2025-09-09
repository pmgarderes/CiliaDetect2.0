function [imgStack, metadata] = load_bioformats_stack_downsampled(filename, param)
% LOAD_BIOFORMATS_STACK_DOWNSAMPLED
% Unified loader for ND2/CZI/DV (and other Bio-Formats supported files).
% Averages/sums contiguous planes per channel into groups whose sizes are
% as close as possible to the chosen DSfactor (“closest” policy).
%
% INPUTS
%   filename : full path to .nd2 / .czi / .dv (any Bio-Formats-readable file)
%   param.DSfactor : target planes-per-average (scalar >=1), e.g., 10
%   param.fluorescenceMode : 'mean' (default) or 'sum'
%   param.grouping : 'closest' (default) | 'fixed_include_remainder' | 'fixed_truncate'
%   param.series (optional) : 1-based series index to load (default = 1)
%
% OUTPUTS
%   imgStack : cell array length C; each is [Y x X x nGroups] (uint16)
%   metadata : struct with sizes, pixel sizes (µm), group sizes per channel, etc.
%
% REQUIREMENTS
%   - Bio-Formats MATLAB toolbox (bfmatlab) must be on the MATLAB path.
%     https://www.openmicroscopy.org/bio-formats/downloads/
%
% EXAMPLE
%   param = struct('DSfactor', 10, 'fluorescenceMode','mean', 'grouping','closest');
%   [imgs, meta] = load_bioformats_stack_downsampled('myfile.nd2', param);

    % ---- Checks & defaults
    assert(isfield(param,'DSfactor') && param.DSfactor>=1, 'Please define param.DSfactor >= 1');
    if ~isfield(param,'fluorescenceMode'), param.fluorescenceMode = 'mean'; end
    if ~isfield(param,'grouping'),         param.grouping         = 'closest'; end
    if ~isfield(param,'series'),           param.series           = 1; end
    assert(exist('bfGetReader','file')==2, 'Bio-Formats not found. Add bfmatlab to your path.');

    % ---- Reader
    r = bfGetReader(filename);
    cleanupObj = onCleanup(@() r.close());

    % Series selection (1-based for user; 0-based for BF)
    nSeries = r.getSeriesCount();
    s = min(max(1, param.series), nSeries);
    r.setSeries(s-1);

    SX = r.getSizeX(); SY = r.getSizeY();
    SZ_raw = r.getSizeZ(); ST_raw = r.getSizeT();
    SZ = max(1, SZ_raw);
    ST = max(1, ST_raw);
    SC = r.getSizeC();
    nPlanes = r.getImageCount();

    fprintf('%s | Series %d/%d | [%d x %d], Z=%d, C=%d, T=%d, Planes=%d\n', ...
        filename, s, nSeries, SX, SY, SZ_raw, SC, ST_raw, nPlanes);

    % ---- Metadata (convert to µm safely; do not blindly multiply)
    ome = r.getMetadataStore();
    [px_um, px_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeX(s-1)));
    [py_um, py_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeY(s-1)));
    [pz_um, pz_unit] = readLenUM(tryGet(@() ome.getPixelsPhysicalSizeZ(s-1)));

    metadata = struct();
    metadata.series = s;
    metadata.sizeX = SX; metadata.sizeY = SY;
    metadata.sizeZ = SZ_raw; metadata.sizeC = SC; metadata.sizeT = ST_raw;
    metadata.format = upper(get_ext(filename));
    metadata.pixelSizeX_um = px_um; metadata.pixelSizeY_um = py_um; metadata.pixelSizeZ_um = pz_um;
    metadata.pixelSize_units = struct('X',px_unit,'Y',py_unit,'Z',pz_unit);
    metadata.grouping = param.grouping;
    metadata.group_sizes = cell(SC,1);

    if isnan(px_um) || isnan(py_um)
        warning('%s: pixel size X/Y in µm missing; downstream physical measures may be off.', metadata.format);
    end

    % ---- Per-channel stacking (Z changes fastest within each T)
    imgStack = cell(SC,1);
    for c = 1:SC
        % Build nominal Z→T contiguous order for channel c
        idx_nominal = zeros(SZ*ST, 1);
        k = 0;
        for t = 1:ST
            for z = 1:SZ
                k = k + 1;
                idx_nominal(k) = r.getIndex(z-1, c-1, t-1) + 1; % MATLAB 1-based
            end
        end

        % Sanity-check against actual planes per channel; fallback to acquisition order if needed
        expected_per_chan = nPlanes / SC;
        if abs(numel(idx_nominal) - expected_per_chan) > 0.5  % tolerate tiny FP issues
            idxList = build_idx_acquisition_order(r, c);
        else
            idxList = idx_nominal;
        end
        n = numel(idxList);

        % ---- Grouping (closest to DSfactor, no drops)
        DS = max(1, round(param.DSfactor));
        [bounds, sizes] = make_groups(n, DS, param.grouping);
        metadata.group_sizes{c} = sizes;

        % ---- Read & accumulate into groups
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
                out(:,:,g) = acc;                 % beware of potential uint16 clipping later
            else
                out(:,:,g) = acc / (b - a + 1);   % mean
            end
        end

        % Cast to uint16 (clip if sum mode might overflow)
        if strcmpi(param.fluorescenceMode,'sum')
            imgStack{c} = uint16(min(out, 65535));
        else
            imgStack{c} = uint16(out);
        end
    end
end

% ========================================================================
% Helpers (kept inside this file for a clean, single-script drop-in)
% ========================================================================

function ext = get_ext(fname)
    [~,~,ext0] = fileparts(fname);
    if isempty(ext0), ext = ''; else, ext = ext0(2:end); end
end

function x = tryGet(fun)
    try, x = fun(); catch, x = []; end
end

function [val_um, unit_str] = readLenUM(lenObj)
% Convert an OME Length object to micrometers, preserving unit label.
% lenObj may be [] or may lack unit; handle robustly.
    if isempty(lenObj), val_um = NaN; unit_str = ''; return; end
    try
        v = lenObj.value().doubleValue();
        if ~isempty(lenObj.unit())
            u = char(lenObj.unit().getSymbol());  % 'µm','nm','mm','m', etc.
        else
            u = 'µm';
        end
    catch
        try
            v = lenObj.value().doubleValue();
            u = 'µm';
        catch
            val_um = NaN; unit_str = ''; return;
        end
    end
    unit_str = u;

    % Normalize Greek mu
    u_norm = lower(strrep(u,'μ','µ'));
    switch u_norm
        case {'µm','um','micrometer','micrometre'}
            f = 1;
        case 'nm'
            f = 1e-3;
        case 'mm'
            f = 1e3;
        case 'm'
            f = 1e6;
        otherwise
            f = 1;  % assume µm
    end
    val_um = v * f;
end

function idxList = build_idx_acquisition_order(r, c)
% Build plane indices for channel c in true acquisition order (robust).
% Uses Bio-Formats getZCTCoords over all planes, filtering by channel.
    nP = r.getImageCount();
    buf = zeros(ceil(nP / max(1,r.getSizeC())), 1);
    kk = 0;
    for p = 0:nP-1
        zct = r.getZCTCoords(p);   % [z,c,t], 0-based
        if (zct(2)+1) == c
            kk = kk + 1;
            buf(kk) = p + 1;       % MATLAB 1-based
        end
    end
    idxList = buf(1:kk);
end

function [bounds, sizes] = make_groups(n, DS, policy)
% Partition 1..n into contiguous groups according to policy.
% Returns [start,end] (inclusive) and vector of group sizes.
    switch lower(policy)
        case 'closest'
            % Choose number of groups G so that n/G is closest to DS,
            % then distribute as evenly as possible (sizes differ by <=1).
            G = max(1, round(n / DS));
            q = floor(n / G);
            r = n - q*G;                    % first r groups have size q+1
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
            sizes(end) = n - DS*(G-1);
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

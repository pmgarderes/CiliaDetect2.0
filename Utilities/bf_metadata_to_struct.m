function meta = bf_metadata_to_struct(reader)
% Convert Bio-Formats metadata (Java) into a plain MATLAB struct.
% Focus on pixel sizes and core dimensions.

    mr = reader.getMetadataStore();   % MetadataRetrieve
    meta = struct();

    % --- Core dimensions ---
    try, meta.sizeX = mr.getPixelsSizeX(0).getValue(); catch, meta.sizeX = []; end
    try, meta.sizeY = mr.getPixelsSizeY(0).getValue(); catch, meta.sizeY = []; end
    try, meta.sizeZ = mr.getPixelsSizeZ(0).getValue(); catch, meta.sizeZ = []; end
    try, meta.sizeC = mr.getPixelsSizeC(0).getValue(); catch, meta.sizeC = []; end
    try, meta.sizeT = mr.getPixelsSizeT(0).getValue(); catch, meta.sizeT = []; end

    % --- Physical pixel sizes (X, Y, Z) ---
    [meta.pixelSizeX, meta.pixelSizeXUnit] = getLengthSafe(@() mr.getPixelsPhysicalSizeX(0));
    [meta.pixelSizeY, meta.pixelSizeYUnit] = getLengthSafe(@() mr.getPixelsPhysicalSizeY(0));
    [meta.pixelSizeZ, meta.pixelSizeZUnit] = getLengthSafe(@() mr.getPixelsPhysicalSizeZ(0));

    % Convenient shorthand (µm if units are µm; empty otherwise)
    if strcmpi(meta.pixelSizeXUnit, 'µm') || strcmpi(meta.pixelSizeXUnit, 'um')
        meta.pixelSizeX_um = meta.pixelSizeX;
    end
    if strcmpi(meta.pixelSizeYUnit, 'µm') || strcmpi(meta.pixelSizeYUnit, 'um')
        meta.pixelSizeY_um = meta.pixelSizeY;
    end
    if strcmpi(meta.pixelSizeZUnit, 'µm') || strcmpi(meta.pixelSizeZUnit, 'um')
        meta.pixelSizeZ_um = meta.pixelSizeZ;
    end

    % --- Time increment (per frame), if present ---
    [meta.timeIncrement, meta.timeIncrementUnit] = getTimeSafe(@() mr.getPixelsTimeIncrement(0));

    % --- Channel info (names / wavelengths if present) ---
    try
        C = meta.sizeC; 
        if isempty(C) || isnan(C), C = mr.getChannelCount(0); end
    catch
        C = [];
    end
    meta.channelNames = cell(1, max(0,double(C)));
    meta.emissionWavelength_nm = nan(1, max(0,double(C)));
    meta.exposureTime_ms = nan(1, max(0,double(C)));

    for c = 1:numel(meta.channelNames)
        idx = javaMethod('valueOf','java.lang.Integer',c-1); % 0-based
        % Name
        try
            nm = mr.getChannelName(0, idx);
            if ~isempty(nm), meta.channelNames{c} = char(nm); end
        catch, end
        % Emission wavelength
        [lam, unitLam] = getLengthSafe(@() mr.getChannelEmissionWavelength(0, idx));
        if ~isempty(lam)
            if strcmpi(unitLam,'nm')
                meta.emissionWavelength_nm(c) = lam;
            elseif strcmpi(unitLam,'µm') || strcmpi(unitLam,'um')
                meta.emissionWavelength_nm(c) = lam * 1000;
            end
        end
        % Exposure time
        [expv, expu] = getTimeSafe(@() mr.getChannelExposureTime(0, idx));
        if ~isempty(expv)
            if contains(lower(expu),'ms')
                meta.exposureTime_ms(c) = expv;
            elseif contains(lower(expu),'s')
                meta.exposureTime_ms(c) = expv * 1000;
            end
        end
    end

    % nested helpers:
    function [val, unitStr] = getLengthSafe(fh)
        val = []; unitStr = '';
        try
            q = fh();  % ome.units.quantity.Length
            if ~isempty(q)
                val = q.value().doubleValue();     % numeric value
                unitStr = char(q.unit().getSymbol());  % e.g., 'µm'
            end
        catch
        end
    end

    function [val, unitStr] = getTimeSafe(fh)
        val = []; unitStr = '';
        try
            q = fh();  % ome.units.quantity.Time
            if ~isempty(q)
                val = q.value().doubleValue();
                unitStr = char(q.unit().getSymbol());  % e.g., 's', 'ms'
            end
        catch
        end
    end
end

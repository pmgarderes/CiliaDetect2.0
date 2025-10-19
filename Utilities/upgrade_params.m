function p = upgrade_params(p)
% Add missing new fields; map legacy ones if they exist.
    if ~isfield(p,'prefilterEnable'),  p.prefilterEnable  = false; end
    if ~isfield(p,'prefilterScalePx'), p.prefilterScalePx = 2.0;  end
    if ~isfield(p,'lineBridgeEnable'), p.lineBridgeEnable = false; end

    % If legacy structured prefilter existed, map a sensible scale:
    if isfield(p,'prefilter') && isstruct(p.prefilter)
        if isfield(p.prefilter,'bilatSpatialSigma')
            p.prefilterScalePx = p.prefilter.bilatSpatialSigma;
        elseif isfield(p.prefilter,'gaussianSigma')
            p.prefilterScalePx = p.prefilter.gaussianSigma;
        end
        if isfield(p.prefilter,'method') && ~strcmpi(p.prefilter.method,'none')
            p.prefilterEnable = true;
        end
        % Drop-through: we ignore other legacy knobs on purpose to keep UI compact
    end

    % If legacy lineClose existed, map its enable only.
    if isfield(p,'lineClose') && isstruct(p.lineClose) && isfield(p.lineClose,'enable')
        p.lineBridgeEnable = logical(p.lineClose.enable);
    end
end

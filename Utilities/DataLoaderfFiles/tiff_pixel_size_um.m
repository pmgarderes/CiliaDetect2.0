function [px_um, py_um] = tiff_pixel_size_um(info1)
% Try to infer pixel size from TIFF X/YResolution and ResolutionUnit.
% Common units: 'Inch' or 'Centimeter'. Returns NaN if unknown.
    px_um = NaN; py_um = NaN;
    try
        if isfield(info1,'ResolutionUnit') && isfield(info1,'XResolution') && isfield(info1,'YResolution')
            ru = info1.ResolutionUnit;  % 'Inch' or 'Centimeter' or 'None'
            xr = double(info1.XResolution);
            yr = double(info1.YResolution);
            switch lower(ru)
                case 'inch'
                    % pixels per inch -> µm/pixel
                    px_um = 25_400 / xr;
                    py_um = 25_400 / yr;
                case 'centimeter'
                    % pixels per cm -> µm/pixel
                    px_um = 10_000 / xr;
                    py_um = 10_000 / yr;
                otherwise
                    % Unknown: leave NaN
            end
        end
    catch
        % leave NaN
    end
end
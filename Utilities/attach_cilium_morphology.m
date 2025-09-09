function results = attach_cilium_morphology(results, i, mask, Metadata)
% Appends simple morphology metrics to results(i)
% Safe on empty masks and keeps everything flat (no nested structs).

if ~isempty(Metadata)
    R = measure_cilium_simple(mask, Metadata, i);   % from previous message

    % Store (flat fields so they sit next to your other metrics)
    results(i).Length_um       = R.Length_um;
    results(i).Width_um_mean   = R.Width_um_mean;   % area / length
    results(i).Curviness       = R.Curviness;       % tortuosity
    results(i).LW_Ratio        = R.LW_Ratio;        % length / width
    results(i).Area_um2        = R.Area_um2;

else
    % Store (flat fields so they sit next to your other metrics)
    results(i).Length_um       = NaN;
    results(i).Width_um_mean   = NaN;   % area / length
    results(i).Curviness       = NaN;       % tortuosity
    results(i).LW_Ratio        = NaN;        % length / width
    results(i).Area_um2        = NaN;
end


end

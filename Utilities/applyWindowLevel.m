function applyWindowLevel(handles)
    w = max(handles.windowWidth, eps);
    L = handles.windowLevel;
    caxis(handles.ax, [L - w/2, L + w/2]);   % or: caxis(handles.ax, ...)
end

% % function applyWindowLevel(handles)
% % % --- helper to apply WL/WW back to the axes ---
% %     w = max( eps, handles.windowWidth );              % avoid zero
% %     L = handles.windowLevel;
% %     newCLim = [L - w/2, L + w/2];
% %     caxis(handles.ax, newCLim);                        % caxis(handles.ax,newCLim) pre‑R2022a
% % end
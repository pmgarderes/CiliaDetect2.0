function applyLW(H)
% helper to apply L/W -> CLim
    set(H.ax,'CLim',[H.windowLevel - H.windowWidth/2, ...
                     H.windowLevel + H.windowWidth/2], 'CLimMode','manual');
end
function updateStatusText(hText, line1, line2)
    if ~ishandle(hText), return; end
    if nargin < 3 || isempty(line2), line2 = ''; end
    set(hText, 'String', sprintf('%s\n%s', line1, line2));
    if length(line2)>40 
        line2 = [line2(1:40) , '...' ]; end
    drawnow;          % <-- force paint now (not limitrate)
    pause(0);         % <-- yield to event loop so text shows before heavy ops
end


% % function updateStatusText(hText, line1, line2)
% %     if ~ishandle(hText), return; end
% %     if nargin < 3 || isempty(line2), line2 = ''; end
% %     set(hText, 'String', sprintf('%s\n%s', line1, line2));
% %     drawnow limitrate nocallbacks;
% % end

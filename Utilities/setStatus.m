function setStatus(H, line1, line2)
    if ~isfield(H,'status') || ~ishandle(H.status), return; end
    if nargin < 3 || isempty(line2), line2 = ''; end
    set(H.status, 'String', sprintf('%s\n%s', line1, line2));
end
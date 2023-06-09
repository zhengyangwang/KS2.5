% FT_POSTAMBLE_SAVEFIG is a helper script that optionally saves the output
% MATLAB figure to a *.fig and to a *.png file on disk. This is useful for
% batching and for distributed processing. This makes use of the
% cfg.outputfile variable.
%
% Use as
%   ft_postamble savefig
%
% See also FT_PREAMBLE, FT_POSTAMBLE, FT_POSTAMBLE_SAVEVAR

% Copyright (C) 2019, Robert Oostenveld, DCCN
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% the output data should be saved to a MATLAB file
if (isfield(cfg, 'outputfile') && ~isempty(cfg.outputfile)) || exist('Fief7bee_reproducescript', 'var')
  
  if isfield(cfg, 'outputlock') && ~isempty(cfg.outputlock)
    mutexlock(cfg.outputlock);
  end
  
  if exist('Fief7bee_reproducescript', 'var')
    % write the output figure to a MATLAB file
    iW1aenge_now = datestr(now, 30);
    cfg.outputfile = fullfile(Fief7bee_reproducescript, sprintf('%s_%s_output',...
      iW1aenge_now, FjmoT6aA_highest_ft)); % the file extension is added later
    
    % write the large configuration fields to a MATLAB file
    % this applies to layout, event, sourcemodel, headmodel, grad, etc.
    % note that this is here, rather than in the (seemingly more logical)
    % ft_preamble_loadvar, because this code depends on cfg.callinfo (which
    % is only present at postamble stage)
    cfg = save_large_cfg_fields(cfg, FjmoT6aA_highest_ft, Fief7bee_reproducescript, iW1aenge_now);
    
    % write a snippet of MATLAB code with the user-specified configuration and function call
    reproducescript(Fief7bee_reproducescript, fullfile(Fief7bee_reproducescript, 'script.m'),...
      FjmoT6aA_highest_ft, cfg, false);
    
  elseif (isfield(cfg, 'outputfile') && ~isempty(cfg.outputfile))
    % keep the output file as it is
    
  else
    % don't write to an output file
    cfg.outputfile = {};
  end
  
  % save the current figure to a MATLAB .fig and to a .png file
  if ~isempty(cfg.outputfile)
    [Fief7bee_p, Fief7bee_f, Fief7bee_x] = fileparts(cfg.outputfile);
    Fief7bee_outputfile = fullfile(Fief7bee_p, [Fief7bee_f, '.fig']);
    ft_info('writing output figure to file ''%s''\n', Fief7bee_outputfile);
    savefig(gcf, Fief7bee_outputfile, 'compact')
    Fief7bee_outputfile = fullfile(Fief7bee_p, [Fief7bee_f, '.png']);
    ft_info('writing screenshot to file ''%s''\n', Fief7bee_outputfile);
    set(gcf, 'PaperOrientation', 'portrait');
    print(Fief7bee_outputfile, '-dpng');
  end
  
  if isfield(cfg, 'outputlock') && ~isempty(cfg.outputlock)
    mutexunlock(cfg.outputlock);
  end
  
end


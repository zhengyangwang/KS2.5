function [s, cfg] = ft_statfun_indepsamplesT(cfg, dat, design)

% FT_STATFUN_INDEPSAMPLEST calculates the independent samples T-statistic on the
% biological data in dat (the dependent variable), using the information on the
% independent variable (ivar) in design.
%
% Use this function by calling one of the high-level statistics functions as
%   [stat] = ft_timelockstatistics(cfg, timelock1, timelock2, ...)
%   [stat] = ft_freqstatistics(cfg, freq1, freq2, ...)
%   [stat] = ft_sourcestatistics(cfg, source1, source2, ...)
% with the following configuration option:
%   cfg.statistic = 'ft_statfun_indepsamplesT'
%
% You can specify the following configuration options:
%   cfg.computestat    = 'yes' or 'no', calculate the statistic (default='yes')
%   cfg.computecritval = 'yes' or 'no', calculate the critical values of the test statistics (default='no')
%   cfg.computeprob    = 'yes' or 'no', calculate the p-values (default='no')
%
% The following options are relevant if cfg.computecritval='yes' and/or cfg.computeprob='yes':
%   cfg.alpha = critical alpha-level of the statistical test (default=0.05)
%   cfg.tail  = -1, 0, or 1, left, two-sided, or right (default=1)
%               cfg.tail in combination with cfg.computecritval='yes'
%               determines whether the critical value is computed at
%               quantile cfg.alpha (with cfg.tail=-1), at quantiles
%               cfg.alpha/2 and (1-cfg.alpha/2) (with cfg.tail=0), or at
%               quantile (1-cfg.alpha) (with cfg.tail=1).
%
% The experimental design is specified as:
%   cfg.ivar  = independent variable, row number of the design that contains the labels of the conditions to be compared (default=1)
%
% The labels for the independent variable should be specified as the number 1 and 2.
%
% See also FT_TIMELOCKSTATISTICS, FT_FREQSTATISTICS or FT_SOURCESTATISTICS

% Copyright (C) 2006, Eric Maris
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

% set the defaults
cfg.computestat    = ft_getopt(cfg, 'computestat', 'yes');
cfg.computecritval = ft_getopt(cfg, 'computecritval', 'no');
cfg.computeprob    = ft_getopt(cfg, 'computeprob', 'no');
cfg.alpha          = ft_getopt(cfg, 'alpha', 0.05);
cfg.tail           = ft_getopt(cfg, 'tail', 1);
cfg.ivar           = ft_getopt(cfg, 'ivar', 1);

% perform some checks on the configuration
if strcmp(cfg.computeprob,'yes') && strcmp(cfg.computestat,'no')
  % probabilities can only be calculated if the test statistics are calculated
  cfg.computestat = 'yes';
end
if isfield(cfg,'uvar') && ~isempty(cfg.uvar)
  ft_error('cfg.uvar should not exist for an independent samples statistic');
end

% perform some checks on the design and data
sel1     = design(cfg.ivar,:)==1;
sel2     = design(cfg.ivar,:)==2;
nreplc1  = sum(~isnan(dat(:,sel1)), 2);
nreplc2  = sum(~isnan(dat(:,sel2)), 2);
nrepl    = nreplc1 + nreplc2;
hasnans1 = any(nreplc1<sum(sel1));
hasnans2 = any(nreplc2<sum(sel2));

if any(nrepl<size(design,2))
  ft_warning('Not all replications are used for the computation of the statistic.');
end
df = nrepl - 2;

if strcmp(cfg.computestat, 'yes')
  % compute the statistic, use nanmean only if necessary
  if hasnans1
    avg1 = nanmean(dat(:,sel1), 2);
    var1 = nanvar(dat(:,sel1), 0, 2);
  else
    avg1 = mean(dat(:,sel1), 2);
    var1 = var(dat(:,sel1), 0, 2);
  end
  if hasnans2
    avg2 = nanmean(dat(:,sel2), 2);
    var2 = nanvar(dat(:,sel2), 0, 2);
  else
    avg2 = mean(dat(:,sel2), 2);
    var2 = var(dat(:,sel2), 0, 2);
  end

  % compute the combined variance
  varc = ((nreplc1-1).*var1 + (nreplc2-1).*var2) .* (1./nreplc1 + 1./nreplc2) ./ df;

  % in the case of non-equal trial lengths, and TFRs as input-data, nreplc are
  % vectors with different values. When the trial lengths are equal, and the
  % input is a TFR, nreplc are vectors with either zeros (all trials contain nan
  % meaning that t_ftimwin did not fit around data), or the number of trials
  s.stat = (avg1 - avg2)./sqrt(varc);
end

if strcmp(cfg.computecritval,'yes')
  % also compute the critical values
  s.df      = df;
  if all(df==df(1)), df = df(1); end
  if cfg.tail==-1
    s.critval = tinv(cfg.alpha,df);
  elseif  cfg.tail==0
    s.critval = [tinv(cfg.alpha/2,df),tinv(1-cfg.alpha/2,df)];
  elseif cfg.tail==1
    s.critval = tinv(1-cfg.alpha,df);
  end
end

if strcmp(cfg.computeprob,'yes')
  % also compute the p-values
  s.df      = df;
  if cfg.tail==-1
    s.prob = tcdf(s.stat,s.df);
  elseif  cfg.tail==0
    s.prob = 2*tcdf(-abs(s.stat),s.df);
  elseif cfg.tail==1
    s.prob = 1-tcdf(s.stat,s.df);
  end
end

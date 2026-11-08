function res = analyze_mppt(log, Ts_mppt, tol, name)
%ANALYZE_MPPT  Tracking efficiency and settling time from a logged run.
%   res = analyze_mppt(log, Ts_mppt, tol, name)
%     log      struct with t, V, I, G (vectors) and T (scalar)
%              - from mppt_avg_sim, or built from Simulink logs
%     Ts_mppt  MPPT update period, used as the averaging window [s]
%     tol      settling band, e.g. 0.02 = within 2% of P_max
%     name     label for printouts (optional)
%
%   Definitions used (state them in your report):
%     tracking efficiency = integral(P_pv dt) / integral(P_max(G(t)) dt)
%     settling time       = time from the irradiance step until the power,
%                           averaged over one Ts_mppt window, last enters
%                           and then stays inside (1-tol)*P_max for the
%                           rest of that irradiance segment
%     steady-state ripple = peak-to-peak of averaged P over the last 20%
%                           of each segment

if nargin < 3 || isempty(tol),  tol  = 0.02;  end
if nargin < 4,                  name = '';    end

% Resample onto a uniform grid (Simulink logs may be non-uniform)
[t, iu] = unique(log.t(:));       % drop repeated time stamps, if any
Vl = log.V(:); Il = log.I(:); Gl = log.G(:);
dt = median(diff(t));
tu = (t(1):dt:t(end))';
V  = interp1(t, Vl(iu), tu);
I  = interp1(t, Il(iu), tu);
G  = interp1(t, Gl(iu), tu, 'previous');
P  = V.*I;

w    = max(1, round(Ts_mppt/dt));
Pavg = movmean(P, w);

% P_max for each irradiance level (cached)
Gs = unique(G);
Pm = zeros(size(Gs));
for k = 1:numel(Gs)
    [~, ~, Pm(k)] = pv_mpp(Gs(k), log.T);
end
Pmax = zeros(size(G));
for k = 1:numel(Gs)
    Pmax(G == Gs(k)) = Pm(k);
end

% Segments of constant irradiance
edges = [1; find(diff(G) ~= 0) + 1; numel(G) + 1];
nseg  = numel(edges) - 1;
res.segment = struct('G', {}, 'Pmax', {}, 'eta', {}, 'settle', {}, ...
                     'P_ss', {}, 'ripple_pp', {});
for s = 1:nseg
    idx = edges(s):edges(s+1)-1;
    ts  = tu(idx) - tu(idx(1));
    pa  = Pavg(idx);
    pm  = Pmax(idx(1));

    valid = 1:numel(idx) - w;                 % drop the window at the end
    bad   = find(pa(valid) < (1 - tol)*pm, 1, 'last');
    if isempty(bad)
        settle = 0;
    elseif bad == numel(valid)
        settle = NaN;                         % never settled
    else
        settle = ts(bad + 1);
    end

    tail = idx(round(0.8*numel(idx)):end);
    seg.G         = G(idx(1));
    seg.Pmax      = pm;
    seg.eta       = trapz(tu(idx), P(idx)) / trapz(tu(idx), Pmax(idx));
    seg.settle    = settle;
    seg.P_ss      = mean(P(tail));
    seg.ripple_pp = max(Pavg(tail)) - min(Pavg(tail));
    res.segment(s) = seg;
end

res.eta_total = trapz(tu, P) / trapz(tu, Pmax);
res.t = tu; res.P = P; res.Pavg = Pavg; res.Pmax = Pmax;

% Printout
fprintf('\n=== %s ===\n', name);
fprintf('Overall tracking efficiency: %.2f %%\n', 100*res.eta_total);
fprintf('  G [W/m2]  Pmax [W]  eta [%%]  settle [ms]  P_ss [W]  ripple p-p [W]\n');
for s = 1:nseg
    sg = res.segment(s);
    fprintf('  %7.0f  %8.2f  %7.2f  %10.1f  %8.2f  %10.3f\n', ...
            sg.G, sg.Pmax, 100*sg.eta, 1e3*sg.settle, sg.P_ss, sg.ripple_pp);
end
end

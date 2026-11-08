%% run_offline_comparison.m
% Week 2/3 without Simulink: runs the averaged model for
%   P&O with a big step, P&O with a small step, and Incremental Conductance,
% then prints the metrics and plots power, duty cycle and panel voltage.
% Use this to get the algorithms right before running the switched model.

clear; clc;
Ts_mppt = 5e-3;
tol     = 0.02;

cases = { 1, 0.010, 'P&O,  dD = 0.010';
          1, 0.002, 'P&O,  dD = 0.002';
          2, 0.010, 'IncCond, dD = 0.010';
          2, 0.002, 'IncCond, dD = 0.002' };

prm = [];   % defaults inside mppt_avg_sim (keep in sync with mppt_params.m)
nc  = size(cases, 1);
logs = cell(nc,1);  res = cell(nc,1);
for c = 1:nc
    fprintf('Running %s ...\n', cases{c,3});
    logs{c} = mppt_avg_sim(cases{c,1}, cases{c,2}, prm);
    res{c}  = analyze_mppt(logs{c}, Ts_mppt, tol, cases{c,3});
end

%% Summary table
eta = zeros(nc,1); st = zeros(nc,3); rp = zeros(nc,1);
for c = 1:nc
    eta(c)  = 100*res{c}.eta_total;
    st(c,:) = 1e3*[res{c}.segment.settle];
    rp(c)   = mean([res{c}.segment.ripple_pp]);
end
summary = table(cases(:,3), eta, st(:,1), st(:,2), st(:,3), rp, ...
    'VariableNames', {'Case','Eta_pct','Settle_1000_ms','Settle_500_ms', ...
                      'Settle_800_ms','Mean_ripple_W'});
disp(summary)

%% Plots
figure('Name','MPPT comparison','Color','w');
tl = tiledlayout(3,1,'TileSpacing','compact');

nexttile; hold on; grid on
plot(res{1}.t, res{1}.Pmax, 'k--', 'LineWidth', 1.2, 'DisplayName', 'P_{max}');
for c = 1:nc
    plot(res{c}.t, res{c}.Pavg, 'DisplayName', cases{c,3});
end
ylabel('P_{pv} [W] (avg over T_{mppt})'); legend('Location','best');

nexttile; hold on; grid on
for c = 1:nc, plot(logs{c}.t, logs{c}.D); end
ylabel('Duty cycle D');

nexttile; hold on; grid on
for c = 1:nc, plot(logs{c}.t, logs{c}.V); end
ylabel('V_{pv} [V]'); xlabel('Time [s]');
title(tl, 'Averaged boost model: 1000 \rightarrow 500 \rightarrow 800 W/m^2');

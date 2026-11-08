%% run_simulink_cases.m  -  Week 3 on the switched Simscape model
% Needs boost_mppt.slx (see README). Required To Workspace blocks,
% Save format "Timeseries", sample time Ts_ctrl:
%   Vpv_log  - panel voltage (across C_in)
%   Ipv_log  - panel current (output of the pv_current block)
%   D_log    - duty cycle from the MPPT block
%   G_log    - irradiance
%
% Runs the same four cases as run_offline_comparison.m and analyses them.
% The switched model is slow (0.5 us step), so the runs go in parallel if
% you have Parallel Computing Toolbox; otherwise they run one after another.

clear; clc;
mppt_params;

model = 'boost_mppt';
tol   = 0.02;
cases = { 1, 0.010, 'P&O,  dD = 0.010';
          1, 0.002, 'P&O,  dD = 0.002';
          2, 0.010, 'IncCond, dD = 0.010';
          2, 0.002, 'IncCond, dD = 0.002' };
nc = size(cases,1);

load_system(model);
in(nc) = Simulink.SimulationInput(model);
for c = 1:nc
    in(c) = Simulink.SimulationInput(model);
    in(c) = in(c).setVariable('mppt_alg', cases{c,1});
    in(c) = in(c).setVariable('mppt_dD',  cases{c,2});
    in(c) = in(c).setModelParameter('StopTime', num2str(t_stop));
end

if license('test', 'Distrib_Computing_Toolbox')
    out = parsim(in, 'ShowProgress', 'on', 'TransferBaseWorkspaceVariables', 'on');
else
    out = sim(in, 'ShowProgress', 'on');
end

res = cell(nc,1);
for c = 1:nc
    lg.t = out(c).Vpv_log.Time;
    lg.V = out(c).Vpv_log.Data;
    lg.I = out(c).Ipv_log.Data;
    lg.G = out(c).G_log.Data;
    lg.D = out(c).D_log.Data;
    lg.T = T_c;
    res{c} = analyze_mppt(lg, Ts_mppt, tol, cases{c,3});
    res{c}.D = lg.D; res{c}.tD = lg.t;
end

figure('Color','w');
tiledlayout(2,1,'TileSpacing','compact');
nexttile; hold on; grid on
plot(res{1}.t, res{1}.Pmax, 'k--', 'LineWidth', 1.2, 'DisplayName', 'P_{max}');
for c = 1:nc, plot(res{c}.t, res{c}.Pavg, 'DisplayName', cases{c,3}); end
ylabel('P_{pv} [W]'); legend('Location','best');
nexttile; hold on; grid on
for c = 1:nc, plot(res{c}.tD, res{c}.D); end
ylabel('D'); xlabel('Time [s]');

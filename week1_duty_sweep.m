%% week1_duty_sweep.m  -  Week 1: open-loop boost converter check
% Needs boost_open_loop.slx (see README for how to build it):
%   DC Voltage Source  = Vin_test
%   PWM duty input     = Constant block with value D_test
%   To Workspace blocks (Save format: Timeseries):  Vout_log, IL_log
%
% For each D it runs the model to steady state, averages the last 5 ms,
% and compares with the ideal V_in/(1-D) and with the lossy estimate that
% includes the inductor resistance.

clear; clc;
mppt_params;

model  = 'boost_open_loop';
D_list = [0.2 0.4 0.6 0.8];
t_end  = 0.08;                     % D = 0.8 rings for ~40 ms; increase if not settled
t_avg  = 5e-3;

load_system(model);
in(numel(D_list)) = Simulink.SimulationInput(model);
for k = 1:numel(D_list)
    in(k) = Simulink.SimulationInput(model);
    in(k) = in(k).setVariable('D_test', D_list(k));
    in(k) = in(k).setModelParameter('StopTime', num2str(t_end));
end
out = sim(in, 'ShowProgress', 'on');

Vsim = zeros(size(D_list)); ILmin = Vsim; Vpp = Vsim; ILpp = Vsim;
for k = 1:numel(D_list)
    vo = out(k).Vout_log;  il = out(k).IL_log;
    m  = vo.Time >= t_end - t_avg;
    mi = il.Time >= t_end - t_avg;
    Vsim(k)  = mean(vo.Data(m));
    Vpp(k)   = max(vo.Data(m)) - min(vo.Data(m));
    ILmin(k) = min(il.Data(mi));
    ILpp(k)  = max(il.Data(mi)) - min(il.Data(mi));
end

D       = D_list;
V_ideal = Vin_test./(1 - D);
V_lossy = V_ideal ./ (1 + r_L./(R_load*(1 - D).^2));   % inductor ESR only
err_pct = 100*(Vsim - V_ideal)./V_ideal;

results = table(D', V_ideal', V_lossy', Vsim', err_pct', Vpp', ILpp', ILmin', ...
    'VariableNames', {'D','V_ideal','V_with_rL','V_sim','Err_vs_ideal_pct', ...
                      'Vout_ripple_pp','IL_ripple_pp','IL_min'});
disp(results)
if any(ILmin <= 0)
    warning('Inductor current reaches zero for some D: converter is in DCM there.');
end

figure('Color','w'); hold on; grid on
Df = linspace(0.05, 0.9, 200);
plot(Df, Vin_test./(1-Df), 'k-', 'DisplayName', 'Ideal V_{in}/(1-D)');
plot(Df, Vin_test./(1-Df)./(1 + r_L./(R_load*(1-Df).^2)), 'b--', ...
     'DisplayName', 'With r_L');
plot(D, Vsim, 'ro', 'MarkerFaceColor', 'r', 'DisplayName', 'Simulation');
xlabel('Duty cycle D'); ylabel('V_{out} [V]'); legend('Location','northwest');
title(sprintf('Boost converter, V_{in} = %.1f V, R = %g \\Omega', Vin_test, R_load));

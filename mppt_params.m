%% mppt_params.m  -  all parameters for Project 3 (boost converter + MPPT)
% Run this script before opening/simulating any of the Simulink models.
% Every Simulink block parameter should refer to these variable names.

%% Switching and timing
fs        = 20e3;              % switching frequency [Hz]
Ts_sim    = 1/(100*fs);        % Simscape local-solver step (0.5 us)
Ts_ctrl   = 1/(10*fs);         % sample time of the MPPT controller block (5 us)
Ts_mppt   = 5e-3;              % how often the duty cycle is updated [s]
N_avg     = round(Ts_mppt/Ts_ctrl);   % samples averaged per MPPT update

%% Panel (see pv_params.m - replace with your Project 2 numbers)
pv  = pv_params();
T_c = 25;                      % cell temperature [degC]
[Vmp_stc, Imp_stc, Pmp_stc] = pv_mpp(1000, T_c);

%% Load: must be bigger than the panel's MPP resistance at the LOWEST irradiance
G_test   = [1000 500 800];     % irradiances used in Week 3
Rmpp     = zeros(size(G_test));
for k = 1:numel(G_test)
    [vm, im] = pv_mpp(G_test(k), T_c);
    Rmpp(k)  = vm/im;
end
R_load = 20;                   % [ohm]
if R_load <= 1.3*max(Rmpp)
    warning('R_load = %.1f ohm is too close to max R_mpp = %.1f ohm. Increase it.', ...
            R_load, max(Rmpp));
end

%% Converter sizing (design point = MPP at STC)
D_mpp     = 1 - sqrt(Rmpp(1)/R_load);  % duty that puts the panel at its MPP
Vout_mpp  = Vmp_stc/(1 - D_mpp);
Iout_mpp  = Vout_mpp/R_load;

ripple_IL   = 0.20;            % inductor current ripple, fraction of Imp
ripple_Vout = 0.01;            % output voltage ripple, fraction of Vout
ripple_Vin  = 0.005;           % panel voltage ripple, fraction of Vmp

dIL   = ripple_IL*Imp_stc;
L     = Vmp_stc*D_mpp/(dIL*fs);                          % inductor [H]
C_out = Iout_mpp*D_mpp/(ripple_Vout*Vout_mpp*fs);        % output cap [F]
C_in  = dIL/(8*fs*ripple_Vin*Vmp_stc);                   % input cap [F]

% Round up to standard-ish values (comment these out to use exact values)
L     = 470e-6;
C_out = 220e-6;
C_in  = 100e-6;

r_L   = 0.05;                  % inductor ESR [ohm]  (set 0 for ideal)
R_on  = 0.02;                  % switch on-resistance [ohm]
V_f   = 0.7;                   % diode forward voltage [V] (set 0 for ideal)

% CCM check at the design point
L_crit = R_load*D_mpp*(1-D_mpp)^2/(2*fs);
if L < 1.2*L_crit
    warning('Converter may go into DCM: L = %.0f uH, L_crit = %.0f uH', L*1e6, L_crit*1e6);
end

%% MPPT settings (Week 2/3 scripts override mppt_alg and mppt_dD)
mppt_alg = 1;                  % 1 = Perturb & Observe, 2 = Incremental Conductance
mppt_dD  = 0.01;               % perturbation step in duty cycle

%% Irradiance profile for Week 3:  [time  G]
G_profile = [0.0  1000;
             0.5   500;
             1.0   800];
t_stop    = 1.5;               % [s]

%% Week 1 open-loop test
Vin_test = 17.5;               % fixed DC input voltage [V]
D_test   = 0.5;                % overridden by week1_duty_sweep.m

fprintf('Panel MPP @STC: %.2f V, %.2f A, %.1f W  (R_mpp = %.2f ohm)\n', ...
        Vmp_stc, Imp_stc, Pmp_stc, Rmpp(1));
fprintf('R_mpp at G = [%s] W/m^2: [%s] ohm\n', num2str(G_test), num2str(Rmpp, '%.2f '));
fprintf('Design: D_mpp = %.3f, Vout = %.1f V, L = %.0f uH, Cin = %.0f uF, Cout = %.0f uF\n', ...
        D_mpp, Vout_mpp, L*1e6, C_in*1e6, C_out*1e6);
fprintf('MPPT: update every %.1f ms, averaging %d samples\n', Ts_mppt*1e3, N_avg);

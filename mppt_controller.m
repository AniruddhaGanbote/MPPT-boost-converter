function D = mppt_controller(V, I, alg, dD, N)
%MPPT_CONTROLLER  Code for the MATLAB Function block in boost_mppt.slx.
%
%   Inputs (wire from Simulink):
%     V    panel voltage (across C_in)         [V]
%     I    panel current                       [A]
%     alg  1 = Perturb & Observe, 2 = Incremental Conductance  (Constant: mppt_alg)
%     dD   perturbation step                   (Constant: mppt_dD)
%     N    samples averaged per MPPT update    (Constant: N_avg)
%   Output:
%     D    duty cycle, goes to the PWM comparator
%
%   Set the block's sample time to Ts_ctrl (Property Inspector / Model
%   Explorer -> "Sample time"). The block averages V and I over N samples,
%   i.e. over Ts_mppt = N*Ts_ctrl, then performs one MPPT step. Averaging
%   over a whole number of switching periods removes the switching ripple,
%   and waiting Ts_mppt lets the converter settle after each perturbation.
%
%   In the block you can either paste this whole file, or make the block
%   body just  "D = mppt_controller(V, I, alg, dD, N);"  with this file on
%   the path. For offline runs, call  "clear mppt_controller"  first to reset
%   the persistent state.

D_init = 0.5;
D_min  = 0.05;
D_max  = 0.90;
tol_ic = 0.005;                 % Incremental Conductance dead band

persistent Dk dir sumV sumI k first P_prev V_prev I_prev
if isempty(Dk)
    Dk = D_init;  dir = 1;
    sumV = 0;  sumI = 0;  k = 0;
    first = true;
    P_prev = 0;  V_prev = 0;  I_prev = 0;
end

sumV = sumV + V;
sumI = sumI + I;
k    = k + 1;

if k >= N
    Vavg = sumV/k;
    Iavg = sumI/k;
    Pavg = Vavg*Iavg;
    sumV = 0;  sumI = 0;  k = 0;

    if first
        first = false;          % first window: just record a baseline
    elseif alg == 1
        [Dk, dir] = po_update(Pavg, P_prev, Dk, dir, dD);
    else
        Dk = inc_update(Vavg, Iavg, V_prev, I_prev, Dk, dD, tol_ic);
    end
    Dk = min(max(Dk, D_min), D_max);

    P_prev = Pavg;  V_prev = Vavg;  I_prev = Iavg;
end

D = Dk;
end

function log = mppt_avg_sim(alg, dD, prm)
%MPPT_AVG_SIM  Fast offline check of the MPPT loop - no Simulink needed.
%   log = mppt_avg_sim(alg, dD, prm)
%     alg  1 = P&O, 2 = Incremental Conductance
%     dD   duty-cycle step
%     prm  struct of parameters (see default_prm below); pass [] for defaults
%
%   Uses the AVERAGED boost model (no switching ripple):
%     C_in  dv_in/dt = I_pv(v_in) - i_L
%     L     di_L/dt  = v_in - (1-D) v_out - r_L i_L
%     C_out dv_out/dt = (1-D) i_L - v_out/R
%   integrated with RK4 at Ts_ctrl, and calls the SAME mppt_controller and
%   pv_current used in Simulink. Use it to debug the algorithms and choose
%   dD / Ts_mppt before running the slow switched Simscape model.
%   A 1.5 s run takes roughly 10-30 s in MATLAB.
%
%   log has fields t, V, I, P, D, G (column vectors) and T.

if nargin < 3 || isempty(prm)
    prm = default_prm();
end

dt     = prm.Ts_ctrl;
nsteps = round(prm.t_stop/dt);
dec    = 10;                         % keep every 10th sample in the log
nlog   = floor(nsteps/dec);

log.t = zeros(nlog,1); log.V = log.t; log.I = log.t;
log.D = log.t; log.G = log.t; log.T = prm.T_c;

clear mppt_controller                % reset persistent state
x  = [0; 0; 0];                      % [v_in; i_L; v_out]
D  = 0.5;
jl = 0;
for j = 0:nsteps-1
    t = j*dt;
    G = irradiance_at(t, prm.G_profile);

    [k1, Ipv] = f(x, G, D, prm);
    k2 = f(x + dt/2*k1, G, D, prm);
    k3 = f(x + dt/2*k2, G, D, prm);
    k4 = f(x + dt*k3,   G, D, prm);
    x  = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);

    Ipv = pv_current(x(1), G, prm.T_c);
    D   = mppt_controller(x(1), Ipv, alg, dD, prm.N_avg);

    if mod(j, dec) == 0 && jl < nlog
        jl = jl + 1;
        log.t(jl) = t;  log.V(jl) = x(1);  log.I(jl) = Ipv;
        log.D(jl) = D;  log.G(jl) = G;
    end
end
log.P = log.V.*log.I;
end

% -------------------------------------------------------------------------
function [dx, Ipv] = f(x, G, D, prm)
Ipv = pv_current(x(1), G, prm.T_c);
dx  = [ (Ipv - x(2))/prm.C_in;
        (x(1) - (1-D)*x(3) - prm.r_L*x(2))/prm.L;
        ((1-D)*x(2) - x(3)/prm.R_load)/prm.C_out ];
end

function G = irradiance_at(t, prof)
idx = find(prof(:,1) <= t, 1, 'last');
G   = prof(idx, 2);
end

function prm = default_prm()
prm.Ts_ctrl   = 5e-6;
prm.N_avg     = round(5e-3/prm.Ts_ctrl);
prm.t_stop    = 1.5;
prm.T_c       = 25;
prm.G_profile = [0 1000; 0.5 500; 1.0 800];
prm.L = 470e-6; prm.C_in = 100e-6; prm.C_out = 220e-6;
prm.R_load = 20; prm.r_L = 0.05;
end

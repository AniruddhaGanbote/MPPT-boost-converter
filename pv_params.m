function p = pv_params()
%PV_PARAMS  Single-diode panel parameters.
%   REPLACE these with the parameters you extracted in Project 2.
%   Defaults describe a generic 36-cell, ~100 W panel:
%   Voc = 21.6 V, Isc = 6.11 A, MPP ~ 17.6 V / 5.68 A at STC.
%
%   Kept as a function (not a workspace struct) so the same numbers are
%   used by the Simulink MATLAB Function block and by the offline scripts.

p.Ns   = 36;          % cells in series
p.n    = 1.2;         % diode ideality factor
p.Rs   = 0.15;        % series resistance [ohm]
p.Rsh  = 300;         % shunt resistance [ohm]
p.Isc  = 6.11;        % short-circuit current at STC [A]
p.Voc  = 21.6;        % open-circuit voltage at STC [V]
p.Ki   = 0.0032;      % Isc temperature coefficient [A/K]
p.Eg   = 1.12;        % band gap [eV]
p.Tref = 25;          % reference temperature [degC]
p.Gref = 1000;        % reference irradiance [W/m^2]
end

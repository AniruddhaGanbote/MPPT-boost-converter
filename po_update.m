function [D, dir] = po_update(P, P_prev, D, dir, dD)
%PO_UPDATE  One step of Perturb & Observe on the duty cycle.
%   If the last perturbation made power go down, reverse direction.
%   Then perturb D by dD in the current direction.
%
%   Boost converter note: raising D lowers the panel voltage
%   (R_in = R_load*(1-D)^2), so "direction" here is direction in D.

if P < P_prev
    dir = -dir;
end
D = D + dir*dD;
end

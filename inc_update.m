function D = inc_update(V, I, V_prev, I_prev, D, dD, tol)
%INC_UPDATE  One step of Incremental Conductance on the duty cycle.
%   At the MPP, dP/dV = 0  <=>  dI/dV = -I/V.
%     dI/dV > -I/V  -> left of MPP  -> raise V -> LOWER D
%     dI/dV < -I/V  -> right of MPP -> lower V -> RAISE D
%   tol is a relative dead band: no change when |dI/dV + I/V| < tol*I/V.
%   With tol = 0 it keeps hunting like P&O; a small tol lets it sit still.

if V < 0.1
    return                      % start-up: nothing meaningful to do
end
dV = V - V_prev;
dI = I - I_prev;
g  = I/V;                       % instantaneous conductance

if abs(dV) < 1e-4
    % Voltage did not move: only irradiance changed
    if dI > 1e-4
        D = D - dD;             % more current available -> raise V
    elseif dI < -1e-4
        D = D + dD;
    end
else
    e = dI/dV + g;              % proportional to dP/dV
    if e > tol*g
        D = D - dD;
    elseif e < -tol*g
        D = D + dD;
    end
end
end

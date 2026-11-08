# Project 3 – MPPT with a boost converter

All files go in one folder; add it to the MATLAB path (or `cd` into it).
Run `mppt_params` first in every session – every Simulink block parameter
below refers to a variable it creates.

| File | Purpose |
|---|---|
| `mppt_params.m` | All parameters: f_s, L, C, R, solver steps, MPPT settings, irradiance profile. Prints the design summary. |
| `pv_params.m` | Panel constants. **Replace with your Project 2 values.** |
| `pv_current.m` | Single-diode panel model I = f(V, G, T). Code-generation safe, used inside Simulink. |
| `pv_mpp.m` | True MPP for given G, T (the "maximum available" power). |
| `po_update.m` | One Perturb & Observe step. |
| `inc_update.m` | One Incremental Conductance step. |
| `mppt_controller.m` | Body of the MPPT MATLAB Function block: averaging + P&O/IncCond. |
| `mppt_avg_sim.m` | Fast averaged-model simulation in plain MATLAB (no Simulink). |
| `analyze_mppt.m` | Tracking efficiency, settling time, steady-state ripple. |
| `run_offline_comparison.m` | Week 2/3 comparison on the averaged model. |
| `week1_duty_sweep.m` | Week 1: V_out vs D on the switched model. |
| `run_simulink_cases.m` | Week 3: the same comparison on the switched model. |

**Suggested order:** `mppt_params` → `run_offline_comparison` (checks the
algorithms in ~1 min) → build `boost_open_loop.slx` → `week1_duty_sweep` →
build `boost_mppt.slx` → `run_simulink_cases`.

---

## Week 1 – `boost_open_loop.slx`

**Solver setup**
- Model Settings → Solver: *Fixed-step*, *discrete (no continuous states)*, step `Ts_sim`.
- Solver Configuration block (Simscape): tick *Use local solver*, *Backward Euler*, sample time `Ts_sim`.

**Power stage (Simscape › Electrical)**
- DC Voltage Source: `Vin_test`
- Inductor: `L`, series resistance `r_L`
- N-Channel MOSFET (or *Ideal Semiconductor Switch*): R_on `R_on`
- Diode: forward voltage `V_f` (piecewise-linear model is fine)
- Capacitor: `C_out`
- Resistor: `R_load`
- Electrical Reference + Solver Configuration

Topology: source(+) → L → node SW; switch from SW to ground; diode anode at
SW, cathode at V_out; C_out and R_load from V_out to ground.

**PWM (Simulink side)**
- Constant `D_test` → Relational Operator (`>`) ← Repeating Sequence
  (time values `[0 1/fs]`, output values `[0 1]`).
- Relational Operator → Data Type Conversion (double) → Simulink-PS Converter → switch gate.
  For a MOSFET gate, scale by ~10 V (Gain block) before the converter.
- Simscape Electrical also has a *PWM Generator (DC-DC)* block that does all of this.

**Measurements**
- Voltage Sensor across R_load → PS-Simulink Converter → To Workspace `Vout_log`.
- Current Sensor in series with L → PS-Simulink Converter → To Workspace `IL_log`.
- Both To Workspace blocks: Save format *Timeseries*, sample time `Ts_sim`.

Then run `week1_duty_sweep`. Expect V_sim slightly below the ideal curve, close
to the "with r_L" curve, and further below at D = 0.8 (switch and diode losses
grow with D – worth a sentence in the report). `IL_min > 0` confirms CCM.

---

## Week 2 – `boost_mppt.slx`

Copy `boost_open_loop.slx` and change it:

**1. Replace the DC source with the panel**
- Add C_in (`C_in`) across the converter input.
- Add a **Controlled Current Source** in parallel with C_in (current flows into the + node).
- Voltage Sensor across C_in → PS-Simulink → signal `Vpv`.
- MATLAB Function block, body: `I = pv_current(V, G, T);`
  - inputs: `Vpv`, `G`, Constant `T_c`
  - output → Simulink-PS Converter → Controlled Current Source.
  - That output is also the signal `Ipv`.
- If Simulink reports an algebraic loop, enable *Filter input* in that
  Simulink-PS Converter (time constant ≈ `Ts_sim`), or insert a Memory block.

**2. Irradiance**
- From Workspace, data `G_profile`, *Interpolate data* **unticked**, *Form output after final data value* = *Holding final value*. Output is `G`.

**3. MPPT block**
- MATLAB Function block, body: `D = mppt_controller(V, I, alg, dD, N);`
  - inputs: `Vpv`, `Ipv`, Constants `mppt_alg`, `mppt_dD`, `N_avg`.
  - Block sample time: `Ts_ctrl` (Property Inspector → Sample time, or Model Explorer).
  - Its output `D` replaces the `D_test` constant feeding the PWM comparator.

**4. Logging** – To Workspace (*Timeseries*, sample time `Ts_ctrl`):
`Vpv_log`, `Ipv_log`, `D_log`, `G_log`.

Set the stop time to `t_stop`.

---

## Week 3

`run_simulink_cases` runs P&O and IncCond with ΔD = 0.01 and 0.002 and prints:

- overall tracking efficiency = ∫P_pv dt / ∫P_max dt
- per irradiance segment: efficiency, settling time to within 2 % of P_max,
  steady-state power, and peak-to-peak power ripple

Each 1.5 s switched run is about 3 M solver steps, so expect a few minutes per case.
To make it shorter, scale `G_profile` times down (e.g. 0.3 s segments), or use
`Ts_sim = 1e-6`.

### Reference numbers from the averaged model (default panel, Ts_mppt = 5 ms)

| Case | Overall η | Settling 1000 / 500 / 800 W/m² |
|---|---|---|
| P&O, ΔD = 0.01  | ≈ 97.5 % | ≈ 60 / 90 / 55 ms |
| P&O, ΔD = 0.002 | ≈ 92 %   | ≈ 235 / 375 / 245 ms |
| IncCond, ΔD = 0.01 | ≈ 98 % | ≈ 55 / 65 / 60 ms |
| IncCond, ΔD = 0.002 | ≈ 92.5 % | ≈ 230 / 340 / 240 ms |

The small step oscillates less at steady state (~100.1 W vs ~99.9 W at 1000 W/m²)
but loses more energy during transients. On a 0.5 s segment the transient loss
dominates, which is exactly the trade-off the comparison is meant to show.
The η values include the start-up transient from D = 0.5. The switched model
will be slightly lower because of ripple.

### Things to try for extra credit
- `Ts_mppt` = 2, 5, 10 ms: too short and P&O reacts to the converter's own transient.
- Ramp irradiance (e.g. 1000 → 500 over 0.2 s) instead of steps. P&O can drift
  the wrong way during a ramp; IncCond handles it better.
- Variable-step P&O: ΔD = k·|ΔP/ΔD|, clipped.

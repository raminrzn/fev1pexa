# fev1pexa

<!-- badges: start -->
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

A **ModelsCloud wrapper** for [`resplab/fev1`](https://github.com/resplab/fev1),
the R implementation of the individualized FEV₁ decline model for COPD
described in Zafari et al., *CMAJ* 2016.

Given a patient's baseline spirometry and demographics, it projects their FEV₁
trajectory over a **16-year horizon under two scenarios** — continued smoking
and sustained quitting — each with a 95% prediction interval.

> **This package contains none of the model's mathematics.** The science lives
> in `resplab/fev1` and stays there; this repo only adapts it to the
> ModelsCloud calling convention and adds the `gateway()` entry point the
> platform dispatches to. If the lab updates `fev1`, a redeploy picks it up.

---

## Installation

```r
# install.packages("remotes")
remotes::install_git("https://github.com/raminrzn/fev1pexa", ref = "main")
```

`fev1` is pulled automatically via the `Remotes:` field. Note it lives on
**`master`**, not `main` — hence `resplab/fev1@master` in DESCRIPTION.

---

## Quick start

```r
library(fev1pexa)

model_run(get_default_input())
#>   Year     FEV1   variance FEV1_lower FEV1_upper Scenario
#> 1    0 2.500000 0.00000000   2.500000   2.500000  Smoking
#> 2    1 2.386493 0.01558353   2.141818   2.631167  Smoking
#> ...

# Unwrapped, with aliases
model_run(fev1 = 2.5, age = 70, height = 1.68, weight = 65,
          sex = "male", smoking = "current")
```

For the default patient (70-year-old male smoker, baseline FEV₁ 2.5 L), the
year-15 projection is **1.364 L** if they keep smoking versus **1.851 L** if
they quit — the ~0.49 L gap is the point of the model.

---

## Inputs

| Field | Meaning | Coding |
|---|---|---|
| `fev1_0` | Baseline FEV₁ | litres |
| `age` | Age | years |
| `height` | Height | **metres** (e.g. `1.68`) |
| `weight` | Weight | kg |
| `male` | Sex | `1`/`0`, or `sex` = `"male"`/`"female"` |
| `smoking` | Smoking status | `1` current · `0` sustained quitter (or `"current"`/`"former"`) |
| `int_effect` | Intervention effect on lung function | litres, default `0` |
| `tio` | Tiotropium | `"Yes"`/`"No"`, default `"No"` |
| `prediction_model` | Which `fev1` projection model | `1`–`4`, default `3` |

Aliases are accepted (`fev1`→`fev1_0`, `sex`→`male`, `tiotropium`→`tio`), and
unknown extra fields are ignored.

> **Height must be in metres.** The model multiplies height and height² by
> large coefficients, so a value in centimetres yields a confident but
> completely wrong trajectory. Values above 3 are rejected rather than
> silently converted — a rejected call is recoverable; a plausible wrong
> answer is not.

---

## Output

One row per projected year per scenario (32 rows: years 0–15 × 2 scenarios):

| Column | Meaning |
|---|---|
| `Year` | Years from baseline (0–15) |
| `FEV1` | Projected FEV₁ (litres) |
| `variance` | Variance of the projection |
| `FEV1_lower` / `FEV1_upper` | 95% prediction interval |
| `Scenario` | `"Smoking"` or `"QuitsSmoking"` |

---

## ModelsCloud entry points

| Function | Description |
|---|---|
| `model_run(model_input)` | Project one patient's trajectory. |
| `get_sample_input(n)` | Example patients. |
| `get_default_input()` | One baseline patient to modify. |
| `gateway(...)` | The platform's dispatcher; defaults to `model_run`. |

### Raw HTTP

```bash
curl -X POST https://core.modelscloud.resp.core.ubc.ca/call/v2/<ns>/fev1pexa \
  -H "Authorization: Bearer <ACCESS_KEY_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"funcInput": {"model_input": {
        "fev1_0": 2.5, "age": 70, "height": 1.68, "weight": 65,
        "male": 1, "smoking": 1
      }}}'
```

---

## Clinical interpretation

The model was developed in mild-to-moderate COPD (Lung Health Study) and is
intended to support conversations about the lung-function benefit of quitting.
This service returns the raw projection and applies no threshold.

> For research use. Not a medical device and not a substitute for clinical
> judgement.

---

## Reference

> Zafari Z, Sin DD, Postma DS, et al. Individualized prediction of lung-function
> decline in chronic obstructive pulmonary disease. *CMAJ.*
> 2016;188(14):1004–1011.
> doi:[10.1503/cmaj.151483](https://doi.org/10.1503/cmaj.151483)

Underlying implementation: [`resplab/fev1`](https://github.com/resplab/fev1)
(Adibi, Sadatsafavi, Zafari).

## License

GPL-3, matching `resplab/fev1`. Model © its original authors; wrapper
implementation © Ramin Rezaeianzadeh.

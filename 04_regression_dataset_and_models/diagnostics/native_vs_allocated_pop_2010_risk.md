# Native 2010 grid vs. allocated-onto-2022 grid — 2010 at-risk population

Findings from `diagnostics/native_vs_allocated_pop_2010_risk.R`, run end to end
against real data. Read-only: no pipeline script, `results_used.md`, `CLAUDE.md`
or `MIGRATION_PLAN.md` was touched, no data column renamed, no target updated.

## Step 0 — definitions, and the like-for-like construction

The two published columns are not the same estimand. They differ in **three**
ways, two of which push in opposite directions.

| | Stage 3 `pop_2010_risk_total` | Stage 2 `pop_suscept_alta_2010` |
|---|---|---|
| Weighting | **Full cell population** where `prop_suscept_total > 0` (`07_...R` L142, L147); `LIMIAR_SUSCEPT <- 0` at L51 | **× `prop_suscept`** (`03_...py` L391, L401–403) |
| Urban filter | `urbano_2010` for 2010 / `urbano_2020` for 2022, **plus** `tipo_crescimento` (L140, L186–193) | **None** |
| Scope | Urban cells only | **Whole municipality**, rural included (L336, L383) |

Also: the 2010 side is filtered by **urban in 2010**, not 2022; and
`pp_alta_2010`'s denominator `pop_2010_total` (L224) is the same urban-restricted
sum, not the municipal total at L108.

Three series are therefore built on both sides — **A** (`pop × prop_suscept`, all
cells), **B** (`pop` where `prop_suscept > 0`, all cells) and **C** (stage 3's
published rule). C initially had no native counterpart; it was reconstructed —
see below — and **C_allocated vs C_native is the headline**, since it is the only
like-for-like comparison of the quantity the regression variables are built on.

**The 2022 alignment control passed exactly**: across 395 municipalities all
three variants matched to the unit (A 13,216,182 both sides; B 30,758,441; total
105,642,648), per-municipality max gap **0.00000**.

## C_native — reconstruction and its two gates

Built from `grade_ibge_2010.parquet` by re-applying script 04's rule, taken from
`04_delimit_urban_extent.R`: `LIMIAR_BUILT <- 10` (L49), `LIMIAR_DENS <- 300`
(L54), `classificar_urbano()` (L60–68) with
`dens <- populacao / (area_total_m2 / 1e6)`, applied at L95. Numerator is the
unweighted sum of `populacao` over urban-2010 cells with
`prop_suscept_total > 0`; denominator is the urban-restricted sum.

**Both gates passed.** The C statistics printed as numbers rather than `NA`, and
no "urban-filtered only" label appeared — which happens only when (1) the
reconstructed rule reproduced `urbano_2010` exactly against
`grade_urban_form_2010_2022.parquet`, and (2) urban-2010 cells lacking a
`tipo_crescimento` label accounted for **under 0.5%** of urban-2010 population.
So the growth-type filter is non-binding on the 2010 side and **C_native is a
true counterpart of C_allocated**, not merely an urban-filtered approximation.
(The verification block prints just above the pasted excerpt; the exact
percentages are in `cache_c_native_checks.csv`.)

## Step 1 — under the like-for-like definition, the allocation is a non-event

On the 395-municipality regression sample (identical to the both-grids universe,
since C is non-zero only there):

- native **25,273,552** → allocated **25,256,353** = **−17,199, or −0.07%**
- ratio quantiles: p25 0.9998, **median 1.0000**, p75 1.0004
- **199 of 395 municipalities differ by exactly zero**
- |deviation| > 10%: 13 (3.3%); > 25%: 7 (1.8%)

### The sign is balanced, not negative

| | C (headline) | A (decomposition) | B (decomposition) |
|---|---|---|---|
| negative | 91 (23.0%) | 275 (69.6%) | — |
| positive | **105 (26.6%)** | 119 (30.1%) | — |
| exactly zero | 199 | 1 | — |
| national gap | **−0.07%** | −0.16% | −0.70% |

Under the definition the regression actually uses, slightly **more**
municipalities move up than down. The 69.6%-negative tilt seen under variant A
does not survive the like-for-like construction.

### The correlations show no under-detection signature

| Variable | Pearson | Spearman |
|---|---|---|
| `prop_favelas_2010` | −0.0066 | −0.0858 |
| `topo_prop_inclinado` | +0.0405 | +0.0011 |
| `pp_alta_2010` | +0.0807 | +0.0321 |
| `log_pop_total_2010` | −0.0229 | −0.1558 |

All four are effectively zero (n = 385; 10 municipalities have a zero on one
side). Slum share is very slightly negative, steep terrain slightly positive —
the two the hypothesis names most directly do not move together in the predicted
direction, and neither is of a magnitude that could matter.

### The previous run's −7.24% was coverage, confirmed numerically

Coverage splits as: **395 on both grids, 308 native-only, 441 common-only**. The
native-side population sitting in native-only municipalities is **945,879 =
7.09% of the native total** — which accounts for essentially all of the −7.24%
variant-A gap reported over the union. Restricted to the 395 on both grids,
variant A is −0.16%, not −7.24%.

### The `> 1000` cut is not an artifact of the allocation

Of the 41 municipalities the cut drops, **only 1 would survive on C_native**
(Xinguara, 1,465 → 231). A gives 2, B gives 30, but neither is like-for-like (no
urban filter, rural population included). For most of the 41 the two series are
**identical to the unit** (ratio exactly 1.000000), and 10 are zero under
definition C on both grids. Of the few that move, one moves *up* (Brusque,
546 → 749, ratio 1.37).

### The `g_alta` extremes are not a grid artifact either

| | count with \|g_alta\| > 500 | max |
|---|---|---|
| current pipeline | 3 | 6300.0 |
| **C_native** | **3** | **6300.0** |
| A-based sensitivity | 25 | — |

Identical. The three (Piracicaba 3545159: 0 → 63; São Paulo 3556453: 0 → 29;
Uberaba 3170107: 84 → 910) have `cnat_risk_2010` equal to `pop_2010_risk_total`
to the unit. They are genuine tiny-denominator cases that the native grid agrees
with exactly.

## Step 2 — the old file used definition C, not a native series

Old column `pop10e_risco_alta_total`, total 25,478,752, n = 387:

| Series | Correlation | Median abs. dev. | Within 1% | Total |
|---|---|---|---|---|
| C_native | 0.999778 | 3.19% | 17.3% | 25,273,552 |
| C_allocated | 0.999791 | 3.07% | 18.1% | 25,256,353 |
| A native | 0.902732 | 55.70% | 0% | 12,395,205 |
| B native | 0.998767 | 33.05% | 1.8% | 28,986,729 |

The answer to (b) is decisive at the level of *definition*: the pre-Migrate
numbers are **definition C**, the same family as the current pipeline — A and B
are ruled out by an order of magnitude. It is **not** decisive between C_native
and C_allocated: those two score identically (0.999778 vs 0.999791; 3.19% vs
3.07%), which is exactly what a −0.07% difference between them implies. The old
file cannot distinguish them because they are nearly the same number.

What the old file is *not* is a bit-match to either: its total is **~0.87% above**
both current C series, median absolute deviation ~3%, and only ~18% of
municipalities within 1%. That residual is the 6b0 rework itself, not
native-vs-allocated.

## Step 3 — the refit

The current pipeline **reproduced exactly**: 0.0859 / 0.1485 / 0.0411\*\* /
−0.0197, **N = 317**, confirming the copied `prep()` / `CTRL_ALTA` / `fit_safe()`
/ clustered SEs are faithful to `16_estimate_models.R`.

| Spec | Current (N=317) | **C_native (N=318)** | A-based sens. (N=298) | Published draft |
|---|---|---|---|---|
| (1) g_high — Compact | 0.0859 | **0.0962** | 1.1124 | −0.026 n.s. |
| (2) g_high — Sprawl | 0.1485 | **0.1312** | 0.3714 | 0.103 \*\* |
| (3) Δpp — Compact | 0.0411 \*\* | **0.0472 \*\*\*** | 0.1296 \* | 0.040 \*\*\* |
| (4) Δpp — Sprawl | −0.0197 | **−0.0199** | −0.0732 | −0.021 \* |

**Moving the 2010 side to the native grid does not materially change Table 2.**
Every sign is unchanged, magnitudes shift by roughly 10% or less, and the only
significance change is spec (3) tightening from \*\* to \*\*\* (p 0.0174 →
0.0054). Spec (3) is the most stable result in the whole exercise: 0.0411,
0.0472 and the draft's 0.040 all agree.

The gap to the published draft stays concentrated in the two `g_alta` specs (1)
and (2), and it does not close under the native grid — so it is not attributable
to the allocation.

The A-based sensitivity diverges wildly (1.1124 for compact) exactly as its
mixed-estimand construction predicts, which is why it is a sensitivity and not a
specification.

Sample arithmetic: the cut removes 41 rows under the allocated series (395 →
354, regression N = 317), **40 under C_native** (395 → 355, N = 318), and 63
under A (395 → 332, N = 298). The gap between rows-after-cut and regression N is
missing controls.

## Things that did not reconcile

1. **"12 municipalities" is 2.** `pp_alta_2010 > 0` in the old file and exactly 0
   now holds for **2** municipalities (Piracicaba 3545159, old 0.460; São Paulo
   3556453, old 0.033), not the 12 that an earlier write-up (kept in the project's
   working repository) reports. Both are 0 under **C_native** as well, so the native grid agrees they
   are empty — only the pre-6b0 file had them positive.
2. **1,144 municipalities in the union**, against a documented processing
   universe of 629 (`CLAUDE.md`, "Key sample facts"): 395 on both grids, 308
   native-only, 441 common-only. Unexplained here.
3. **Definition C is non-zero only on the 395.** The full-universe and both-grids
   C totals are identical, so C_native and C_allocated are both zero for all 749
   other municipalities. This makes the full-universe C block (median ratio
   0.0000, 948 exact zeros) uninformative — the both-grids block is the one to
   read.
4. **The old file's ~0.87% total offset** from both current C series is not
   traced further here.
5. **No municipality-name column** exists in the regression dataset, so labels
   are `NM_CIDADE`, the functional-urban-area name — hence repeated "Arranjo
   Populacional de São Paulo/SP" rows. UF is derived from the IBGE code.
6. The 14 warnings from the previous run did not recur.

## Re-running

`source()` it again; the municipality aggregates are cached in
`data/processed_data/04_regression/diagnostics/`, so the grid reads are skipped.
To redo them, delete `municipality_native_vs_allocated_2010.csv`,
`cache_native_2022_series.csv` and `cache_c_native_checks.csv`, or set
`options(nva.force_reread = TRUE)` before sourcing. The 2022 control is not
re-run from cache; its result is preserved in `control_2022_alignment.csv`.

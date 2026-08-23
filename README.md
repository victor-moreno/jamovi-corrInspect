# corrInspect

A jamovi module that clones `jmv::corrMatrix`, redesigned for cleaner output:

- **Tidy table** instead of a sparse n-by-n matrix: one row per pair (per
  method), with the 95% CI collapsed into a single `[lower, upper]` cell
  instead of separate columns. With exactly two variables this naturally
  reduces to a single row.
- **Two analysis modes, one box each**: "Variables" (all-vs-all, jmv's usual
  comparison, restyled) and an optional "Reference variable" box — set it
  and the analysis switches to comparing it against the rest of Variables,
  no separate mode switch to keep in sync.
- **Annotated scatterplots**: r, its CI and the fitted regression line
  printed on the plot itself, in the style of `jamovi-jmvplus`'s `scat`
  analysis, plus optional marginal densities.
- **Colour-coded heatmap**, its own toggle independent of the scatterplot
  option, for the all-vs-all overview with more than two variables (instead
  of jmv's plain-text matrix plot).
- **95% CI** for Pearson (exact, from `cor.test`), and for Spearman/Kendall
  via the Fisher z-transform with the Fieller, Hartley & Pearson (1957)
  variance correction (`Var(z) = 0.437/(n-4)`) — base R's `cor.test` has no
  CI for those two.

See `corrInspect/` for the R package (jamovi module). `task_plan.md`,
`findings.md` and `progress.md` at the repo root are the working notes from
building it — not shipped documentation.

## Status

Builds and installs cleanly on the user's machine (desktop + Docker, via
`tools/install.sh`) as of 2026-08-23; the dev sandbox this was written in
has a broken/mismatched jmvtools/node toolchain and could never run the
build itself (see `jamovi_build_toolchain` memory / `progress.md` for that
dead end). `R/corrCompute.R` (the pure statistics layer) is unit-tested
against base R's `cor.test` — see `corrInspect/tests/testthat/`. Feedback
from a first real test round (2026-08-23) is being worked through: options
were reshaped from an explicit "mode" selector + separate "compare with"
box down to just Variables + an optional Reference variable, the heatmap
became its own toggle instead of auto-triggering on variable count, CI
decimals now match r's 3 decimals, and Spearman/Kendall got CIs. Not yet
re-verified in a real jamovi after this round.

## Build

```r
jmvtools::prepare("corrInspect")
jmvtools::install("corrInspect")
```

## Install (desktop + Docker)

`tools/install.sh`, adapted from `jamovi-jmvplus/tools/install.sh`, builds
the module and installs it into jamovi desktop and/or a running jamovi
Docker container, with a smoke test in Docker (all-vs-all and one-vs-rest
correlations checked against base R's `cor()`):

```
bash tools/install.sh              # both targets, whichever are available
bash tools/install.sh desktop
bash tools/install.sh docker [container]   # default container: jamovi
```

Desktop expects `~/R/.Rlib-arm` or `~/R/.Rlib-x64` (per architecture) with
jmvtools installed, and `/Applications/jamovi.app`. Docker expects a running
container with `jmc` on its PATH. Not adapted from jmvplus (not asked for
yet): `prepare-jmo.sh` (repackaging a built `.jmo` for other OS/R-version
combinations) and `release.sh` (publishing `.jmo`s as a GitHub release).

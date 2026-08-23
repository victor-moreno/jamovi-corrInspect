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
- **Annotated scatterplot(s)**: r, p, the fitted regression line and its
  equation are each independently toggleable, left-aligned (with a small
  inset from the axis) in the plot's corner annotation. Light-blue points,
  black regression line and axes, regardless of jamovi's active theme. The
  y-axis is clipped to the data's own range plus headroom for the
  annotation, rather than stretching to fit the prediction band (which can
  overshoot the data, e.g. below 0 for a variable that never is). With
  more than two Variables and no reference variable, a Layout choice:
  **Matrix** (small panels, one per pair) or **Pairs** (one full-sized
  annotated scatter per pair, an array -- the same shape a reference
  variable's comparisons already used).
- **Colour-coded heatmap**, its own toggle independent of the scatterplot
  option -- both can be shown at once -- for the all-vs-all overview with
  more than two variables (instead of jmv's plain-text matrix plot), or a
  single column against the reference variable when one is set. Square
  cells (`coord_fixed()`) with the colour legend moved below rather than
  eating into them. Its coefficient (Pearson/Spearman/Kendall) is
  independently selectable, and a "Details" toggle adds each cell's
  CI/p/N/significance flag, reusing the table's own ci/sig/n/flag options
  instead of adding one per stat.
- **95% CI** for Pearson (exact, from `cor.test`), and for Spearman/Kendall
  via the Fisher z-transform with the Fieller, Hartley & Pearson (1957)
  variance correction (`Var(z) = 0.437/(n-4)`) — base R's `cor.test` has no
  CI for those two.
- **Spanish and Catalan translations** (`jamovi/i18n/es.po`, `ca.po`),
  confirmed working by the user. Covers all static yaml UI text, plus
  R-generated dynamic strings via `self$translate()` (`jmvcore::Analysis`'s
  built-in translator, reading the same compiled `inst/i18n/*.json` as the
  UI side -- confirmed by reading the jmvcore source, see
  `task_plan.md`): the method labels ("r de Pearson", not "Pearson's r")
  and the reference-mode table's title. Long tooltip descriptions aren't
  translated yet.

See `corrInspect/` for the R package (jamovi module). `task_plan.md`,
`findings.md` and `progress.md` at the repo root are the working notes from
building it — not shipped documentation.

## Status

Builds and installs cleanly on the user's machine (desktop + Docker, via
`tools/install.sh`); the dev sandbox this was written in has a
broken/mismatched jmvtools/node toolchain and could never run the build
itself (see `jamovi_build_toolchain` memory / `progress.md`). `R/corrCompute.R`
(the pure statistics layer) is unit-tested against base R's `cor.test` and
hand-derived formulas — see `corrInspect/tests/testthat/`. New ggplot2/
gridExtra plot compositions (the scatterplot matrix, the square heatmap
with a bottom legend, the left-aligned annotation) are rendered to a plain
PNG standalone before being wired into the module, to catch composition
bugs before jamovi-specific ones -- but the module itself still only gets
validated when the user builds and clicks through it. Five real-test
rounds so far (2026-08-23). `enable: (refVar)` and the translations are
now confirmed working. Open: dropping a factor variable into "Reference
variable" throws an error -- cause not yet diagnosed, waiting on the exact
error text (see `task_plan.md`).

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

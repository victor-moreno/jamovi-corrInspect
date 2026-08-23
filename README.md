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
- **Annotated scatterplot(s)**: r, its CI and the fitted regression line
  printed on the plot itself, in the style of `jamovi-jmvplus`'s `scat`
  analysis, plus optional marginal densities. With more than two Variables
  (and no reference variable), a scatterplot matrix instead of a single
  plot.
- **Colour-coded heatmap**, its own toggle independent of the scatterplot
  option -- both can be shown at once -- for the all-vs-all overview with
  more than two variables (instead of jmv's plain-text matrix plot). Its
  coefficient (Pearson/Spearman/Kendall) is independently selectable, and
  a "Details" toggle adds each cell's CI/p/N/significance flag, reusing
  the table's own ci/sig/n/flag options instead of adding one per stat.
- **95% CI** for Pearson (exact, from `cor.test`), and for Spearman/Kendall
  via the Fisher z-transform with the Fieller, Hartley & Pearson (1957)
  variance correction (`Var(z) = 0.437/(n-4)`) — base R's `cor.test` has no
  CI for those two.
- **Spanish and Catalan translations** (`jamovi/i18n/es.po`, `ca.po`) for
  all visible menu/option/table/plot text. Long tooltips and R-generated
  dynamic strings (the reference-mode table's title, method labels) aren't
  translated yet -- see `task_plan.md` for why.

See `corrInspect/` for the R package (jamovi module). `task_plan.md`,
`findings.md` and `progress.md` at the repo root are the working notes from
building it — not shipped documentation.

## Status

Builds and installs cleanly on the user's machine (desktop + Docker, via
`tools/install.sh`); the dev sandbox this was written in has a
broken/mismatched jmvtools/node toolchain and could never run the build
itself (see `jamovi_build_toolchain` memory / `progress.md`). `R/corrCompute.R`
(the pure statistics layer) is unit-tested against base R's `cor.test` and
hand-derived formulas — see `corrInspect/tests/testthat/`. Three real-test
rounds so far (2026-08-23): mode selector removed in favour of Variables +
optional Reference variable, scatterplot vs. heatmap split into two
independent toggles/Images (a genuine bug -- they couldn't both show at
once before), heatmap's coefficient made selectable, and i18n added. Not
yet re-verified in a real jamovi after this round -- in particular
`enable: (refVar)` in the `.u.yaml` (an unverified truthy-test on a
Variable-type option) and whether the translations actually apply when
switching jamovi's language.

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

# corrInspect

A jamovi module that clones `jmv::corrMatrix`, redesigned for cleaner output:

- **Tidy table** instead of a sparse n-by-n matrix: one row per pair (per
  method), with the 95% CI collapsed into a single `[lower, upper]` cell
  instead of separate columns. With exactly two variables this naturally
  reduces to a single row.
- **Two analysis modes**: "All variables vs. all" (jmv's usual comparison,
  restyled) or "One variable vs. the rest" — a reference variable (its own
  box) compared against a set of others, for inspecting candidate predictors
  or confounders before a regression.
- **Annotated scatterplots**: r, its CI and the fitted regression line
  printed on the plot itself, in the style of `jamovi-jmvplus`'s `scat`
  analysis, plus optional marginal densities.
- **Colour-coded heatmap** instead of jmv's plain-text matrix plot, for the
  all-vs-all overview with more than two variables.

See `corrInspect/` for the R package (jamovi module). `task_plan.md`,
`findings.md` and `progress.md` at the repo root are the working notes from
building it — not shipped documentation.

## Status

Code written and the pure statistics layer (`R/corrCompute.R`) is unit-tested
against base R's `cor.test` — see `corrInspect/tests/testthat/`. The jamovi
build step (`jmvtools::prepare()` / `install()`) could not be completed in
the dev sandbox: `jamovi-compiler` (bundled with `jmvtools`) fails with "a
newer version of the jamovi-compiler (or jmvtools) is required" — reproduced
on the already-working `conttables2xK` sibling module too, so it is a local
toolchain issue, not something wrong with this module's code. The sandbox's
`node` is v26.7.0 (homebrew, very recent); `jamovi-compiler` 0.3.5 most
likely wasn't built against anything that new. Try building with an older
Node (18–20) on the machine that normally builds these modules, and if the
same error appears there too, that pins the cause down further.

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

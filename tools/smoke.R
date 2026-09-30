# Smoke test, run by tools/install.sh right after installing the module into
# jamovi desktop and/or the docker container (the runner has put jamovi's
# libraries and the installed module on .libPaths() and attached it).
# Moved here from the docker target of the previous install.sh.

# all-vs-all correlations against cor()
data(mtcars)
results <- corrInspect::corrInspect(data = mtcars, vars = c("mpg", "hp"))
tbl <- results$tableAllVsAll$asDF
oracle <- cor(mtcars$mpg, mtcars$hp)
stopifnot(isTRUE(all.equal(tbl$r[1], oracle, tolerance = 1e-6)))
cat(sprintf("   allVsAll smoke test passed: r = %.3f\n", tbl$r[1]))

# one-vs-rest correlations
results <- corrInspect::corrInspect(
    data = mtcars, vars = c("hp", "wt"), refVar = "mpg"
)
tbl <- results$tableRefVsRest$asDF
stopifnot(nrow(tbl) == 2)
stopifnot(isTRUE(all.equal(tbl$r[tbl$var2 == "hp"], cor(mtcars$mpg, mtcars$hp), tolerance = 1e-6)))
stopifnot(isTRUE(all.equal(tbl$r[tbl$var2 == "wt"], cor(mtcars$mpg, mtcars$wt), tolerance = 1e-6)))
cat("   refVsRest smoke test passed\n")

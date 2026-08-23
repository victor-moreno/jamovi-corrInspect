# Pure statistics/formatting helpers for corrInspect.
# No jmvcore, no R6, no self -- testable standalone against base R.

corrMethods <- function(pearson, spearman, kendall) {
    methods <- character(0)
    if (isTRUE(pearson))  methods <- c(methods, 'pearson')
    if (isTRUE(spearman)) methods <- c(methods, 'spearman')
    if (isTRUE(kendall))  methods <- c(methods, 'kendall')
    if (length(methods) == 0)
        methods <- 'pearson'
    methods
}

methodLabel <- function(method) {
    switch(method,
        pearson  = "Pearson's r",
        spearman = "Spearman's rho",
        kendall  = "Kendall's tau-b",
        method)
}

hypothesisAlternative <- function(hypothesis) {
    switch(hypothesis, corr = 'two.sided', pos = 'greater', neg = 'less', 'two.sided')
}

starsFor <- function(p) {
    if (is.na(p)) return('')
    if (p < .001) return('***')
    if (p < .01)  return('**')
    if (p < .05)  return('*')
    ''
}

ciText <- function(low, high) {
    if (is.na(low) || is.na(high))
        return('')
    sprintf('[%.3f, %.3f]', low, high)
}

# Compact p-value text for a heatmap cell (not jamovi's own pvalue format,
# which isn't reachable from plain R).
pText <- function(p) {
    if (is.na(p))
        return('')
    if (p < .001)
        return('p<.001')
    sprintf('p=%.3f', p)
}

# Fisher z-transform CI for a rank correlation (Spearman's rho or Kendall's
# tau), using the Fieller, Hartley & Pearson (1957) variance correction
# Var(z) = 0.437/(n-4) in place of the 1/(n-3) that's exact for Pearson's r.
# base R's cor.test() has no conf.int for these methods; this is the
# standard closed-form approximation other stats packages use instead
# (recommended by Fieller et al. for |r| up to about .8).
fisherZCI <- function(r, n, ciWidth) {
    if (is.na(r) || n <= 4)
        return(list(low = NA_real_, high = NA_real_))
    z <- atanh(pmin(pmax(r, -0.9999), 0.9999))
    se <- sqrt(0.437 / (n - 4))
    zcrit <- stats::qnorm(1 - (1 - ciWidth / 100) / 2)
    list(low = tanh(z - zcrit * se), high = tanh(z + zcrit * se))
}

# One pairwise correlation. Returns r/n/p/ciLow/ciHigh, NA where undefined
# (constant variable, or fewer than 3 complete pairs).
corrFit <- function(x, y, method, alternative, ciWidth) {
    ok <- stats::complete.cases(x, y)
    x <- x[ok]
    y <- y[ok]
    n <- length(x)

    out <- list(r = NA_real_, n = n, p = NA_real_, ciLow = NA_real_, ciHigh = NA_real_)
    if (n < 3 || stats::sd(x) == 0 || stats::sd(y) == 0)
        return(out)

    fit <- tryCatch(
        stats::cor.test(x, y, method = method, alternative = alternative,
                         conf.level = ciWidth / 100),
        error = function(e) NULL)
    if (is.null(fit))
        return(out)

    out$r <- unname(fit$estimate)
    out$p <- fit$p.value
    if (method == 'pearson' && !is.null(fit$conf.int)) {
        out$ciLow  <- fit$conf.int[1]
        out$ciHigh <- fit$conf.int[2]
    } else if (method %in% c('spearman', 'kendall')) {
        ci <- fisherZCI(out$r, n, ciWidth)
        out$ciLow  <- ci$low
        out$ciHigh <- ci$high
    }
    out
}

# ggtheme (jmvcore's renderFun 3rd-arg-equivalent) is theme + 2 discrete
# palette scales, packed as a list -- `p + ggtheme` is only safe when the
# plot declares no scale of its own. Pull just the theme back out for plots
# (like the heatmap) that need a continuous scale instead.
themeOnly <- function(ggtheme) {
    if (is.null(ggtheme))
        return(NULL)
    if (inherits(ggtheme, 'theme'))
        return(ggtheme)
    parts <- Filter(function(x) inherits(x, 'theme'), ggtheme)
    if (length(parts) == 0L) NULL else parts[[1L]]
}

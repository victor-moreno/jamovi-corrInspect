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
    sprintf('[%.2f, %.2f]', low, high)
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

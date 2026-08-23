
corrInspectClass <- R6::R6Class(
    "corrInspectClass",
    inherit = corrInspectBase,
    private = list(

        .init = function() {
            private$.initTable()
            private$.initPlots()
        },

        .run = function() {
            if (private$.isRefMode())
                private$.runRefVsRest()
            else
                private$.runAllVsAll()
            private$.updateVisibility()
        },

        # analysis mode is derived, not a separate option: a reference
        # variable set means "one vs. the rest", empty means "all vs. all".
        .isRefMode = function() length(self$options$refVar) > 0,

        # the comparison set for "one vs. the rest": Variables minus the
        # reference variable, in case the user put it in both boxes.
        .restVars = function() {
            refVar <- self$options$refVar
            if (length(refVar) == 0)
                return(self$options$vars)
            setdiff(self$options$vars, refVar)
        },

        # ---- structure (must exist by the end of .init(), see jamovi-skill) ----

        .initTable = function() {
            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)

            if (private$.isRefMode()) {
                for (v in private$.restVars()) {
                    for (m in methods) {
                        self$results$tableRefVsRest$addRow(
                            rowKey = paste(v, m, sep = '|'),
                            values = list(var2 = v, stat = methodLabel(m)))
                    }
                }
            } else {
                for (pair in private$.pairs(self$options$vars)) {
                    for (m in methods) {
                        self$results$tableAllVsAll$addRow(
                            rowKey = paste(pair[1], pair[2], m, sep = '|'),
                            values = list(var1 = pair[1], var2 = pair[2], stat = methodLabel(m)))
                    }
                }
            }
        },

        .initPlots = function() {
            n <- length(self$options$vars)
            scatterSide <- if (n <= 2) 500 else max(500, 160 * n)
            self$results$plotScatter$setSize(scatterSide, scatterSide * 0.8)
            heatmapSide <- max(400, 90 * n)
            self$results$plotHeatmap$setSize(heatmapSide, heatmapSide)

            if (private$.isRefMode()) {
                array <- self$results$plotRefVsRest
                for (v in private$.restVars()) {
                    item <- array$addItem(key = v)
                    item$setSize(450, 350)
                }
            }
        },

        .pairs = function(vars) {
            if (length(vars) < 2)
                return(list())
            utils::combn(vars, 2, simplify = FALSE)
        },

        # ---- values ----

        .runAllVsAll = function() {
            vars <- self$options$vars
            pairs <- private$.pairs(vars)
            if (length(pairs) == 0)
                return()

            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)
            alternative <- hypothesisAlternative(self$options$hypothesis)
            ciWidth <- self$options$ciWidth
            flag <- isTRUE(self$options$flag)
            data <- self$data
            tbl <- self$results$tableAllVsAll

            for (pair in pairs) {
                x <- jmvcore::toNumeric(data[[pair[1]]])
                y <- jmvcore::toNumeric(data[[pair[2]]])
                for (m in methods) {
                    fit <- corrFit(x, y, m, alternative, ciWidth)
                    tbl$setRow(rowKey = paste(pair[1], pair[2], m, sep = '|'), values = list(
                        r = fit$r,
                        ci = ciText(fit$ciLow, fit$ciHigh),
                        n = fit$n,
                        p = fit$p,
                        stars = if (flag) starsFor(fit$p) else ''
                    ))
                }
            }
        },

        .runRefVsRest = function() {
            refVar <- self$options$refVar
            restVars <- private$.restVars()
            if (length(restVars) == 0)
                return()

            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)
            alternative <- hypothesisAlternative(self$options$hypothesis)
            ciWidth <- self$options$ciWidth
            flag <- isTRUE(self$options$flag)
            data <- self$data
            tbl <- self$results$tableRefVsRest
            tbl$setTitle(paste0('Correlations — ', refVar, ' vs. others'))

            x <- jmvcore::toNumeric(data[[refVar]])
            for (v in restVars) {
                y <- jmvcore::toNumeric(data[[v]])
                for (m in methods) {
                    fit <- corrFit(x, y, m, alternative, ciWidth)
                    tbl$setRow(rowKey = paste(v, m, sep = '|'), values = list(
                        r = fit$r,
                        ci = ciText(fit$ciLow, fit$ciHigh),
                        n = fit$n,
                        p = fit$p,
                        stars = if (flag) starsFor(fit$p) else ''
                    ))
                }
            }
        },

        .updateVisibility = function() {
            refMode <- private$.isRefMode()
            vars <- self$options$vars
            hasVars <- !refMode && length(vars) >= 2

            self$results$tableAllVsAll$setVisible(!refMode)
            self$results$tableRefVsRest$setVisible(refMode)
            self$results$plotScatter$setVisible(hasVars && isTRUE(self$options$plots))
            self$results$plotHeatmap$setVisible(
                hasVars && length(vars) > 2 && isTRUE(self$options$heatmap))
            self$results$plotRefVsRest$setVisible(refMode && isTRUE(self$options$plots))
        },

        # ---- plots ----

        # "Scatterplots" and "Correlation heatmap" are independent toggles
        # (both, either, or neither can be showing at once) -- not one plot
        # auto-switching shape on variable count.
        .plotScatter = function(image, ggtheme, theme, ...) {
            if (private$.isRefMode() || !isTRUE(self$options$plots))
                return(FALSE)

            vars <- self$options$vars
            if (length(vars) < 2)
                return(FALSE)

            if (length(vars) == 2)
                return(private$.drawAnnotatedScatter(vars[1], vars[2], ggtheme, theme))
            private$.drawScatterMatrix(vars, ggtheme, theme)
        },

        .plotHeatmap = function(image, ggtheme, theme, ...) {
            if (private$.isRefMode() || !isTRUE(self$options$heatmap))
                return(FALSE)

            vars <- self$options$vars
            if (length(vars) <= 2)
                return(FALSE)

            p <- private$.heatmap(vars, ggtheme, theme)
            if (is.null(p))
                return(FALSE)
            print(p)
            TRUE
        },

        .plotRefVsRest = function(image, ggtheme, theme, ...) {
            if (!private$.isRefMode() || !isTRUE(self$options$plots))
                return(FALSE)

            refVar <- self$options$refVar
            v <- image$key
            if (length(refVar) == 0 || length(v) == 0)
                return(FALSE)

            if (self$options$refAxis == 'x')
                return(private$.drawAnnotatedScatter(refVar, v, ggtheme, theme))
            private$.drawAnnotatedScatter(v, refVar, ggtheme, theme)
        },

        # a scatter with an lm fit, its prediction band, and an r/CI/equation
        # annotation -- the same idea as jamovi-jmvplus's scat.b.R, built from
        # scratch here since this module doesn't wrap scatr::scat. Draws
        # straight to the active device and returns TRUE/FALSE, so the
        # optional marginal densities (composed with gridExtra, since ggExtra
        # isn't in this module's dependencies) can be laid out around it.
        .drawAnnotatedScatter = function(xvar, yvar, ggtheme, theme) {
            data <- self$data
            x <- jmvcore::toNumeric(data[[xvar]])
            y <- jmvcore::toNumeric(data[[yvar]])
            ok <- stats::complete.cases(x, y)
            x <- x[ok]
            y <- y[ok]
            if (length(x) < 3 || stats::sd(x) == 0 || stats::sd(y) == 0)
                return(FALSE)

            df <- data.frame(x = x, y = y)
            fit <- stats::lm(y ~ x, data = df)
            grid <- data.frame(x = seq(min(x), max(x), length.out = 100))
            pred <- stats::predict(fit, newdata = grid, interval = 'prediction')
            ribbon <- cbind(grid, as.data.frame(pred[, c('lwr', 'upr'), drop = FALSE]))

            r <- stats::cor(x, y)
            coefv <- stats::coef(fit)
            label <- sprintf('r = %.3f\n%s = %.3g + %.3g·%s',
                              r, yvar, coefv[1], coefv[2], xvar)

            if (isTRUE(self$options$ci)) {
                m <- corrFit(x, y, 'pearson', 'two.sided', self$options$ciWidth)
                if (!is.na(m$ciLow)) {
                    label <- paste0(label, sprintf('\n%s%% CI %s',
                                                    self$options$ciWidth,
                                                    ciText(m$ciLow, m$ciHigh)))
                }
            }

            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            pointColour <- if (!is.null(theme$color)) theme$color[1] else '#3366CC'
            fillColour <- if (!is.null(theme$fill)) theme$fill[1] else '#3366CC'

            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
                ggplot2::geom_ribbon(data = ribbon,
                                      mapping = ggplot2::aes(x = x, ymin = lwr, ymax = upr),
                                      inherit.aes = FALSE, fill = fillColour, alpha = 0.25) +
                ggplot2::geom_point(colour = pointColour, alpha = 0.7) +
                ggplot2::geom_smooth(method = 'lm', formula = y ~ x, se = FALSE,
                                      colour = pointColour) +
                ggplot2::annotate('text', x = -Inf, y = Inf, hjust = -0.05, vjust = 1.3,
                                   label = label, colour = textColour, size = 3.6) +
                ggplot2::labs(x = xvar, y = yvar) +
                ggtheme

            if (!isTRUE(self$options$plotDens)) {
                print(p)
                return(TRUE)
            }

            xDens <- ggplot2::ggplot(df, ggplot2::aes(x = x)) +
                ggplot2::geom_density(fill = fillColour, colour = NA) +
                ggplot2::theme_void()
            yDens <- ggplot2::ggplot(df, ggplot2::aes(x = y)) +
                ggplot2::geom_density(fill = fillColour, colour = NA) +
                ggplot2::coord_flip() +
                ggplot2::theme_void()
            blank <- ggplot2::ggplot() + ggplot2::theme_void()

            gridExtra::grid.arrange(xDens, blank, p, yDens,
                                     ncol = 2, nrow = 2,
                                     widths = c(4, 1), heights = c(1, 4))
            TRUE
        },

        # scatterplot matrix for >2 variables: lower triangle = mini scatter
        # + lm line + r per pair, diagonal = variable name, upper triangle
        # blank. No marginal densities here -- panels are too small for it.
        .drawScatterMatrix = function(vars, ggtheme, theme) {
            data <- self$data
            n <- length(vars)
            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            pointColour <- if (!is.null(theme$color)) theme$color[1] else '#3366CC'

            idx <- function(row, col) (row - 1) * n + col
            panels <- vector('list', n * n)

            for (row in seq_len(n)) {
                for (col in seq_len(n)) {
                    if (row == col) {
                        panels[[idx(row, col)]] <- grid::textGrob(
                            vars[row], gp = grid::gpar(col = textColour, fontsize = 10))
                    } else if (row > col) {
                        x <- jmvcore::toNumeric(data[[vars[col]]])
                        y <- jmvcore::toNumeric(data[[vars[row]]])
                        ok <- stats::complete.cases(x, y)
                        x <- x[ok]
                        y <- y[ok]
                        if (length(x) < 3 || stats::sd(x) == 0 || stats::sd(y) == 0) {
                            panels[[idx(row, col)]] <- grid::nullGrob()
                        } else {
                            r <- stats::cor(x, y)
                            df <- data.frame(x = x, y = y)
                            panels[[idx(row, col)]] <- ggplot2::ggplotGrob(
                                ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
                                    ggplot2::geom_point(colour = pointColour, alpha = 0.6, size = 0.8) +
                                    ggplot2::geom_smooth(method = 'lm', formula = y ~ x, se = FALSE,
                                                          colour = pointColour, linewidth = 0.5) +
                                    ggplot2::annotate('text', x = -Inf, y = Inf, hjust = -0.1, vjust = 1.3,
                                                       label = sprintf('r = %.2f', r),
                                                       colour = textColour, size = 2.6) +
                                    ggplot2::theme_void() +
                                    ggplot2::theme(panel.border = ggplot2::element_rect(
                                        colour = 'grey85', fill = NA)))
                        }
                    } else {
                        panels[[idx(row, col)]] <- grid::nullGrob()
                    }
                }
            }

            gridExtra::grid.arrange(grobs = panels, nrow = n, ncol = n)
            TRUE
        },

        # all-vs-all overview for >2 variables: a colour-coded heatmap instead
        # of jmv's plain-text matrix. Coefficient and detail level are their
        # own options (heatmapMethod/heatmapDetails), independent of which
        # methods are ticked in the table above.
        .heatmap = function(vars, ggtheme, theme) {
            data <- self$data
            method <- self$options$heatmapMethod
            alternative <- hypothesisAlternative(self$options$hypothesis)
            ciWidth <- self$options$ciWidth
            details <- isTRUE(self$options$heatmapDetails)

            pairs <- private$.pairs(vars)
            rows <- lapply(pairs, function(pair) {
                x <- jmvcore::toNumeric(data[[pair[1]]])
                y <- jmvcore::toNumeric(data[[pair[2]]])
                fit <- corrFit(x, y, method, alternative, ciWidth)
                data.frame(var1 = pair[1], var2 = pair[2], r = fit$r,
                           label = private$.heatmapCellLabel(fit, details),
                           stringsAsFactors = FALSE)
            })
            long <- do.call(rbind, rows)
            full <- rbind(
                long,
                data.frame(var1 = long$var2, var2 = long$var1, r = long$r,
                           label = long$label, stringsAsFactors = FALSE),
                data.frame(var1 = vars, var2 = vars, r = 1, label = '1.00',
                           stringsAsFactors = FALSE))

            full$var1 <- factor(full$var1, levels = vars)
            full$var2 <- factor(full$var2, levels = rev(vars))

            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            textSize <- if (details) 2.4 else 3.2

            ggplot2::ggplot(full, ggplot2::aes(x = var1, y = var2, fill = r)) +
                ggplot2::geom_tile(colour = NA) +
                ggplot2::geom_text(ggplot2::aes(label = label), colour = textColour, size = textSize) +
                ggplot2::scale_fill_gradient2(low = '#B2182B', mid = 'white', high = '#2166AC',
                                               midpoint = 0, limits = c(-1, 1)) +
                ggplot2::labs(x = NULL, y = NULL, fill = methodLabel(method)) +
                themeOnly(ggtheme)
        },

        # r (with a significance flag, if on) on its own line; CI/p/N appended
        # below it only when Details is on, and only for whichever of those
        # are already switched on in the table's own options.
        .heatmapCellLabel = function(fit, details) {
            line1 <- sprintf('%.2f', fit$r)
            if (isTRUE(self$options$flag))
                line1 <- paste0(line1, starsFor(fit$p))
            if (!details)
                return(line1)

            lines <- line1
            if (isTRUE(self$options$ci) && !is.na(fit$ciLow))
                lines <- c(lines, ciText(fit$ciLow, fit$ciHigh))
            if (isTRUE(self$options$sig) && !is.na(fit$p))
                lines <- c(lines, pText(fit$p))
            if (isTRUE(self$options$n))
                lines <- c(lines, sprintf('n=%d', fit$n))
            paste(lines, collapse = '\n')
        }
    )
)


corrInspectClass <- R6::R6Class(
    "corrInspectClass",
    inherit = corrInspectBase,
    private = list(

        .init = function() {
            private$.initTable()
            private$.initPlots()
        },

        .run = function() {
            mode <- self$options$mode
            if (mode == 'allVsAll')
                private$.runAllVsAll()
            else
                private$.runRefVsRest()
            private$.updateVisibility()
        },

        # ---- structure (must exist by the end of .init(), see jamovi-skill) ----

        .initTable = function() {
            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)

            if (self$options$mode == 'allVsAll') {
                for (pair in private$.pairs(self$options$vars)) {
                    for (m in methods) {
                        self$results$tableAllVsAll$addRow(
                            rowKey = paste(pair[1], pair[2], m, sep = '|'),
                            values = list(var1 = pair[1], var2 = pair[2], stat = methodLabel(m)))
                    }
                }
            } else {
                refVar <- self$options$refVar
                compareVars <- self$options$compareVars
                if (length(refVar) == 0 || length(compareVars) == 0)
                    return()
                for (v in compareVars) {
                    for (m in methods) {
                        self$results$tableRefVsRest$addRow(
                            rowKey = paste(v, m, sep = '|'),
                            values = list(var2 = v, stat = methodLabel(m)))
                    }
                }
            }
        },

        .initPlots = function() {
            self$results$plotAllVsAll$setSize(500, 400)

            if (self$options$mode == 'refVsRest') {
                array <- self$results$plotRefVsRest
                for (v in self$options$compareVars) {
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
            compareVars <- self$options$compareVars
            if (length(refVar) == 0 || length(compareVars) == 0)
                return()

            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)
            alternative <- hypothesisAlternative(self$options$hypothesis)
            ciWidth <- self$options$ciWidth
            flag <- isTRUE(self$options$flag)
            data <- self$data
            tbl <- self$results$tableRefVsRest
            tbl$setTitle(paste0('Correlations — ', refVar, ' vs. others'))

            x <- jmvcore::toNumeric(data[[refVar]])
            for (v in compareVars) {
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
            mode <- self$options$mode
            showPlots <- isTRUE(self$options$plots)
            self$results$plotAllVsAll$setVisible(showPlots && mode == 'allVsAll')
            self$results$plotRefVsRest$setVisible(showPlots && mode == 'refVsRest')
        },

        # ---- plots ----

        .plotAllVsAll = function(image, ggtheme, theme, ...) {
            if (!isTRUE(self$options$plots) || self$options$mode != 'allVsAll')
                return(FALSE)

            vars <- self$options$vars
            if (length(vars) < 2)
                return(FALSE)

            if (length(vars) == 2)
                return(private$.drawAnnotatedScatter(vars[1], vars[2], ggtheme, theme))

            p <- private$.heatmap(vars, ggtheme, theme)
            if (is.null(p))
                return(FALSE)
            print(p)
            TRUE
        },

        .plotRefVsRest = function(image, ggtheme, theme, ...) {
            if (!isTRUE(self$options$plots) || self$options$mode != 'refVsRest')
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

        # all-vs-all overview for >2 variables: a colour-coded heatmap instead
        # of jmv's plain-text matrix.
        .heatmap = function(vars, ggtheme, theme) {
            data <- self$data
            pairs <- private$.pairs(vars)
            rows <- lapply(pairs, function(pair) {
                x <- jmvcore::toNumeric(data[[pair[1]]])
                y <- jmvcore::toNumeric(data[[pair[2]]])
                r <- suppressWarnings(stats::cor(x, y, use = 'pairwise.complete.obs'))
                data.frame(var1 = pair[1], var2 = pair[2], r = r)
            })
            long <- do.call(rbind, rows)
            full <- rbind(
                long,
                data.frame(var1 = long$var2, var2 = long$var1, r = long$r),
                data.frame(var1 = vars, var2 = vars, r = 1))

            full$var1 <- factor(full$var1, levels = vars)
            full$var2 <- factor(full$var2, levels = rev(vars))

            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour

            ggplot2::ggplot(full, ggplot2::aes(x = var1, y = var2, fill = r)) +
                ggplot2::geom_tile(colour = NA) +
                ggplot2::geom_text(ggplot2::aes(label = sprintf('%.2f', r)),
                                    colour = textColour, size = 3.2) +
                ggplot2::scale_fill_gradient2(low = '#B2182B', mid = 'white', high = '#2166AC',
                                               midpoint = 0, limits = c(-1, 1)) +
                ggplot2::labs(x = NULL, y = NULL, fill = 'r') +
                themeOnly(ggtheme)
        }
    )
)

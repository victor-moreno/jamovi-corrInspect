
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

        # >2 variables, all-vs-all, "Pairs" layout chosen for Scatterplots.
        .pairsFormat = function() {
            !private$.isRefMode() &&
                length(self$options$vars) > 2 &&
                identical(self$options$plotsFormat, 'pairs')
        },

        # ---- structure (must exist by the end of .init(), see jamovi-skill) ----

        .initTable = function() {
            methods <- corrMethods(self$options$pearson, self$options$spearman, self$options$kendall)

            if (private$.isRefMode()) {
                for (v in private$.restVars()) {
                    for (m in methods) {
                        self$results$tableRefVsRest$addRow(
                            rowKey = paste(v, m, sep = '|'),
                            values = list(var2 = v, stat = self$translate(methodLabel(m))))
                    }
                }
            } else {
                for (pair in private$.pairs(self$options$vars)) {
                    for (m in methods) {
                        self$results$tableAllVsAll$addRow(
                            rowKey = paste(pair[1], pair[2], m, sep = '|'),
                            values = list(var1 = pair[1], var2 = pair[2],
                                          stat = self$translate(methodLabel(m))))
                    }
                }
            }
        },

        .initPlots = function() {
            vars <- self$options$vars
            n <- length(vars)
            refMode <- private$.isRefMode()

            scatterSide <- if (n <= 2) 500 else max(500, 160 * n)
            self$results$plotScatter$setSize(scatterSide, scatterSide * 0.8)

            if (refMode) {
                restN <- length(private$.restVars())
                self$results$plotHeatmap$setSize(260, max(300, 70 * restN) + 90)
            } else {
                heatmapSide <- max(400, 90 * n)
                self$results$plotHeatmap$setSize(heatmapSide, heatmapSide + 90)
            }

            array <- self$results$plotPairs
            if (refMode) {
                for (v in private$.restVars()) {
                    item <- array$addItem(key = v)
                    item$setSize(450, 350)
                }
            } else if (private$.pairsFormat()) {
                for (pair in private$.pairs(vars)) {
                    item <- array$addItem(key = paste(pair[1], pair[2], sep = '|'))
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
            tbl$setTitle(paste0(self$translate('Correlations'), ' — ', refVar, ' ',
                                 self$translate('vs. others')))

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
            n <- length(vars)
            hasVars <- !refMode && n >= 2
            showPlots <- isTRUE(self$options$plots)

            showMatrix <- hasVars && showPlots && (n == 2 || !private$.pairsFormat())
            showPairs <- showPlots && (refMode || (hasVars && private$.pairsFormat()))
            showHeatmap <- isTRUE(self$options$heatmap) && (
                (hasVars && n > 2) || (refMode && length(private$.restVars()) >= 1))

            self$results$tableAllVsAll$setVisible(!refMode)
            self$results$tableRefVsRest$setVisible(refMode)
            self$results$plotScatter$setVisible(showMatrix)
            self$results$plotPairs$setVisible(showPairs)
            self$results$plotHeatmap$setVisible(showHeatmap)
        },

        # ---- plots ----

        # "Scatterplots" and "Correlation heatmap" are independent toggles
        # (both, either, or neither can be showing at once). With more than
        # two Variables and no reference variable, "Scatterplots" itself has
        # a Layout choice: Matrix (this Image) or Pairs (plotPairs, below).
        .plotScatter = function(image, ggtheme, theme, ...) {
            if (private$.isRefMode() || !isTRUE(self$options$plots))
                return(FALSE)

            vars <- self$options$vars
            if (length(vars) < 2)
                return(FALSE)

            if (length(vars) == 2)
                return(private$.drawAnnotatedScatter(vars[1], vars[2], ggtheme, theme))
            if (private$.pairsFormat())
                return(FALSE)
            private$.drawScatterMatrix(vars, ggtheme, theme)
        },

        .plotHeatmap = function(image, ggtheme, theme, ...) {
            if (!isTRUE(self$options$heatmap))
                return(FALSE)

            vars <- self$options$vars
            if (private$.isRefMode()) {
                if (length(private$.restVars()) == 0)
                    return(FALSE)
            } else if (length(vars) <= 2) {
                return(FALSE)
            }

            p <- private$.heatmap(vars, ggtheme, theme)
            if (is.null(p))
                return(FALSE)
            print(p)
            TRUE
        },

        # one annotated scatter per item: the reference-variable comparisons
        # (key = the compared variable) or, in "Pairs" layout, every pair
        # among Variables (key = "var1|var2").
        .plotPairs = function(image, ggtheme, theme, ...) {
            if (!isTRUE(self$options$plots))
                return(FALSE)
            key <- image$key
            if (length(key) == 0)
                return(FALSE)

            if (private$.isRefMode()) {
                refVar <- self$options$refVar
                if (self$options$refAxis == 'x')
                    return(private$.drawAnnotatedScatter(refVar, key, ggtheme, theme))
                return(private$.drawAnnotatedScatter(key, refVar, ggtheme, theme))
            }

            pair <- strsplit(key, '|', fixed = TRUE)[[1]]
            if (length(pair) != 2)
                return(FALSE)
            private$.drawAnnotatedScatter(pair[1], pair[2], ggtheme, theme)
        },

        # a scatter with an optional lm fit and its confidence/prediction
        # bands, and an optional r/p/CI/equation annotation -- the same idea
        # as jamovi-jmvplus's scat.b.R, built from scratch here since this
        # module doesn't wrap scatr::scat. Always Pearson, regardless of
        # which coefficients are ticked above (a linear fit pairs with
        # Pearson's r, not a rank correlation). Fixed light-blue points +
        # black line/axes (not theme-derived) so the plot reads clearly
        # regardless of jamovi's active theme.
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
            fit <- corrFit(x, y, 'pearson', 'two.sided', self$options$ciWidth)
            lmFit <- stats::lm(y ~ x, data = df)
            coefv <- stats::coef(lmFit)

            lines <- character(0)
            if (isTRUE(self$options$plotR))
                lines <- c(lines, sprintf('r = %.3f', fit$r))
            if (isTRUE(self$options$sig) && !is.na(fit$p))
                lines <- c(lines, pText(fit$p))
            if (isTRUE(self$options$plotEquation)) {
                lines <- c(lines, sprintf('%s = %.3g + %.3g·%s',
                                           yvar, coefv[1], coefv[2], xvar))
            }
            if (isTRUE(self$options$ci) && !is.na(fit$ciLow)) {
                lines <- c(lines, sprintf('%s%% CI %s', self$options$ciWidth,
                                           ciText(fit$ciLow, fit$ciHigh)))
            }
            label <- paste(lines, collapse = '\n')

            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            pointColour <- '#5DADE2'
            lineColour <- 'black'

            p <- ggplot2::ggplot(df, ggplot2::aes(x = x, y = y))

            if (isTRUE(self$options$plotLine)) {
                grid <- data.frame(x = seq(min(x), max(x), length.out = 100))
                level <- self$options$ciWidth / 100

                # prediction band (pink) drawn first, wider and so behind
                # the confidence band (blue) where they overlap.
                if (isTRUE(self$options$plotPredBand)) {
                    predPI <- stats::predict(lmFit, newdata = grid, interval = 'prediction', level = level)
                    ribbonPI <- cbind(grid, as.data.frame(predPI[, c('lwr', 'upr'), drop = FALSE]))
                    p <- p + ggplot2::geom_ribbon(
                        data = ribbonPI, mapping = ggplot2::aes(x = x, ymin = lwr, ymax = upr),
                        inherit.aes = FALSE, fill = '#F48FB1', alpha = 0.35)
                }
                if (isTRUE(self$options$ci)) {
                    predCI <- stats::predict(lmFit, newdata = grid, interval = 'confidence', level = level)
                    ribbonCI <- cbind(grid, as.data.frame(predCI[, c('lwr', 'upr'), drop = FALSE]))
                    p <- p + ggplot2::geom_ribbon(
                        data = ribbonCI, mapping = ggplot2::aes(x = x, ymin = lwr, ymax = upr),
                        inherit.aes = FALSE, fill = pointColour, alpha = 0.35)
                }
            }

            p <- p + ggplot2::geom_point(colour = pointColour, alpha = 0.7)

            if (isTRUE(self$options$plotLine)) {
                p <- p + ggplot2::geom_smooth(method = 'lm', formula = y ~ x, se = FALSE,
                                               colour = lineColour)
            }

            if (nzchar(label)) {
                # a small nudge in from the axis -- x is a real data
                # coordinate here (not -Inf), since hjust alone can't add a
                # gap when the anchor is already the panel's edge.
                xRange <- range(x)
                xPad <- diff(xRange) * 0.02
                p <- p + ggplot2::annotate('text', x = xRange[1] + xPad, y = Inf, hjust = 0, vjust = 1.3,
                                            label = label, colour = textColour, size = 3.6)
            }

            # the prediction band can overshoot well past the data's own
            # range (e.g. below 0 for a variable that's never negative) and
            # drag the axis down with it; clip display to the data instead,
            # with headroom on top for the annotation.
            yRange <- range(y)
            ySpan <- diff(yRange)
            topPad <- if (nzchar(label)) 0.15 else 0.05
            p <- p + ggplot2::coord_cartesian(
                ylim = c(yRange[1] - ySpan * 0.05, yRange[2] + ySpan * topPad))

            p <- p +
                ggplot2::labs(x = xvar, y = yvar) +
                ggtheme +
                ggplot2::theme(
                    axis.text = ggplot2::element_text(colour = 'black'),
                    axis.title = ggplot2::element_text(colour = 'black'),
                    axis.ticks = ggplot2::element_line(colour = 'black'))

            print(p)
            TRUE
        },

        # scatterplot matrix for >2 variables ("Matrix" layout): lower
        # triangle = mini scatter + lm line + r per pair, diagonal =
        # variable name, upper triangle blank.
        .drawScatterMatrix = function(vars, ggtheme, theme) {
            data <- self$data
            n <- length(vars)
            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            pointColour <- '#5DADE2'
            lineColour <- 'black'

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
                            xPanelRange <- range(x)
                            xPanelPad <- diff(xPanelRange) * 0.05
                            panels[[idx(row, col)]] <- ggplot2::ggplotGrob(
                                ggplot2::ggplot(df, ggplot2::aes(x = x, y = y)) +
                                    ggplot2::geom_point(colour = pointColour, alpha = 0.6, size = 0.8) +
                                    ggplot2::geom_smooth(method = 'lm', formula = y ~ x, se = FALSE,
                                                          colour = lineColour, linewidth = 0.5) +
                                    ggplot2::annotate('text', x = xPanelRange[1] + xPanelPad, y = Inf,
                                                       hjust = 0, vjust = 1.3,
                                                       label = sprintf('r = %.2f', r),
                                                       colour = textColour, size = 2.6) +
                                    ggplot2::theme_minimal(base_size = 6) +
                                    ggplot2::theme(
                                        axis.text = ggplot2::element_text(colour = 'black', size = 5),
                                        axis.title = ggplot2::element_blank(),
                                        axis.ticks = ggplot2::element_line(colour = 'black'),
                                        panel.grid = ggplot2::element_blank(),
                                        panel.border = ggplot2::element_rect(
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

        # colour-coded heatmap instead of jmv's plain-text matrix. All-vs-all
        # (n x n) with no reference variable, or a single column against the
        # reference variable when one is set. Coefficient and detail level
        # are their own options (heatmapMethod/heatmapDetails), independent
        # of which methods are ticked in the table above. coord_fixed() plus
        # a bottom legend keep the cells square regardless of variable count.
        .heatmap = function(vars, ggtheme, theme) {
            data <- self$data
            method <- self$options$heatmapMethod
            alternative <- hypothesisAlternative(self$options$hypothesis)
            ciWidth <- self$options$ciWidth
            details <- isTRUE(self$options$heatmapDetails)
            refMode <- private$.isRefMode()

            if (refMode) {
                refVar <- self$options$refVar
                pairs <- lapply(private$.restVars(), function(v) c(refVar, v))
            } else {
                pairs <- private$.pairs(vars)
            }

            rows <- lapply(pairs, function(pair) {
                x <- jmvcore::toNumeric(data[[pair[1]]])
                y <- jmvcore::toNumeric(data[[pair[2]]])
                fit <- corrFit(x, y, method, alternative, ciWidth)
                data.frame(var1 = pair[1], var2 = pair[2], r = fit$r,
                           label = private$.heatmapCellLabel(fit, details),
                           stringsAsFactors = FALSE)
            })
            long <- do.call(rbind, rows)

            if (refMode) {
                full <- long
                full$var1 <- factor(full$var1, levels = self$options$refVar)
                full$var2 <- factor(full$var2, levels = rev(private$.restVars()))
            } else {
                full <- rbind(
                    long,
                    data.frame(var1 = long$var2, var2 = long$var1, r = long$r,
                               label = long$label, stringsAsFactors = FALSE),
                    data.frame(var1 = vars, var2 = vars, r = 1, label = '1.00',
                               stringsAsFactors = FALSE))
                full$var1 <- factor(full$var1, levels = vars)
                full$var2 <- factor(full$var2, levels = rev(vars))
            }

            textColour <- ggplot2::calc_element('text', themeOnly(ggtheme))$colour
            textSize <- if (details) 2.4 else 3.2

            ggplot2::ggplot(full, ggplot2::aes(x = var1, y = var2, fill = r)) +
                ggplot2::geom_tile(colour = NA) +
                ggplot2::geom_text(ggplot2::aes(label = label), colour = textColour, size = textSize) +
                ggplot2::scale_fill_gradient2(low = '#B2182B', mid = 'white', high = '#2166AC',
                                               midpoint = 0, limits = c(-1, 1)) +
                ggplot2::coord_fixed() +
                ggplot2::labs(x = NULL, y = NULL, fill = self$translate(methodLabel(method))) +
                themeOnly(ggtheme) +
                ggplot2::theme(
                    legend.position = 'bottom',
                    legend.title = ggplot2::element_text(size = 8),
                    legend.text = ggplot2::element_text(size = 7)) +
                ggplot2::guides(fill = ggplot2::guide_colorbar(
                    barwidth = grid::unit(5, 'cm'), barheight = grid::unit(0.35, 'cm')))
        },

        # r (with a significance flag, if on) on its own line; CI/p/N appended
        # below it only when Details is on, and only for whichever of those
        # are already switched on in the table's own options. CI uses 2
        # decimals here, matching r's own 2-decimal display in the heatmap
        # (the table and scatterplot annotation use 3, matching r there).
        .heatmapCellLabel = function(fit, details) {
            line1 <- sprintf('%.2f', fit$r)
            if (isTRUE(self$options$flag))
                line1 <- paste0(line1, starsFor(fit$p))
            if (!details)
                return(line1)

            lines <- line1
            if (isTRUE(self$options$ci) && !is.na(fit$ciLow))
                lines <- c(lines, ciText(fit$ciLow, fit$ciHigh, decimals = 2))
            if (isTRUE(self$options$sig) && !is.na(fit$p))
                lines <- c(lines, pText(fit$p))
            if (isTRUE(self$options$n))
                lines <- c(lines, sprintf('n=%d', fit$n))
            paste(lines, collapse = '\n')
        }
    )
)

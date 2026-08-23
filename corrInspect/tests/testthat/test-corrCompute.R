test_that("corrFit agrees with stats::cor.test (pearson)", {
    x <- mtcars$mpg
    y <- mtcars$hp
    oracle <- stats::cor.test(x, y, method = "pearson", alternative = "two.sided", conf.level = 0.95)
    fit <- corrFit(x, y, "pearson", "two.sided", 95)

    expect_equal(fit$r, unname(oracle$estimate))
    expect_equal(fit$p, oracle$p.value)
    expect_equal(fit$n, length(x))
    expect_equal(fit$ciLow, oracle$conf.int[1])
    expect_equal(fit$ciHigh, oracle$conf.int[2])
})

test_that("corrFit agrees with stats::cor.test (spearman, kendall)", {
    x <- mtcars$mpg
    y <- mtcars$wt

    for (m in c("spearman", "kendall")) {
        oracle <- suppressWarnings(stats::cor.test(x, y, method = m, alternative = "two.sided"))
        fit <- corrFit(x, y, m, "two.sided", 95)
        expect_equal(fit$r, unname(oracle$estimate))
        expect_equal(fit$p, oracle$p.value)

        z <- atanh(fit$r)
        se <- sqrt(0.437 / (fit$n - 4))
        zcrit <- qnorm(0.975)
        expect_equal(fit$ciLow, tanh(z - zcrit * se))
        expect_equal(fit$ciHigh, tanh(z + zcrit * se))
    }
})

test_that("fisherZCI is undefined for r == NA or n <= 4", {
    ci <- fisherZCI(NA_real_, 20, 95)
    expect_true(is.na(ci$low) && is.na(ci$high))

    ci <- fisherZCI(0.5, 4, 95)
    expect_true(is.na(ci$low) && is.na(ci$high))
})

test_that("fisherZCI widens as the confidence level increases", {
    narrow <- fisherZCI(0.4, 30, 90)
    wide <- fisherZCI(0.4, 30, 99)
    expect_true(wide$high - wide$low > narrow$high - narrow$low)
})

test_that("corrFit handles missing data by dropping incomplete pairs", {
    x <- c(1, 2, NA, 4, 5)
    y <- c(2, 4, 6, NA, 10)
    fit <- corrFit(x, y, "pearson", "two.sided", 95)

    expect_equal(fit$n, 3)
    expect_equal(fit$r, unname(stats::cor.test(c(1, 2, 5), c(2, 4, 10))$estimate))
})

test_that("corrFit degrades gracefully for constant or too-short input", {
    fit <- corrFit(c(1, 1, 1, 1), c(1, 2, 3, 4), "pearson", "two.sided", 95)
    expect_true(is.na(fit$r))

    fit <- corrFit(c(1, 2), c(3, 4), "pearson", "two.sided", 95)
    expect_true(is.na(fit$r))
    expect_equal(fit$n, 2)
})

test_that("corrMethods defaults to pearson when nothing is selected", {
    expect_equal(corrMethods(FALSE, FALSE, FALSE), "pearson")
    expect_equal(corrMethods(TRUE, TRUE, FALSE), c("pearson", "spearman"))
})

test_that("hypothesisAlternative maps to cor.test's alternative", {
    expect_equal(hypothesisAlternative("corr"), "two.sided")
    expect_equal(hypothesisAlternative("pos"), "greater")
    expect_equal(hypothesisAlternative("neg"), "less")
})

test_that("starsFor matches conventional thresholds", {
    expect_equal(starsFor(0.5), "")
    expect_equal(starsFor(0.04), "*")
    expect_equal(starsFor(0.005), "**")
    expect_equal(starsFor(0.0005), "***")
    expect_equal(starsFor(NA), "")
})

test_that("pText formats p-values compactly", {
    expect_equal(pText(0.0001), "p<.001")
    expect_equal(pText(0.023), "p=0.023")
    expect_equal(pText(NA), "")
})

test_that("ciText formats bounds to 3 decimals, matching r, or blanks out NA", {
    expect_equal(ciText(0.2114, 0.6543), "[0.211, 0.654]")
    expect_equal(ciText(NA, 0.5), "")
})

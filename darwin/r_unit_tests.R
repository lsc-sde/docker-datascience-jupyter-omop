#!/opt/conda/bin Rscript

library(testthat)
library(yaml)

context("Darwin OMOP Environment Preflight Checklist")

is_omop_package_available <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

results <- list()
pkgs <- yaml.load_file('r_omop_packages.yaml')

# Darwin OMOP package tests
results$packages <- test_that("OMOP packages check", {
    for (p in pkgs) {
        expect_true(is_omop_package_available(p), label = sprintf("%s is not installed", p))
    }
})

failures <- any(sapply(results, function(x) {
  result <- attr(x, "failed")
  !is.null(result) && result > 0
}))

exit_state <- if (failures) 1 else 0
quit(status = exit_state)
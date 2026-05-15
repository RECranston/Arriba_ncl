#!/usr/bin/env Rscript

lib <- "./R_packages"
dir.create(lib, showWarnings=FALSE, recursive=TRUE)
.libPaths(c(lib, .libPaths()))

if (!requireNamespace("BiocManager", quietly=TRUE))
  install.packages("BiocManager", lib=lib, repos="https://cloud.r-project.org")

# Reload libPaths after every install to ensure new packages are found
.libPaths(c(lib, .libPaths()))

pkgs_cran <- c("lattice", "Matrix", "circlize", "matrixStats")
for (pkg in pkgs_cran) {
  if (!requireNamespace(pkg, quietly=TRUE)) {
    message("Installing ", pkg, "...")
    install.packages(pkg, lib=lib, repos="https://cloud.r-project.org")
  }
  .libPaths(c(lib, .libPaths()))  # refresh after each install
}

pkgs_bioc <- c("BiocGenerics", "S4Vectors", "IRanges", "GenomeInfoDb",
               "GenomicRanges", "Biostrings", "Rsamtools", "MatrixGenerics",
               "S4Arrays", "SparseArray", "DelayedArray",
               "SummarizedExperiment", "GenomicAlignments")
for (pkg in pkgs_bioc) {
  .libPaths(c(lib, .libPaths()))  # refresh before each install
  if (!requireNamespace(pkg, quietly=TRUE)) {
    message("Installing ", pkg, "...")
    BiocManager::install(pkg, lib=lib, ask=FALSE, force=TRUE)
    .libPaths(c(lib, .libPaths()))  # refresh after each install
    if (!requireNamespace(pkg, quietly=TRUE)) {
      message("WARNING: ", pkg, " failed to install!")
    } else {
      message("OK: ", pkg)
    }
  } else {
    message("Already installed: ", pkg)
  }
}

message("Done. Installed packages:")
message(paste(list.dirs(lib, recursive=FALSE, full.names=FALSE), collapse=", "))
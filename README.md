
<!-- README.md is generated from README.Rmd. Please edit that file -->

# QuanT

<!-- badges: start -->
<!-- badges: end -->

The goal of QuanT is to identifying unmeasured heterogeneity in
microbiome data via quantile thresholding.

## Installation

You can install QuanT from [GitHub](https://github.com) with:

``` r
devtools::install_github("jiuyaolu/QuanT")
```

## Example

This is a basic example which shows how to apply QuanT to the CRC
dataset.

``` r
library(QuanT)
covariates = model.matrix(~ subtype + age + gender, data=crc)[,-1]
qsv = QuanT(crc$rela, covariates)
```

A detailed vignette can be accessed via
<https://jiuyaolu.github.io/QuanT/QuanT.html>.

It introduces the CRC dataset and explains how to analyze the CRC
dataset using QuanT. It also compares SVA and RUV with QuanT.

<!-- You'll still need to render `README.Rmd` regularly, to keep `README.md` up-to-date. `devtools::build_readme()` is handy for this. -->

#' QuanT
#'
#' @description
#' \code{QuanT} runs the QuanT algorithm. It takes as input the abundance
#' matrix and covariates, and outputs the QSVs.
#'
#' @param dat The abundance matrix with rows as samples and columns as taxa.
#' This is supposed to be relative abundances after preprocessing.
#' @param covariates All the known variables including the primary variable of
#' interest and other covariates.
#' @param q The quantile levels to be used. If NULL, QuanT will choose the
#' quantile levels based on the proportion of zeroes in the data.
#' @param B The number of iterations.
#' @param parallel Whether to use parallel computation or not
#' @param num.cores How many cores to use if parallel==TRUE
#'
#' @return \code{QuanT} outputs the QSVs, which are surrogates for the
#' unmeasured heterogeneity in the data. They are stored in a matrix with the
#' same number of rows as \code{dat}.
#' @export
#'
#' @examples
#' covariates = model.matrix(~ subtype + age + gender, data=crc)[,-1]
#' qsv = QuanT(crc$rela, covariates)
#' plot(qsv[,1:2], col=crc$batchid)
QuanT = function(dat, covariates, q=NULL, B = 10,
                 parallel = FALSE, num.cores = 1,
                 alpha = 0.1, visualization = FALSE) {
  if (inherits(dat, "phyloseq")) {
    # Check if the phyloseq package is installed
    if (!requireNamespace("phyloseq", quietly = TRUE)) {
      stop("The 'phyloseq' package is required. Please install it.", call. = FALSE)
    }

    message("phyloseq object detected. Automatically processing...")

    # Extract sample data for covariates if covariates are not provided
    if (is.null(covariates)) {
      # Check if sample_data is not empty
      if (nrow(phyloseq::sample_data(dat)) > 0) {
        covariates <- as(phyloseq::sample_data(dat), "data.frame")
        message("--> Extracted sample data to use as covariates.")
      } else {
        warning("Covariates not provided and the phyloseq object has no sample_data.")
      }
    }

    # Transform counts to relative abundance
    dat <- phyloseq::transform_sample_counts(dat, function(x) x / sum(x))

    # Extract OTU table
    otu_tab <- phyloseq::otu_table(dat)

    # Ensure samples are rows and taxa are columns
    if (phyloseq::taxa_are_rows(dat)) {
      otu_tab <- t(otu_tab)
    }

    # Convert to a standard matrix for the rest of the function
    dat <- as(otu_tab, "matrix")
    message("--> Converted OTU table to a relative abundance matrix (samples are rows).")
  }

  zp = colMeans(dat==0)
  z = covariates

  if (is.null(q)) {
    # q = stats::quantile(zp[zp<0.9], c(0.1,0.25,0.5,0.75,0.9))
    q = stats::quantile(zp, seq(0.1,0.9,by=0.005))
  }

  res_dual = get_dual(dat, zp, z, q)
  res_test = test_for_uniformity(res_dual$dual_centered)
  pcid = mySelectiveSeqStep(res_test$pv_comb, alpha = alpha)$signif
  if (visualization == TRUE) {
    coloring = rep("black", length(res_test$d))
    coloring[pcid] = "red"
    plot(res_test$d,
         xlab = "Index", ylab = "Singular Values",
         pch = 16,
         cex.lab=0.5, cex.axis=0.5, cex=0.5,
         col = coloring)
  }
  if (all(pcid==0)) {
    return(0)
  } else {
    u = res_test$u[,pcid]
    u = matrix(u,nrow=nrow(dat))
    res_stage2 = stage2(dat, zp, z, q, u, B = B,
                        parallel = parallel, num.cores = num.cores)
    pc = res_stage2$pc[[length(res_stage2$pc)]]

    return(pc)
  }
}

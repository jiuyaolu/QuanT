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
QuanT = function(dat, covariates, q=NULL, B = 20) {
  zp = colMeans(dat==0)
  z = covariates

  if (is.null(q)) {
    q = stats::quantile(zp[zp<0.9], c(0.1,0.25,0.5,0.75,0.9))
  }

  res_dual = get_dual(dat, zp, z, q)
  res_test = test_for_uniformity(res_dual$dual_centered)
  pcid = SelectiveSeqStep(res_test$pv_ad, alpha = 0.05)$signif
  u = res_test$u[,pcid]
  u = matrix(u,nrow=nrow(dat))
  res_stage2 = stage2(dat, zp, z, q, u, B = B)
  pc = res_stage2$pc[[length(res_stage2$pc)]]

  pc
}

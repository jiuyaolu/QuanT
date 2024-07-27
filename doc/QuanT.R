## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  warning = FALSE,
  comment = "#>",
  out.width = "80%",
  out.height = "80%",
  dpi = 300
)

## -----------------------------------------------------------------------------
library(QuanT)

str(crc)

## -----------------------------------------------------------------------------
covariates = model.matrix(~ subtype + age + gender, data=crc)[,-1]
qsv = QuanT(crc$rela, covariates)

## -----------------------------------------------------------------------------
plot(qsv[,1], qsv[,2], col=crc$groupid, 
     cex.lab=0.5, cex.axis=0.5, cex=0.5)

## ----message=FALSE------------------------------------------------------------
if (!require("mgcv", quietly = TRUE)) {
 install.packages("mgcv")
}
if (!require("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}
if (!require("sva", quietly = TRUE)) {
  BiocManager::install("sva")
}
if (!require("RUVSeq", quietly = TRUE)) {
  BiocManager::install("RUVSeq")
}
if (!require("ggplot2", quietly = TRUE)) {
 install.packages("ggplot2")
}
if (!require("corrplot", quietly = TRUE)) {
  install.packages("corrplot")
}

library(mgcv)
library(sva)
library(RUVSeq)
library(ggplot2)
library(corrplot)

## -----------------------------------------------------------------------------
mod = model.matrix(~ subtype + age + gender, data=crc)
mod0 = mod[,1]

svafit = svaseq(t(crc$otu),mod,mod0)
sv = svafit$sv

## -----------------------------------------------------------------------------
plot(sv[,1], sv[,2], col=crc$groupid, 
     cex.lab=0.5, cex.axis=0.5, cex=0.5)

## -----------------------------------------------------------------------------
design <- model.matrix(~ subtype + age + gender, data=crc)
y <- DGEList(counts=t(crc$otu))
y <- calcNormFactors(y, method="TMM")
y <- estimateGLMCommonDisp(y, design)
y <- estimateGLMTagwiseDisp(y, design)
fit <- glmFit(y, design)
lrt <- glmLRT(fit, coef=2)
empirical = which(p.adjust(lrt$table$PValue,"BH") > 0.05)
ruv <- RUVg(t(crc$otu), empirical, k=11)$W

## -----------------------------------------------------------------------------
plot(ruv[,1], ruv[,2], col=crc$groupid, 
     cex.lab=0.5, cex.axis=0.5, cex=0.5)

## -----------------------------------------------------------------------------
get_pv = function(rela, surrogates) {
  if (is.null(surrogates)) {
    pv = apply(rela, 2,
               function(x) anova(lm(x~covariates),
                                 lm(x~covariates[,-(1:4)]))$'Pr(>F)'[2])
  } else {
    pv = apply(rela, 2,
               function(x)
                 anova(lm(x~covariates+surrogates),
                       lm(x~covariates[,-(1:4)]+surrogates))$'Pr(>F)'[2])
  }
  return(pv)
}

pv_no_correction = get_pv(crc$rela, NULL)
pv_group = get_pv(crc$rela, crc$groupid)
pv_quant = get_pv(crc$rela, qsv)
pv_sva = get_pv(crc$rela, sv)
pv_ruv = get_pv(crc$rela, ruv)

## -----------------------------------------------------------------------------
which(p.adjust(pv_no_correction,"BH") <= 0.05)
which(p.adjust(pv_group,"BH") <= 0.05)
which(p.adjust(pv_quant,"BH") <= 0.05)
which(p.adjust(pv_sva,"BH") <= 0.05)
which(p.adjust(pv_ruv,"BH") <= 0.05)

## -----------------------------------------------------------------------------
get_overlap = function(pv, method_name, alpha) {
  n_method = ncol(pv)
  discovery = apply(pv, 2, function(x) which(p.adjust(x,"BH")<=alpha))
  concordance = matrix(NA, nrow=n_method,ncol=n_method)
  for (i in 1:n_method) {
    for (j in i:n_method) {
      if (length(discovery) == 0) {
        concordance[i,j] = 0
      } else if ("list" %in% class(discovery)) {
        concordance[i,j] = length(intersect(discovery[[i]], discovery[[j]]))
      } else {
        concordance[i,j] = length(intersect(discovery[,i], discovery[,j]))
      }
      concordance[j,i] = concordance[i,j]
    }
  }
  rownames(concordance) = colnames(concordance) = method_name
  concordance
}
plot_overlap = function(pv, method_name, alpha=0.05) {
  concordance = get_overlap(pv, method_name, alpha)
  maxconcord = max(concordance)
  corrplot(concordance, 
           method = "color", 
           type = "upper",
           col.lim = c(0,maxconcord),
           # col = rev(COL2('RdYlBu',200)),
           col = COL1("YlGn",200),
           addCoef.col = "black",
           is.corr = FALSE,
           tl.cex = 0.4, number.cex = 0.4,
           tl.srt = 0,
           cl.pos = "n")
}
method_name = c("No Correction",
                "True Group",
                "SVA",
                "RUV",
                "QuanT")
plot_overlap(cbind(pv_no_correction, 
                   pv_group, 
                   pv_sva, 
                   pv_ruv, 
                   pv_quant),
             method_name)

## -----------------------------------------------------------------------------
truerank = rank(pv_group, ties.method = "min")
get_overlap = function(pv) {
  overlap = rep(NA,20)
  for (k in 1:20) {
    dis = which(rank(pv, ties.method = "min") <= k)
    truetopK = which(truerank <= k)
    overlap[k] = mean(dis%in%truetopK)
  }
  return(overlap)
}
df = data.frame(overlap = c(get_overlap(pv_no_correction), 
                             get_overlap(pv_group), 
                             get_overlap(pv_sva), 
                             get_overlap(pv_ruv), 
                             get_overlap(pv_quant)),
                 method = rep(method_name,each=20),
                 K = rep(1:20,length(method_name)))
df$method = factor(df$method, method_name)
pic_overlap = ggplot(df, aes(x = K,
             y = overlap,
             color = method)) +
  geom_line(lwd = 0.6) +
  theme_bw() +
  scale_color_manual(values = c("#7FC97F","#BEAED4","#FDC086","#386CB0","#F0027F")) +
  labs(color = "Method",
       shape = "Method",
       linetype = "Method",
       x = "Top K Detected Taxa",
       y = "Proportion of overlapping Discoveries") +
    theme(legend.position="bottom",
          text = element_text(size = 6)) +
  guides(color = guide_legend(nrow = 2))
plot(pic_overlap)


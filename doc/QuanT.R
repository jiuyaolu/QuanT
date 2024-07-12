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
plot(qsv[,1], qsv[,2], col=crc$batchid, 
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

library(mgcv)
library(sva)
library(RUVSeq)

## -----------------------------------------------------------------------------
mod = model.matrix(~ subtype + age + gender, data=crc)
mod0 = mod[,1]

svafit = svaseq(t(crc$otu),mod,mod0)
sv = svafit$sv

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
pv_batch = get_pv(crc$rela, crc$batchid)
pv_quant = get_pv(crc$rela, qsv)
pv_sva = get_pv(crc$rela, sv)
pv_ruv = get_pv(crc$rela, ruv)

## -----------------------------------------------------------------------------
which(p.adjust(pv_no_correction,"BH") <= 0.05)
which(p.adjust(pv_batch,"BH") <= 0.05)
which(p.adjust(pv_quant,"BH") <= 0.05)
which(p.adjust(pv_sva,"BH") <= 0.05)
which(p.adjust(pv_ruv,"BH") <= 0.05)

## -----------------------------------------------------------------------------
library(ggplot2)
truerank = rank(pv_batch, ties.method = "min")
get_overlap = function(pv) {
  overlap = rep(NA,20)
  for (k in 1:20) {
    dis = which(rank(pv, ties.method = "min") <= k)
    truetopK = which(truerank <= k)
    overlap[k] = mean(dis%in%truetopK)
  }
  return(overlap)
}

method_name = c("No Correction",
                "True Group",
                "SVA",
                "RUV",
                "QuanT")
df = data.frame(overlap = c(get_overlap(pv_no_correction), 
                             get_overlap(pv_batch), 
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


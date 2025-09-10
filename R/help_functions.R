update_pc = function(dual0_centered, pprob, pc) {
  n = nrow(pc)
  K = ncol(pc)
  newpc = matrix(nrow = n, ncol = K)
  id = maxcor = rep(NA,K)

  weighted_dual0_centered = t(t(dual0_centered) * pprob)
  # svdfit = svd(weighted_dual0_centered)
  svdfit = RSpectra::svds(weighted_dual0_centered,
                          max(K,min(6,
                                    nrow(weighted_dual0_centered),
                                    ncol(weighted_dual0_centered),
                                    sum(pprob>0))))
  u = matrix(svdfit$u[,which(svdfit$d>1e-10)],nrow=n)

  for (k in 1:K) {
    abscor = abs(stats::cor(pc[,k],u))
    id[k] = setdiff(order(abscor, decreasing = TRUE),id)[1]
    maxcor[k] = abscor[id[k]]
    newpc[,k] = u[,id[k]]
  }

  list(pc = newpc,
       id = id,
       maxcor = maxcor)
}

p.unicirc = function( x, N ) {
  pos=(x>0)
  neg=(x <=0)
  cdf=rep(NA,length(x))
  cdf[pos]=1 - 0.5*stats::pbeta( 1-x[pos]^2, (N-1)/2, 1/2 )
  cdf[neg]=0.5*stats::pbeta( 1-x[neg]^2, (N-1)/2, 1/2 )
  return(cdf)
}

q.unicirc = function( q, N ) {
  arg = 2*q
  arg[ q>0.5 ]=2 - arg[ q>0.5 ]
  sgn = sign( q-0.5 )
  q.vals=rep(NA,length(q))
  q.vals = sgn*sqrt( 1 - stats::qbeta(arg, (N-1)/2, 1/2 ) )
  return(q.vals)
}

cauchy_combination = function(pv, threshold=NA) {
  if (is.na(threshold)) {
    pv0 = pv
  } else {
    pv0 = pmin(pmax(pv,threshold),1-threshold)
  }
  stats_cauchy = mean(tan((0.5 - pv0) * pi))
  1 - pcauchy(stats_cauchy)
}

test_for_uniformity = function(dual_centered) {
  df = as.numeric(Matrix::rankMatrix(dual_centered))

  s = svd(dual_centered)

  pv_ks = apply(s$u[,1:df], 2, function(x)
    nortest::lillie.test(x)$p.value)
  pv_cvm = apply(s$u[,1:df], 2, function(x)
    nortest::cvm.test(x)$p.value)
  pv_ad = apply(s$u[,1:df], 2, function(x)
    nortest::ad.test(x)$p.value)
  pv_pearson = apply(s$u[,1:df], 2, function(x)
    nortest::pearson.test(x)$p.value)
  pv_sf = apply(s$u[,1:df], 2, function(x)
    nortest::sf.test(x)$p.value)

  pv_comb = sapply(1:df,
                   function(k) cauchy_combination(c(pv_ks[k],
                                                    pv_sf[k],
                                                    pv_ad[k])))

  list(df = df,
       d = s$d,
       u = s$u,
       v = s$v,
       s = s,
       pv_ks = pv_ks,
       pv_ad = pv_ad,
       pv_cvm = pv_cvm,
       pv_pearson = pv_pearson,
       pv_sf = pv_sf,
       pv_comb = pv_comb)
}

SeqStep = function(p, alpha = 0.05, q = alpha/(1-alpha)+1e-5) {
  out = rep(NA, length(p))
  for (k in seq_along(p)) {
    out[k] = sum(p[1:k]>alpha) / k / (1-alpha)
  }

  if (min(out)>q) {
    k = 0
    signif = 0
  } else {
    k = max(which(out<=q))
    signif = 1:k
  }

  list(signif = signif, out = out, k = k)
}

SeqStepPlus = function(p, alpha = 0.05, q = alpha/(1-alpha)+1e-5) {
  out = rep(NA, length(p))
  for (k in seq_along(p)) {
    out[k] = (1+sum(p[1:k]>alpha)) / (1+k) / (1-alpha)
  }

  if (min(out)>q) {
    k = 0
    signif = 0
  } else {
    k = max(which(out<=q))
    signif = 1:k
  }

  list(signif = signif, out = out, k = k)
}

SelectiveSeqStep = function(p, alpha = 0.05, q = alpha/(1-alpha)+1e-5) {
  out = rep(NA, length(p))
  for (k in seq_along(p)) {
    out[k] = sum(p[1:k]>alpha) / sum(p[1:k]<=alpha) / ((1-alpha)/alpha)
  }

  if (min(out)>q) {
    k = 0
    signif = 0
  } else {
    k = max(which(out<=q))
    signif = which(p[1:k]<=alpha)
    k = length(signif)
  }

  list(signif = signif, out = out, k = k)
}

SelectiveSeqStepPlus = function(p, alpha = 0.05, q = alpha/(1-alpha)) {
  out = rep(NA, length(p))
  for (k in seq_along(p)) {
    out[k] = (1+sum(p[1:k]>alpha)) / sum(p[1:k]<=alpha) / ((1-alpha)/alpha)
  }

  if (min(out)>q) {
    k = 0
    signif = 0
  } else {
    k = max(which(out<=q))
    signif = which(p[1:k]<=alpha)
    k = length(signif)
  }

  list(signif = signif, out = out, k = k)
}

mySelectiveSeqStep = function(p, alpha = 0.05, q = alpha/(1-alpha)+1e-5) {
  out = rep(NA, length(p))
  for (k in seq_along(p)) {
    out[k] = sum(p[1:k]>alpha) / sum(p[1:k]<=alpha) / ((1-alpha)/alpha)
  }

  if (min(out)>q) {
    k = 0
    signif = 0
  } else {
    k = which(out[-length(out)] <= q & out[-1] > q)[1]
    signif = which(p[1:k]<=alpha)
    k = length(signif)
  }

  list(signif = signif, out = out, k = k)
}

stage2 = function (dat, zp, z, q, u, test = "rank", B = 10,
                   parallel, num.cores)
{
  n = nrow(dat)
  p = ncol(dat)
  K = length(q)

  warmup = 0.5

  feasible_pair = data.frame(tau = rep(q,p),
                             id_taxon = rep(1:p,each=K),
                             zp = rep(zp,each=K))
  feasible_pair = feasible_pair[feasible_pair$tau >= feasible_pair$zp,]

  # dual0 = dual0_centered = matrix(0, nrow = n, ncol = nrow(feasible_pair))
  #
  # for (t in 1:nrow(feasible_pair)) {
  #   fit0 = quantreg::rq(dat[,feasible_pair$id_taxon[t]] ~ 1,
  #                       tau = feasible_pair$tau[t])
  #   dual0[,t] = fit0$dual
  #   dual0_centered[,t] = fit0$dual - 1 + feasible_pair$tau[t]
  # }


  if (parallel) {
    results_list <- parallel::mclapply(1:nrow(feasible_pair), function(t) {
      fit0 <- quantreg::rq(dat[, feasible_pair$id_taxon[t]] ~ 1,
                           tau = feasible_pair$tau[t])
      list(
        dual0 = fit0$dual,
        dual0_centered = fit0$dual - 1 + feasible_pair$tau[t]
      )
    }, mc.cores = num.cores)

    dual0 <- do.call(cbind, lapply(results_list, `[[`, "dual0"))
    dual0_centered <- do.call(cbind, lapply(results_list, `[[`, "dual0_centered"))

  } else {
    dual0 <- dual0_centered <- matrix(0, nrow = n, ncol = nrow(feasible_pair))
    for (t in 1:nrow(feasible_pair)) {
      fit0 <- quantreg::rq(dat[, feasible_pair$id_taxon[t]] ~ 1,
                           tau = feasible_pair$tau[t])
      dual0[, t] <- fit0$dual
      dual0_centered[, t] <- fit0$dual - 1 + feasible_pair$tau[t]
    }
  }

  pc = vector("list",length=B+2)
  pc[[1]] = matrix(u, nrow = n)
  pprob = matrix(NA,nrow=B+1,ncol=nrow(feasible_pair))

  converge = FALSE

  for (i in 1:B) {
    if (parallel) {
      ptmp.b = parallel::mclapply(1:nrow(feasible_pair), function(t){
        quantreg::rq.test.rank(cbind(1,pc[[i]]),
                               z,
                               dat[,feasible_pair$id_taxon[t]],
                               score="tau",
                               tau=feasible_pair$tau[t])$pvalue
      }, mc.cores = num.cores) %>% unlist()
    } else {
      ptmp.b = sapply(1:nrow(feasible_pair), function(t){
        quantreg::rq.test.rank(cbind(1,pc[[i]]),
                               z,
                               dat[,feasible_pair$id_taxon[t]],
                               score="tau",
                               tau=feasible_pair$tau[t])$pvalue
      })
    }

    ptmp.b.max = sapply(feasible_pair$id_taxon,
                        function(j) max(ptmp.b[feasible_pair$id_taxon==j]))

    if (parallel) {
      ptmp.gam = parallel::mclapply(1:nrow(feasible_pair), function(t){
        quantreg::rq.test.rank(matrix(1,nrow=n,ncol=1),
                               pc[[i]],
                               dat[,feasible_pair$id_taxon[t]],
                               score="tau",
                               tau=feasible_pair$tau[t])$pvalue
      }, mc.cores = num.cores) %>% unlist()
    } else {
      ptmp.gam = sapply(1:nrow(feasible_pair), function(t){
        quantreg::rq.test.rank(matrix(1,nrow=n,ncol=1),
                               pc[[i]],
                               dat[,feasible_pair$id_taxon[t]],
                               score="tau",
                               tau=feasible_pair$tau[t])$pvalue
      })
    }

    ptmp.gam.max = sapply(feasible_pair$id_taxon,
                          function(j)max(ptmp.gam[feasible_pair$id_taxon==j]))



    # pprob.b <- ptmp.b.max<=cutoff.b.grid
    pprob.b <- (1 - sva:::edge.lfdr(ptmp.b,adj=100))

    # pprob.gam <- ptmp.gam.max<=cutoff.gam.grid
    pprob.gam <- (1 - sva:::edge.lfdr(ptmp.gam,adj=100))



    pprob[i,] <- pprob.gam * (1 - pprob.b)

    if (i >= 2) {
      if (all(pprob[i,]==pprob[i-1,])) {
        converge = TRUE
        break
      }
    }

    res_update = update_pc(dual0_centered, pprob[i,], pc[[1]])
    pc[[i+1]] = res_update$pc

  }

  if (!converge) {
    if (is.null(warmup)) {
      pprob[B+1,] <- pprob[B,]
      pc[[B+2]] = pc[[B+1]]
    } else {
      pprob[B+1,] <- colMeans(pprob[(floor(B*warmup)+1):B,])

      res_update = update_pc(dual0_centered, pprob[B+1,], pc[[1]])
      pc[[B+2]] = res_update$pc

    }
  } else {
    for (j in i:(B+1)) {
      pprob[j,] = pprob[j-1,]
      pc[[j+1]] = pc[[j]]
    }
  }


  list(pc = pc,
       feasible_pair = feasible_pair,
       dual0 = dual0,
       dual0_centered = dual0_centered,
       pprob = pprob,
       iterations = i)
}

get_dual = function(dat, zp, z, q) {
  n = nrow(dat)
  p = ncol(dat)
  K = length(q)

  feasible_pair = data.frame(tau = rep(q,p),
                             id_taxon = rep(1:p,each=K),
                             zp = rep(zp,each=K))
  feasible_pair = feasible_pair[feasible_pair$tau >= feasible_pair$zp,]

  residual = dual = dual_centered = matrix(0, nrow = n, ncol = nrow(feasible_pair))

  if (is.null(z)) {
    for (t in 1:nrow(feasible_pair)) {
      fit = quantreg::rq(dat[,feasible_pair$id_taxon[t]] ~ 1,
                         tau = feasible_pair$tau[t])
      residual[,t] = fit$residuals
      dual[,t] = fit$dual
      dual_centered[,t] = fit$dual - 1 + feasible_pair$tau[t]
    }
  } else {
    for (t in 1:nrow(feasible_pair)) {
      fit = quantreg::rq(dat[,feasible_pair$id_taxon[t]] ~ z,
                         tau = feasible_pair$tau[t])
      residual[,t] = fit$residuals
      dual[,t] = fit$dual
      dual_centered[,t] = fit$dual - 1 + feasible_pair$tau[t]
    }
  }

  list(feasible_pair = feasible_pair,
       residual = residual,
       dual = dual,
       dual_centered = dual_centered)
}

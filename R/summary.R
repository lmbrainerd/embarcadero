
#' @title Summary of a BART object
#'
#' @description
#' An all-purpose model summary tool, which reports the model call, an AUC value (the area under the receiver-operator curve), and the optimal threshold based on the true skill statistic (and return the associated Type I and II error rates). 
#' 
#' This summary also returns the symmetric Extremal Dependence Index (SEDI) from Ferro and Stephenson (2011) and Wunderlich et al. (2019), which is recommended as an alternative goodness-of-fit statistic to the TSS.
#' 
#' There are also four diagnostic plots generated (plots=FALSE to turn off): the receiver-operator curve; a histogram of fitted values; the threshold-performance curve, which reports the true skill statistic for a given cutoff, and has a line at the optimal value; and a dotplot showing the fitted values split by the threshold and the true y values in the data.
#' 
#' This is currently compatible with rbart objects but returns the AUC and diagnostics on the model fits WITHOUT THE RANDOM EFFECTS INCORPORATED. Future versions need to add the option to include random effects, to do an AUC with/without.
#'
#' @param model A BART model object generated by the dbarts package 
#' @param plots Generate diagnostic plots
#'
#' @export
#'

summary.bart <- function(object, plots=TRUE)  {
  
  
  if(class(object)=='bart') {fitobj <- object$fit} else 
    if(class(object)=='rbart') {fitobj <- object$fit[[1]] }
  
  cat("Call: ", paste(object$call), '\n \n')
  
  cat("Predictor list: \n", 
          paste(attr(fitobj$data@x, "term.labels"), sep=' '), "\n", "\n")
  
  true.vector <- fitobj$data@y 
  
  pred <- prediction(colMeans(pnorm(object$yhat.train)), true.vector)
  
  perf.tss <- performance(pred,"sens","spec")
  tss.list <- (perf.tss@x.values[[1]] + perf.tss@y.values[[1]] - 1)
  tss.df <- data.frame(alpha=perf.tss@alpha.values[[1]],tss=tss.list)

  # If the values equal 0 SEDI yields infinity, therefore can still be interpreted by adding an infinitely small number to those cells contained zeros (Wunderlich et al. 2019)
  small.num <- 1e-09
  tpr <- perf.tss@x.values[[1]]
  tpr[tpr == 0] <- small.num
  fpr <- 1-perf.tss@y.values[[1]]
  fpr[fpr == 0] <- small.num
  tnr <- 1 - fpr
  fnr <- 1 - tpr
  tnr[tnr == 0] <- small.num
  fnr[fnr == 0] <- small.num
  s <- (log(fpr) - log(tpr) - log(tnr) + log(fnr))/(log(fpr) +
        log(tpr) + log(tnr) + log(fnr))
  
  sedi.df <- data.frame(alpha=perf.tss@alpha.values[[1]],sedi=s)
  
  auc <- performance(pred,"auc")@y.values[[1]]
  cat('Area under the receiver-operator curve', "\n")
  cat('AUC =', auc, "\n", "\n")
  
  thresh <- min(tss.df$alpha[which(tss.df$tss==max(tss.df$tss))])
  thresh.sedi <- min(sedi.df$alpha[which(sedi.df$sedi==max(sedi.df$sedi))])
  cat('Recommended threshold (maximizes true skill statistic)', "\n")
  cat('Cutoff = ', thresh, "\n")
  cat('TSS = ', tss.df[which(tss.df$alpha==thresh),'tss'], "\n")
  cat('SEDI Cutoff = ', thresh.sedi, "\n")
  cat('SEDI = ', sedi.df[which(sedi.df$alpha==thresh),"sedi"], "\n")
  cat('Resulting type I error rate: ',1-perf.tss@y.values[[1]][which(perf.tss@alpha.values[[1]]==thresh)], "\n") # Type I error rate
  cat('Resulting type II error rate: ', 1-perf.tss@x.values[[1]][which(perf.tss@alpha.values[[1]]==thresh)], "\n") # Type II error rate
  
  if(plots==TRUE){
    
    x <- performance(pred, "tpr", "fpr")
    rocdf <- data.frame(fpr=x@x.values[[1]],
                        tpr=x@y.values[[1]])
    g1 <- ggplot(rocdf, aes(x=fpr,y=tpr)) + geom_line() + 
      ggtitle('Receiver-operator curve') + 
      xlab('False positive rate') + 
      ylab('True positive rate') + 
      geom_abline(intercept=0,slope=1,col='red')+ 
      theme_classic()

    pnormdf <- data.frame(pnorm = colMeans(pnorm(object$yhat.train)))
    g2 <- ggplot(pnormdf, aes(pnorm)) + geom_histogram(stat='bin', binwidth=0.05) + 
      ylab('Number of training data points') + ggtitle('Fitted values') + 
      xlab('Predicted probability') + 
      theme_classic()
    
    #hist(pnorm(object$yhat.train), xlab='Predicted y', main='Fitted values')
    
    g3 <- ggplot(tss.df, aes(x=alpha,y=tss)) + geom_line() + 
      ggtitle('Threshold-performance curve') + 
      xlab('Threshold') + 
      ylab('True skill statistic') + 
      geom_vline(xintercept=thresh,col='red')+ 
      theme_classic()
    
    obsf <- data.frame(fitted=pnorm(colMeans(object$yhat.train)),
                       classified=as.numeric(pnorm(colMeans(object$yhat.train))>thresh),
                       observed=fitobj$data@y)
    
    g4 <- ggplot(obsf, aes(x=fitted, y=factor(observed), 
                     fill=factor(classified), color=factor(classified))) + 
      geom_jitter(height = 0.2, size=0.9) + xlab('Predicted probability') + 
      ggtitle('Classified fitted values') + 
      ylab('True classification') +  
      #labs(fill = "Thresholded", col='Thresholded') + 
      theme_classic() + theme(legend.position = 'none') + 
      geom_vline(xintercept=thresh,col='black') 
    
    g1 + g2 + g3 + g4 + plot_layout(ncol=2)
  
  }
  
}

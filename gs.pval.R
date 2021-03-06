gs.pval = function(gs, rnames, is.sig, uni.size, min.size=0, max.size=Inf, include.identifiers=FALSE, alt.rnames=NULL){
  # Calculate hypergeometric p- and E-values of enrichment for gene sets
  # Code adapted from EnrichmentBrowser
  # Numeric gene identifiers are recommended for analysis speed
  # gs = list read from GMT file: elems contain sets, names are set names
  # rnames = unique identifiers of genomic features==rows of input data
  # is.sig = logical marking identifiers to retain
  # uni.size = size of potential gene universe
  #   recommend intersection between platform and annotation source
  
  # function for collapsing identifier lists
  semistring = function(myvec){paste(names(myvec)[as.logical(myvec)],sep='',collapse=';')}

  # check arguments
  if( !is.list(gs) | length(gs)==0 | length(names(gs)) != length(gs) ){
    stop('"gs" does not appear to be a gene set') }
  if( length(rnames) != length(is.sig) ){
    stop('feature identifier "rnames" and mask "is.sig" must have same length')}
  if( !is.null(alt.rnames) & length(rnames) != length(alt.rnames) ){
    stop('feature identifier "rnames" and alternative identifier "alt.rnames" must have same length')
  }
  if( length(unique(rnames)) != length(rnames) ){
    # convert mask to ids
    sig = rnames[is.sig]
    # shrink rnames and is.sig to size of unique elements
    mymk = !duplicated(rnames)
    rnames = rnames[mymk]; is.sig = rnames %in% sig
    if(!is.null(alt.rnames) ){ alt.rnames = alt.rnames[mymk] }
  }
  if( !is.logical(include.identifiers) ){
    include.identifiers = as.logical(include.identifiers)
    warn('flag include.identifiers converted to logical') }
  if( mode(gs[[1]]) != mode(rnames) ){
    # convert to character for safety
    rnames = as.character(rnames)
    gs = lapply(X=gs, FUN=function(x){as.character(x)})
  }
  # use faster %chin% function in package 'data.table' for character gene IDs
  if( is.character(rnames) ){
    tmp=suppressPackageStartupMessages(require(data.table)) }

  # trim & transform gene set to matrix, and align features with input data
  gs.sizes = lengths(gs,use.names=F)
  gs = gs[gs.sizes>=min.size & gs.sizes<=max.size]
  gs.sizes = gs.sizes[gs.sizes>=min.size & gs.sizes<=max.size]
  if( length(gs)==0 ){ stop("No gene set with valid size!") }
  if( is.character(rnames) ){
    cmat = as.matrix(as.data.frame(x=lapply(X=gs, FUN=function(x){ rnames %chin% x })))
  } else {
    cmat = as.matrix(as.data.frame(x=lapply(X=gs, FUN=function(x){ rnames %in% x })))
  }
  rownames(cmat) = rnames
  has.set = which(rowSums(cmat) > 0)
  cmat = cmat[has.set,]
  if(length(has.set)<length(rnames)){
    rnames = rnames[has.set]
    is.sig = is.sig[has.set]
    if( !is.null(alt.rnames) ){ alt.rnames = alt.rnames[has.set] }
  }
  # calculate hypergeometric p-values
  nr.sigs = sum(is.sig)
  sig.cmat = cmat & is.sig
  ovlp.sizes = colSums(sig.cmat)
  gs.sizes = colSums(cmat)
  gs.ps = phyper(ovlp.sizes,gs.sizes,uni.size,nr.sigs,lower.tail=FALSE)
  gs.ps[ovlp.sizes==0] = 1 #phyper says finding 0 of 0-3 is p<0.05?!
  # generate return structure
  gs.idx = sort.list(gs.ps)
  # Holm controls family-wise error rate, is valid under arbitrary assumptions
  #  and has more power than simple Bonferroni correction
  gs.es = p.adjust(gs.ps,method="holm")
  res.tbl = cbind(gs.es,gs.ps,gs.sizes,ovlp.sizes)
  colnames(res.tbl) = c("E.Value","P.Value","Set.Size","Overlap")
  rownames(res.tbl) = colnames(cmat)
  res.tbl = res.tbl[gs.idx,]
  attr(res.tbl,"Sig.Size") = nr.sigs
  attr(res.tbl,"Uni.Size") = uni.size
  if(include.identifiers){
    attr(res.tbl,"ID.list") = apply(X=sig.cmat,MARGIN=2,FUN=semistring)[gs.idx]
    if( !is.null(alt.rnames) ){
      tmp = sig.cmat; rownames(tmp) = alt.rnames
      attr(res.tbl,"alt.ID.list") = apply(X=tmp,MARGIN=2,FUN=semistring)[gs.idx]
    }
  }
  return(res.tbl)
}

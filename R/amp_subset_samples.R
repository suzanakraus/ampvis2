#' Subset ampvis2 objects based on sample metadata
#'
#' Subsets the data in ampvis2 objects based on metadata and returns the subsetted object. 
#'
#' @usage amp_subset_samples(data, ...)
#'
#' @param data (\emph{required}) Data list as loaded with \code{\link{amp_load}}.
#' @param ... Logical expression indicating elements or rows to keep in the metadata. Missing values are taken as false. Directly passed to \code{subset()}. 
#' @param minreads Minimum number of reads pr. sample. Samples below this value will be removed. (\emph{default:} \code{0})
#' @param normalise (\emph{logical}) Transform the OTU read counts to be in percent per sample \code{AFTER} the OTU's have been removed by the \code{minreads} argument. (\emph{default:} \code{FALSE})
#' @param removeAbsents (\emph{logical}) Whether to remove OTU's that may have 0 read abundance in all samples after the subset. (\emph{default:} \code{TRUE})
#' 
#' @return A modifed ampvis2 object
#' 
#' @importFrom magrittr %>%
#' @importFrom stringr str_split
#' 
#' @export
#' 
#' @details The subset is performed on the metadata by \code{subset()} and the abundance- and taxonomy tables are then adjusted accordingly.
#' 
#' @section Preserving relative abundances in a subset of larger data:
#' By default the raw read counts in the abundance matrix are normalised (transformed to percentages) by some plotting functions automatically (for example \code{\link{amp_heatmap}}, \code{\link{amp_timeseries}}, and more). This means that the relative abundances shown will be calculated based on the remaining taxa after the subset, not including the removed taxa, if any. To circumvent this, set \code{normalise = TRUE} when subsetting with the \code{\link{amp_subset_taxa}} and \code{\link{amp_subset_samples}} functions, and then set \code{normalise = FALSE} in the plotting function. This will transform the OTU counts to relative abundances BEFORE the subset, and setting \code{normalise = FALSE} will skip the transformation in the plotting function, see the example below.
#' 
#' \preformatted{
#' data("MiDAS")
#' subsettedData <- amp_subset_samples(MiDAS,
#'                                     Plant \%in\% c("Aalborg West", "Aalborg East"),
#'                                     normalise = TRUE
#'                                     )
#' amp_heatmap(subsettedData,
#'             group_by = "Plant",
#'             tax_aggregate = "Phylum",
#'             tax_add = "Genus",
#'             normalise = FALSE
#'             )
#' }
#' 
#' @examples 
#' #Load example data
#' data("MiDAS")
#' 
#' #Show a short summary about the data by simply typing the name of the object in the console
#' MiDAS
#' 
#' #Keep only samples containing Aalborg West or East in the Plant column
#' MiDASsubset <- amp_subset_samples(MiDAS, Plant %in% c("Aalborg West", "Aalborg East"))
#' 
#' #Summary
#' MiDASsubset
#' 
#' #Keep only samples containing Aalborg West or East in the Plant column 
#' #and remove the sample "16SAMP-749". Remove any sample(s) with less than 20000 total reads
#' MiDASsubset2 <- amp_subset_samples(MiDAS,
#'     Plant %in% c("Aalborg West", "Aalborg East") & !SampleID %in% c("16SAMP-749"), 
#'     minreads = 20000)
#'     
#' #Summary
#' MiDASsubset2
#' 
#' @seealso 
#' \code{\link{amp_subset_taxa}}, \code{\link{amp_heatmap}}
#' 
#' @author Kasper Skytte Andersen \email{kasperskytteandersen@@gmail.com}
#' @author Mads Albertsen \email{MadsAlbertsen85@@gmail.com}


amp_subset_samples <- function(data, ..., minreads = 0, normalise = FALSE, removeAbsents = TRUE) {
  
  ### Data must be in ampvis2 format
  if(class(data) != "ampvis2")
    stop("The provided data is not in ampvis2 format. Use amp_load() to load your data before using ampvis2 functions. (Or class(data) <- \"ampvis2\", if you know what you are doing.)", call. = FALSE)
  
  if (minreads > max(colSums(data$abund))) {
    stop(paste("Cannot subset samples with minimum", minreads, "total reads, when highest number of reads in any sample is", max(colSums(data$abund))), call. = FALSE)
  }
  
  ### Check if refseq data is in the right format
  if(!is.null(data$refseq) & !class(data$refseq) == "DNAbin") {
    stop("The refseq element is not of class \"DNAbin\". The reference sequences must be loaded with ape::read.dna().", call. = FALSE)
  }
  
  #For printing removed samples and OTUs
  nsamplesbefore <- nrow(data$metadata) %>% as.numeric()
  nOTUsbefore <- nrow(data$abund) %>% as.numeric()
  
  #remove samples below minreads BEFORE percentages
  data$abund <- data$abund[, colSums(data$abund) >= minreads, drop = FALSE]
  
  #Subset the metadata again to match any removed sample(s)
  data$metadata <- data$metadata[which(rownames(data$metadata) %in% colnames(data$abund)), , drop = FALSE]
  
  ### calculate percentages 
  if (isTRUE(normalise)) {
    if(isTRUE(attributes(data)$normalised))
      warning("The data has already been normalised by either amp_subset_samples or amp_subset_taxa. Setting normalise = TRUE (the default) will normalise the data again and the relative abundance information about the original data of which the provided data is a subset will be lost.", call. = FALSE)
    #create a temporary abund object for calculating raw read stats that are NOT normalised but subsetted in the same way as data$abund
    tempabund <- data$abund
    
    #calculate sample percentages, skip columns with 0 sum to avoid NaN's
    data$abund[,which(colSums(data$abund) != 0)] <- as.data.frame(apply(data$abund[,which(colSums(data$abund) != 0), drop = FALSE], 2, function(x) x/sum(x)*100))
    attributes(data)$normalised <- TRUE
  }
  
  #Subset metadata based on ...
  data$metadata <- subset(data$metadata, ...)
  if(nrow(data$metadata) == 0)
    stop("The subset resulted in empty data", call. = FALSE)
  data$metadata <- droplevels(data$metadata) #Drop unused factor levels or fx heatmaps will show a "NA" column
  
  #And only keep columns in otutable that match the rows in the subsetted metadata
  data$abund <- data$abund[, which(colnames(data$abund) %in% rownames(data$metadata)), drop = FALSE]
  
  #After subsetting the samples, remove OTU's that may have 0 reads in all samples
  if(isTRUE(removeAbsents)) {
    data$abund <- data$abund[rowSums(data$abund) > 0, , drop = FALSE]
  }
  
  if (isTRUE(normalise)) {
    tempabund <- tempabund[which(rownames(tempabund) %in% rownames(data$abund)), which(colnames(tempabund) %in% rownames(data$metadata)), drop = FALSE]
    #calculate basic stats and store in attributes for use in print.ampvis2
    attributes(data)$readstats <- list(
      "Total#Reads" = as.character(sum(tempabund)),
      "Min#Reads" = as.character(min(colSums(tempabund))),
      "Max#Reads" = as.character(max(colSums(tempabund))),
      "Median#Reads" = as.character(median(colSums(tempabund))),
      "Avg#Reads" = as.character(round(mean(colSums(tempabund)), digits = 2))
    )
  }
  
  #Subset taxonomy based on abund
  data$tax <- data$tax[which(rownames(data$tax) %in% rownames(data$abund)), , drop = FALSE]
  
  #make sure the order of sample names are identical between abund and metadata
  data$abund = data$abund[,rownames(data$metadata), drop = FALSE]
  data$tax = data$tax[rownames(data$abund),, drop = FALSE]
  
  #Subset refseq, if any, based on abund
  if(any(names(data) == "refseq")){
    if(!is.null(names(data$refseq))) {
      #sometimes there is taxonomy alongside the OTU ID's. Anything after a ";" will be ignored
      names_stripped <- stringr::str_split(names(data$refseq), ";", simplify = TRUE)[,1]
      data$refseq <- data$refseq[names_stripped %in% rownames(data$abund)] 
    } else if(is.null(names(data$refseq))) {
      warning("DNA sequences have not been subsetted, could not find the names of the sequences in data$refseq.", call. = FALSE)
    }
  }
  
  #Print number of removed samples and OTU's
  nsamplesafter <- nrow(data$metadata) %>% as.numeric()
  nOTUsafter <- nrow(data$abund) %>% as.numeric()
  if (nsamplesbefore == nsamplesafter) {
    message("0 samples have been filtered.")
  } else {
    message(paste(nsamplesbefore-nsamplesafter, "samples and", nOTUsbefore-nOTUsafter,"OTUs have been filtered \nBefore:", nsamplesbefore, "samples and", nOTUsbefore, "OTUs\nAfter:", nsamplesafter, "samples and", nOTUsafter, "OTUs"))
  }
  
  return(data)
}

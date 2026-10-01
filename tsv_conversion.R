# tsv converter

#install.packages("openxlsx", dependencies = TRUE)
library("openxlsx")
library("parallel")


### convert_tsvs function

# give the read.dir for file location
# give the out.dir as the location to save the files
# looks for "_fusions.discarded.tsv|_fusions.tsv" in the directory to generate the file list for the loop
# loops through and saves tsv files as xlsx files
# empty tsv files are saved as xlsx files which are filled with NA values and identical headings
# operate on multiple cores by assigning cores = X

# add in an option for version number/or count col numbers and add if loop for assigning headers


convert_tsvs <- function(pattern = "_fusions.discarded.tsv|_fusions.tsv", 
                         read.dir, 
                         out.dir, 
                         cores = 4) {
  
  # # to test:
  # pattern = "_fusions.discarded.tsv|_fusions.tsv"
  # read.dir = "~/read/path/here/"
  # out.dir = "~/save/path/here/"
  # cores = 16

  
  # to generate list
  read.files <- dir(read.dir)
  read.files <- read.files[grep(pattern, read.files)]
  
  # if the output location doesn't exist it gets created
  if (!dir.exists(out.dir)) {
    
    dir.create(out.dir)
    
  }
  
  mclapply(read.files, mc.cores = cores, function(x){
    
    # for testing:
    # x <- read.files[1]
    
    test.dat <- tryCatch(read.delim(paste0(read.dir, x), sep="\t", comment.char="#", header = FALSE),
                         error = function(e) {
                           if (grepl("no lines available in input", e)) {
                             return(data.frame())
                           } else {
                             stop(e)
                           }
                         })
    
    
    # print out stuff
    
    my.file.name <- gsub(".tsv", "", x)
    
    
    regID <- gsub("_fusions.+", "", x)
    msg.part2 <- gsub(".+_fusions", "fusions", x)
    msg.part2 <- gsub(".tsv", "", msg.part2)
    
    # old version has different number of cols (therefore different colnames) - catch this here
    if (ncol(test.dat) == 30) {
      
      # new arriba version headers (>version2)
      my.col.names <- c("gene1",	"gene2",	"strand1(gene/fusion)",	"strand2(gene/fusion)",	"breakpoint1",	"breakpoint2",	"site1",	
                        "site2", "type",	"split_reads1",	"split_reads2",	"discordant_mates",	"coverage1",	"coverage2", "confidence",
                        "reading_frame",	"tags",	"retained_protein_domains",	"closest_genomic_breakpoint1", "closest_genomic_breakpoint2",
                        "gene_id1",	"gene_id2",	"transcript_id1",	"transcript_id2",	"direction1",	"direction2", "filters",	
                        "fusion_transcript",	"peptide_sequence",	"read_identifiers")
      
    } else if (ncol(test.dat) == 24) {
      
      # old arriba version headers (<version2)
      my.col.names <- c("gene1",	"gene2",	"strand1(gene/fusion)",	"strand2(gene/fusion)",	"breakpoint1",	"breakpoint2",	"site1",
                        "site2", "type",	"direction1",	"direction2",	"split_reads1",	"split_reads2",	"discordant_mates",	"coverage1",
                        "coverage2", "confidence",	"closest_genomic_breakpoint1",	"closest_genomic_breakpoint2",	"filters",
                        "fusion_transcript", "reading_frame",	"peptide_sequence",	"read_identifiers")
      
    }
    
 
    # define header names above so appropriate empty table size can be set
    if (ncol(test.dat) == 0) {
      
      # generates empty data frame
      test.dat <- t(data.frame(rep(NA, length(my.col.names))))
      test.dat <- as.data.frame(test.dat)
      rownames(test.dat) <- NULL
      
    }
    
    # set output colnames
    colnames(test.dat) <- my.col.names
    
    
    write.xlsx(test.dat, file = paste0(out.dir, my.file.name, ".xlsx"), keepNA = TRUE)
    print(paste0("written out ", regID, " ", msg.part2))
    
    
  })
  
  
  
  
}

# for new RNA fusion panel cases
convert_tsvs(pattern = "_fusions.discarded.tsv|_fusions.tsv",
             read.dir = "~/read/path/here/",
             out.dir = "~/save/path/here/",
             cores = 16)


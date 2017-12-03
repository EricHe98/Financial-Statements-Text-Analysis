library("quanteda")
library("dplyr")
library("readr")
library("purrr")
library("stringr")
library("readtext")
library("reshape2")
library("magrittr")
library("ggplot2")
library("gridExtra")

masterIndex <- read_csv("master_index_10Q_withFile.csv")
tickers <- unique(masterIndex$ticker) # use unique(masterIndex) if we wish to scale this across multiple years, or keep tickers.txt updated
StopWordsList <- readLines("../Data/Text Data/StopWordsList.txt")
sections <- c("1", "1A", "2", "3", "4", "5", "6")
file_path <- "../Data/Text Data/10-Q/"
file_type <- ".txt"

section_extractor <- function(statement, section){
  name <- statement$doc_id 
  pattern <- paste0("(?i)°Item ", section, "[^\\w|\\d]", ".*?°")
  section_hits <- str_extract_all(statement, pattern=pattern, simplify=TRUE) 
  if (is_empty(section_hits) == TRUE){
    empty_vec <- "empty"
    names(empty_vec) <- paste(name, section, sep = "_") 
    print(paste("No hits for section", section, "of filing", name))
    return(empty_vec)
  }
  word_counts <- map_int(section_hits, ntoken)
  max_hit <- which(word_counts == max(word_counts))
  max_filing <- section_hits[[max_hit[length(max_hit)]]]
  if (max(word_counts) < 250 & str_detect(max_filing, pattern = "(?i)(incorporated by reference)|(incorporated herein by reference)") == TRUE){
    empty_vec <- "empty"
    names(empty_vec) <- paste(name, section, sep = "_") 
    print(paste("Section", section, "of filing", name, "incorporates by reference its information"))
    return(empty_vec)
  }
  names(max_filing) <- paste(name, section, sep = "_") 
  return(max_filing)
}

section_dfm <- function(statements_list, section, min_words, tf){
  map(statements_list, section_extractor, section=section) %>%
    map(corpus) %>%
    reduce(`+`) %>%
    dfm(tolower=TRUE, remove=StopWordsList, remove_punct=TRUE) %>% 
    dfm_subset(., rowSums(.) > min_words) %>%
    when(tf==TRUE ~ tf(., scheme="log"), 
         ~ .)
}

filing_dfm <- function(sections, filings_list, min_words, tf){
  map(sections, section_dfm, statements_list=filings_list, min_words=min_words, tf=tf)
}

dist_parser <- function(distObj, section){
  melted_frame <- as.matrix(distObj) %>%
  {. * upper.tri(.)} %>% 
    melt(varnames = c("previous_filing", "filing"), value.name = paste0("sec", section, "dist"))  
  melted_frame$previous_filing %<>% str_extract(pattern = ".*?(?=\\.)")
  melted_frame$filing %<>% str_extract(pattern = ".*?(?=\\.)") 
  return(melted_frame)
}

filing_similarity <- function(dfm_list, method){
  map(dfm_list, textstat_simil, method=method) %>%
    map(dist_parser)}

index_filing_filterer <- function(the_ticker, index){
  filter(index, ticker == the_ticker) %>%
    arrange(date) %>% 
    pull(filing)
}

distance_returns_calculator <- function(the_ticker){
  file_names <- index_filing_filterer(the_ticker, masterIndex)
  
  if (length(file_names) <= 1){
    empty_list <- data_frame()
    print(paste("Only one filing available for ticker", the_ticker))
    return(empty_list)
  }
  
  file_locations <- paste0(file_path, file_names, file_type)
  
  filings_list <- map(file_locations, readtext)
  
  similarity_list <- map(sections, section_dfm, statements_list=filings_list, min_words=10, tf=TRUE) %>%
    map(textstat_simil, method="cosine") %>%
    map2(sections, dist_parser) %>%
    reduce(left_join, by = c("previous_filing", "filing"))
  
  prev_current_mapping <- data_frame(previous_filing = file_names[-length(file_names)], filing = file_names[-1])
  distance_returns_df <- left_join(prev_current_mapping, similarity_list, by = c("previous_filing", "filing"))
  print(paste("Successfully mapped distance scores to financial returns for ticker", the_ticker))
  return(distance_returns_df)}

distance_df <- map(tickers, distance_returns_calculator) %>%
  reduce(rbind)

masterIndex %<>% left_join(distance_df, by = "filing")

write.csv(masterIndex, file = "index_distance_10Q.csv", row.names = FALSE)
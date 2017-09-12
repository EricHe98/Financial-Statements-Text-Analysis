library("stringr")
library("dplyr")
library("purrr")

input <- "/data/edgar/data/"
output <- "parsed-filings/"

clean_filing <- function(file_name, input_cik){
  paste0(input_cik, file_name) %>%
  readLines(encoding = "UTF-8") %>%
  str_c(collapse = " ") %>%
  str_extract(pattern = "(?s)(?m)<TYPE>10-Q.*?(</TEXT>)") %>%
  str_replace(pattern = "((?i)<TYPE>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "((?i)<SEQUENCE>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "((?i)<FILENAME>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "((?i)<DESCRIPTION>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "(?s)(?i)<head>.*?</head>", replacement = "") %>%
  str_replace(pattern = "(?s)(?i)<(table).*?(</table>)", replacement = "") %>%
  str_replace_all(pattern = "(?s)(?i)(?m)> +Item|>Item|^Item", replacement = ">°Item") %>%
  str_replace(pattern = "</TEXT>", replacement = "°</TEXT>") %>%
  str_replace_all(pattern = "(?s)<.*?>", replacement = " ") %>%
  str_replace_all(pattern = "&(.{2,6});", replacement = " ") %>%
  str_replace_all(pattern = "(?s) +", replacement = " ") %>%
  write(file = paste0(output, file_name))
  print(paste("Cleaned filing", file_name))
}

clean_cik <- function(cik){
  input_cik <- paste0(input, cik, "/")
  
  files = input_cik %>% 
    list.files %>% 
    subset(str_detect(., pattern = "10-Q"))
  
  map(files, clean_filing, input_cik = input_cik)
  
  print(paste("Cleaned all filings for CIK", cik))  
}

cik_list <- list.files(input)

map(cik_list, clean_cik)


#mutate(cik = cik,
#         date = str_extract(files, pattern = "(?<=(.{1,10}_){2}).*?(?=_)"),
#         file_name = str_extract(files, pattern = "(?<=(.{1,10}_){3}).*")))


library("dplyr")
library("lubridate")
library("tidyr")
library("purrr")

returns_calculator <- function(the_ticker, filing_date, interval_length = 5, interval_type = "day"){
  start_date_beginning <- filing_date %>% # start date is first non-weekend day before the filing date.
    ymd(.) %m-% days(3)
  start_date_candidates <- seq(start_date_beginning, ymd(filing_date) %m-% days(1), by = "days")
  start_date <- start_date_candidates[which(format(start_date_candidates, "%u") %in% c(1:5))[length(which(format(start_date_candidates, "%u") %in% c(1:5)))]] # pick out first weekday in the sequence, %u formats date object into numeric weekday
  end_date <- filing_date %>%
    ymd %>% # have to ram through ymd again because map() uses [[]] which messes with lubridate object type
    when(interval_type == "day" ~ . %m+% days(interval_length),
         interval_type == "month" ~ . %m+% months(interval_length), 
         interval_type == "year" ~ . %m+% years(interval_length),
         ~ stop(print(interval_type)))
  date_sequence <- seq(start_date, end_date, by = "days") # see above comment
  date_returns <- filter(full_returns, as.character(ticker) == as.character(the_ticker), date %in% date_sequence) # tickers must be converted to character or else throws a factor level error
  if (nrow(date_returns) == 0){
    empty_df <- data_frame(hpr = NA)
    print(paste("No financial data for ticker", the_ticker))
    return(empty_df) # if no financial data then we would like to make that clear
  } # when statement does not work to break the function! :(
  hpr <-  summarise(date_returns, hpr = prod(return))
  print(paste("Calculated hpr for ticker", the_ticker, "and date", filing_date))
  return(hpr)}

volatility_calculator <- function(the_ticker, filing_date, interval_length = 1, interval_type = "year"){
  end_date <- filing_date %>% ymd
  start_date <- end_date %>%
    ymd %>%
    when(interval_type == "day" ~ . %m-% days(interval_length),
         interval_type == "month" ~ . %m-% months(interval_length), 
         interval_type == "year" ~ . %m-% years(interval_length),
         ~ stop(print(interval_type)))
  date_sequence <- seq(start_date, end_date, by = "days")
  date_sequence <- date_sequence[-which(format(date_sequence, "%u") %in% c(6,7))]
  date_returns <- filter(full_returns, as.character(ticker) == as.character(the_ticker), date %in% date_sequence)
  if (nrow(date_returns) == 0){
    empty_df <- data_frame(sd = NA)
    print(paste("No financial data for ticker", the_ticker))
    return(empty_df) 
  }
  volatility <-  summarise(date_returns, sd = sd(return))
  print(paste("Calculated volatility for ticker", the_ticker, "and date", filing_date))
  return(volatility)
}

master_index <- read.csv("master_index_10Q.csv")

full_returns <- read.csv("../Data/Financial Data/Trimmed_Returns_Raw.csv")
full_returns <- select(full_returns, permco = PERMCO, date = date, return = RET, ticker = TICKER, delisting_return = DLRET) %>%
  filter(ticker %in% master_index$ticker) %>% # only need tickers for which we have filings to compare with
  mutate(delisting_return = as.numeric(as.character(delisting_return))) %>% # 
  mutate(delisting_return = replace(delisting_return, is.na(delisting_return) == TRUE, 0)) %>% # replace NA with 0
  mutate(delisting_return = delisting_return + 1) %>% # so we can add 1 so we can multiply
  mutate(return = as.numeric(as.character(return))) %>% # change return from factor to numeric, characters which CRSP uses to represent missing data or point towards delisting return gets changed to NA
  mutate(return = replace(return, is.na(return) == TRUE, 0)) %>%
  mutate(return = return + 1) %>%
  filter(is.na(return) == FALSE) %>%
  mutate(return = return * delisting_return) %>%
  mutate(date = mdy(date)) %>%
  select(-delisting_return)

ret5d_10Q <- map2_df(master_index$ticker, master_index$date, returns_calculator)
vol_10Q <- map2_df(master_index$ticker, master_index$date, volatility_calculator)

master_index <- cbind(master_index, ret5d_10Q, vol_10Q)

write.csv(master_index, "master_index_10Q_.csv")
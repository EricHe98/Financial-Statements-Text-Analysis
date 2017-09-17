# Parsing Algorithm
### Eric He
### *June 22, 2017*

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

Stringr is the only required package to parse the financial statement text filing.

```{r, eval = FALSE}
require(stringr)
```

Raw financial statements were downloaded and stored in local, as reading in files directly from the SEC servers into R can break if the Internet connection is unstable. However, for demonstration purposes the code displayed will read in directly from the Internet.

Input is the folder (in this case, link) containing the raw data. Output is the folder into which the cleaned text file is written into. It is assumed the output folder has been created and is in the working directory.

```{r, eval = FALSE}
input <- "https://www.sec.gov/Archives/"
output <- "output/"
```

Load in the master index. It is assumed the working directory contains the master index .csv file.

```{r, eval = FALSE}
masterIndex <- read.csv("masterIndex.csv")
```

The complete parsing function is as follows. It follows the parsing procedure outlined in the 2016 paper "The Annual Report Algorithm", written by Jorg Hering, with the exception that all Unicode characters are removed rather than replaced, and multiple empty spaces are removed directly after removing HTML tags, rather than directly before.

```{r, eval = FALSE}
autoParse <- function(x){
  paste(c(input, as.character(masterIndex$EDGAR_LINK[x])), collapse = "") %>% # Step 1
  readLines(encoding = "UTF-8") %>% # Step 2
  str_c(collapse = " ") %>% # Step 3
  str_extract(pattern = "(?s)(?m)<TYPE>10-K.*?(</TEXT>)") %>% # Step 4
  str_replace(pattern = "((?i)<TYPE>).*?(?=<)", replacement = "") %>% # Step 5
  str_replace(pattern = "((?i)<SEQUENCE>).*?(?=<)", replacement = "") %>% # Step 6
  str_replace(pattern = "((?i)<FILENAME>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "((?i)<DESCRIPTION>).*?(?=<)", replacement = "") %>%
  str_replace(pattern = "(?s)(?i)<head>.*?</head>", replacement = "") %>%
  str_replace(pattern = "(?s)(?i)<(table).*?(</table>)", replacement = "") %>%
  str_replace_all(pattern = "(?s)(?i)(?m)> +Item|>Item|^Item", replacement = ">�Item") %>% # Step 7
  str_replace(pattern = "</TEXT>", replacement = "�</TEXT>")
  str_replace_all(pattern = "(?s)<.*?>", replacement = " ") %>% # Step 8
  str_replace_all(pattern = "&(.{2,6});", replacement = " ") %>% # Step 9
  str_replace_all(pattern = "(?s) +", replacement = " ") %>% # Step 10
  write(file = paste(output, x, ".txt"), sep = "") # Step 11
}
```

Let's go through it line by line.

### Step 1

```{r, eval = FALSE}
paste(c(input, as.character(masterIndex$EDGAR_LINK[x])), collapse = "")) %>%
```

This pastes together the input directory with the edgar link, allowing the parsing function to access the raw text file. If the raw text filings are stored in some other way, this paste() function should be edited so that its output results in the path to the raw text filing. For example, substituting x = 1 should give

"https:www.sec.gov/Archives/edgar/1000180/0001000180-13-000009.txt"

If you visit this link, you will find the exact document which will be parsed by the function. It is a mess of HTML and XBRL code.

The %>% symbol is a pipe operator, which takes the output of the function to the left and "pipes" it as the first input in the function in the next line.

In this case, the function to the left is paste(c(input, as.character(masterIndex$EDGAR_LINK[1])), collapse = ""). Its output is "https:www.sec.gov/Archives/edgar/1000180/0001000180-13-000009.txt".
This output is fed as the first input into the function in the line below, which is readLines(encoding = "UTF-8"). Thus, the equivalent code of the following line is readLines("https:www.sec.gov/Archives/edgar/1000180/0001000180-13-000009.txt", encoding = "UTF-8").

### Step 2

```{r, eval = FALSE}
readLines(encoding = "UTF-8") %>%
```

The readLines() function will read every line of a text document into R. Since the 10-K raw filings follow the UTF-8 format, it has been specified within the parsing algorithm to make it run slightly faster.

The output is, again, passed as the input into the function below using the %>% operator.

### Step 3

```{r, eval = FALSE}
str_c(collapse = " ") %>%
```

readLines() creates a vector containing all the text of the text filing. Each element in the vector corresponds to a new line detected within the text document it is reading. However, for parsing purposes, one element containing the entire text document is needed. The str_c() function will concatenate all the elements of the vector together into a one-element vector. The collapse = " " separates each concatenation with a space.

### Step 4

```{r, eval = FALSE}
str_extract(pattern = "(?s)(?m)<TYPE>10-K.*?(</TEXT>)") %>%
```

This function takes in the one-element vector of text, and returns only the text corresponding to the beginning and end of the actual 10-K text.

The str_extract() receives a vector of text, from which a subset of text according to the pattern specifications is returned. We use regular expressions, a grammar for text parsing commands, to control the str_extract() function.

The (?s) treats every line within the vector as one single string. This may be unnecessary as all lines were split into different elements of the vector by the readLines() command, then pasted together again by the str_c() command with a space, rather than a line, acting as the new separator.

The (?m) will look across multiple lines for the specified pattern. Again, this may be unnecessary.

<TYPE>10-K denotes the beginning of the 10-K filing within the text document. This is where the str_extract() function begins to return the subset of text.

. represents any character value, no matter what it is. \* represents any quantity of character values. When . and \* are combined together, all the text from that point on is returned. ? turns this .\* syntax "lazy", meaning that the function will stop returning text the moment it comes across the next pattern.

The (</TEXT>) marks the end of the 10-K filing within the text document. The moment the function comes across this <TEXT> tag, it will stop extracting text.

Thus, everything between the <TYPE>10-K and the </TEXT> tags are returned.

### Step 5

```{r, eval = FALSE}
str_replace(pattern = "((?i)<TYPE>).*?(?=<)", replacement = "") %>%
```

This function will delete the formatting text used to identify the 10-K section as it is not relevant data.

(?i) instructs the function to ignore the case when searching for "<TYPE>". Thus, both "<type>" and "<TYPE>" would match.

.\*?, again, matches everything up until the first appearance of the next pattern.

(?=<) is a positive look-ahead statement. The ?= looks for an appearance of "<", at which point the function halts and returns everything it is specified to return, except the "<" character.

In this case, everything between <TYPE> and < is returned, without including the final <.

### Step 6

```{r, eval = FALSE}
str_replace(pattern = "((?i)<SEQUENCE>).*?(?=<)", replacement = "") %>%
str_replace(pattern = "((?i)<FILENAME>).*?(?=<)", replacement = "") %>%
str_replace(pattern = "((?i)<DESCRIPTION>).*?(?=<)", replacement = "") %>%
str_replace(pattern = "(?s)(?i)<head>.*?</head>", replacement = "") %>%
str_replace(pattern = "(?s)(?i)<(table).*?(</table>)", replacement = "") %>%
```

Again, five more formatting tags are deleted. These tags are more or less the same across all financial statements and hold no useful information. One can read the Hering (2016) paper for an explanation of these tags.

### Step 7

```{r, eval = FALSE}
str_replace_all(pattern = "(?s)(?i)(?m)> +Item|>Item|^Item", replacement = ">°Item") %>%
```

This command tags each section (e.g. Item 1, Item 1A, Item 9B) of the financial statement for future analysis. Unfortunately, it is likely to tag the table of contents as well as the actual sections, and will also tag incorrectly, or fail to tag correctly if the 10-K is poorly formatted.

Compared to the str_replace() function, which replaces the first instance of the specified pattern, the str_replace_all() function replaces all instances of the pattern it can find within the vector. The specified pattern we are looking for can be "> Item", ">Item", or "^Item", with case insensitivity since the (?i) tag is present. The "|" symbol represents the "or" operator which allows us to tag any of the above patterns.

Each of the valid patterns is replaced with ">°Item". Thus, users of the cleaned text which will have all HTML tags removed can still identify each section by looking for the ° symbol.

Users of the parsing algorithm can also try replacing the pattern "  Item", Item with two preceding spaces, as some financial statements were found to use such a pattern. However, the algorithm will tag instances of "  Item" in other financial statements where the double spaces are merely a typo or a formatting quirk, and do not actually denote the beginning of a new section.

### Step 8

```{r, eval = FALSE}
str_replace_all(pattern = "(?s)<.*?>", replacement = " ") %>%
```

This function removes all HTML tags. Anything enclosed by the < and > symbols, including the two symbols are replaced by a space.

### Step 9

```{r, eval = FALSE}
str_replace_all(pattern = "&(.{2,6});", replacement = " ") %>%
```

This function replaces all Unicode strings. For example, \&#151; is a Unicode string representing the "-" character. Because no Unicode-to-ASCII translator could be found, and because Unicode symbols do not appear prominently among nearly all relevant financial words, Unicode strings were deleted and replaced with a space.

The {2,6} symbol means that the function will search for between 2 and 6 instances of ., and must find a ";" character in that time. Recall that . represents any character. Thus, when the function finds a & character, if there is a ; symbol within 2 and 6 characters, the section between & and ;, inclusive, will be replaced. Otherwise, everything is left as is.

Words containing Unicode, such as "L\&#39;Or\&#233;al", which corresponds to "L'Oréal", will be changed to "L Or al". This is not a great loss as many characters containing Unicode are not relevant, and others do not suffer greatly from Unicode deletion. For example, "the Sarbanes\&#151;Oxley Act" which corresponds to "the Sarbanes-Oxley Act" becomes "the Sarbanes Oxley Act". If a function to translate Unicode to ASCII is found or made, it would be preferable to this function.

### Step 10

```{r, eval = FALSE}
str_replace_all(pattern = "(?s) +", replacement = " ") %>%
```

This function replaces multiple spaces with a single space. The + operator means that the previous pattern can be repeated any number of times. In this case, "  Item" with two spaces will be changed to " Item" with one space.

### Step 11

```{r, eval = FALSE}
write(file = paste(output, x, ".txt"), sep = "")
```

Finally, the cleaned text filing is written into a .txt file. The name of the text filing is the number corresponding to index number in the master index. output is the folder in which the text filing will be stored, as it is assumed that the user of the algorithm does not want to junk up his or her working directory.
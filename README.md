---
title: "Documentation"
author: "Eric He"
date: "September 12, 2017"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
library("dplyr")
```

Summary
--

This repository hosts code for my text mining research project. In this project, I test for trading signals within the texts of quarterly and annual reports filed by publicly traded companies with the Securities Exchange Commission. Three potential features are tested:

1) Sentiment analysis: A company's quarterly and annual reports provide updates on its current state and future goals. Is it possible that a company whose report contains a greater-than-average frequency of "negative" words (i.e. words associated with financial distress; for example, "sued", "losses", "adversity") tends to performs more poorly than companies with less negative words? What about positive words? Code for calculating sentiment scores is [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/Calculating-Sentiment-Returns.Rmd).

2) Distance analysis: Changes in the texts of a company's quarterly and annual reports reflect changes in the company itself. Drastic changes in the company text, such as in the Legal Proceedings section, may be indicative of a troubled company; drastic changes in the Business section, where the company describes itself, may indicate a risky pivot. On the other hand, financial statements with very little edits may be indicative of inattentive management. Code for calculating distance scores is [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/Text-Distance-Algo.Rmd).

3) Text-Numeric proportions analysis: Management facing poor financial numbers may decide to substitute them with words. Code for calculating numeric proportions is [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/Calculating-NumProp-Returns.Rmd).

For each data feature, this writeup will give a short overview of the creation process, and follow on with an exploratory data analysis.

Text Data
--

The raw data consists of raw HTML code, and requires a fairly intricate cleaning process derived from the [paper](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2870309) "The Annual Report Algorithm" by Jorg Hering. Each section of the financial statement is tagged with a "°" degree symbol. A detailed walkthrough of cleaning a filing is in [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/Cleaning-Raw-Filings.md), and the script for cleaning all quarterly filings is [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/parsing-script.R). 

An example of a raw filing is the [Apple 2016 filing](https://www.sec.gov/Archives/edgar/data/320193/0001628280-16-020309.txt) on the SEC website. The [cleaned file](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Sample-Data/Apple-2016-Cleaned.txt) has been reduced from 12.8 MB to 285 KB. Even after cleaning, precautions must be taken when doing any analysis to correct for errors caused by poor formatting. Below is pasted output comparing the raw and cleaned Apple filings.

Raw:
```{r eval = FALSE}
"Apple Music offers users a curated listening experience with on-demand radio stations that evolve based on a user&#8217;s play or download activity and a subscription-based internet streaming service that also provides unlimited access to the Apple Music library. </font></div><div style="line-height:120%;padding-top:24px;text-align:justify;font-size:9pt;"><font style="font-family:Helvetica,sans-serif;font-size:9pt;">iCloud</font></div><div style="line-height:120%;padding-top:8px;text-align:justify;font-size:10pt;"><font style="font-family:Helvetica,sans-serif;font-size:9pt;">iCloud is the Company&#8217;s cloud service which stores music, photos, contacts, calendars, mail, documents and more, keeping them up-to-date and available across multiple iOS devices, Mac and Windows personal computers and Apple TV. iCloud services include iCloud Drive</font><font style="font-family:Helvetica,sans-serif;font-size:10pt;"><sup style="vertical-align:top;line-height:120%;font-size:pt">&#174;</sup></font><font style="font-family:Helvetica,sans-serif;font-size:9pt;">, iCloud Photo Library, Family Sharing, Find My iPhone, iPad or Mac, Find My Friends, Notes, iCloud Keychain</font><font style="font-family:Helvetica,sans-serif;font-size:10pt;"><sup style="vertical-align:top;line-height:120%;font-size:pt">&#174;</sup></font><font style="font-family:Helvetica,sans-serif;font-size:9pt;">&#32;and iCloud Backup for iOS devices.</font></div><div style="line-height:120%;padding-top:24px;text-align:justify;font-size:9pt;"><font style="font-family:Helvetica,sans-serif;font-size:9pt;">AppleCare</font></div><div style="line-height:120%;padding-top:8px;text-align:justify;font-size:10pt;"><font style="font-family:Helvetica,sans-serif;font-size:9pt;">AppleCare</font><font style="font-family:Helvetica,sans-serif;font-size:10pt;"><sup style="vertical-align:top;line-height:120%;font-size:pt">&#174;</sup></font><font style="font-family:Helvetica,sans-serif;font-size:9pt;">&#32;offers a range of support options for the Company&#8217;s customers. These include assistance that is built into software products, printed and electronic product manuals, online support including comprehensive product information as well as technical assistance, the AppleCare Protection Plan (&#8220;APP&#8221;) and the AppleCare+ Protection Plan (&#8220;AC+&#8221;)."
```

Cleaned:
```{r eval = FALSE}
"Apple Music offers users a curated listening experience with on-demand radio stations that evolve based on a user s play or download activity and a subscription-based internet streaming service that also provides unlimited access to the Apple Music library. iCloud iCloud is the Company s cloud service which stores music, photos, contacts, calendars, mail, documents and more, keeping them up-to-date and available across multiple iOS devices, Mac and Windows personal computers and Apple TV. iCloud services include iCloud Drive , iCloud Photo Library, Family Sharing, Find My iPhone, iPad or Mac, Find My Friends, Notes, iCloud Keychain and iCloud Backup for iOS devices. AppleCare AppleCare offers a range of support options for the Company s customers. These include assistance that is built into software products, printed and electronic product manuals, online support including comprehensive product information as well as technical assistance, the AppleCare Protection Plan ( APP ) and the AppleCare+ Protection Plan ( AC+ )."
```

A 10-K filing is split into 4 parts, which are further split into 20 different items. Each item corresponds to a different reporting topic. A table explaining the different items is given below.

```{r echo = FALSE, align = "left"}
Section <- c("1", "1A", "1B", "2", "3", "4", "5", "6", "7", "7A", "8", "9", "9A", "9B", "10", "11", "12", "13", "14", "15")
Part <- c(rep(1, 6), rep(2, 8), rep(3, 5), rep(4,1))
Description <- c("Business", "Risk Factors", "Unresolved Staff Comments", "Properties", "Legal Proceedings", "Mine Safety Disclosures", "Market for Registrant's Common Equity", "Consolidated Financial Data", "Financial Condition and Results of Operations", "Disclosures about Market Risks", "Financial Statements", "Changes in and Disagreements with Accountants", "Controls and Procedures", "Other Information", "Corporate Governance", "Executive Compensation", "Security Ownership", "Certain Relationships and Related Transactions", "Principal Accountant Fees and Services", "Exhibits, Financial Statement Schedules")

(Item_Table <- cbind(Section = Section, Part = Part, Description = Description))
```

Part 1 gives an overview of the business. Part 2 discusses the firm's financial standing and its various securities being traded in the financial markets. Part 3 contains disclosures about important company personnel and their families. Part 4 contains the financial statements and exhibits (tables) that are expected to come with the 10-K.

Though many of the items within these 4 parts are self-explanatory, a few require further clarification. 

Item 4, Mine Safety Disclosures, is used by mining companies to report on any violations of safety regulations with their mines. As such, this section is irrelevant for many companies, and the vast majority of Item 4s extracted from 10-K filings will contain short, boiler-plate text saying no mines are owned by the company.

Item 9, Changes in and Disagreements with Accountants contains any disclosures of changes in the accountants hired to audit the company. If the company has any disagreements with the auditors, those will be discussed in this section.

Item 9B contains any miscellaneous information that the company should have reported in other (non-10-K) filings during the fourth quarter, but did not yet do so.

The tables in Item 8, Financial Statements, frequently make a reappearance in Item 15, Exhibits and Financial Statement Schedules. Because this is a text mining exercise, not much attention was paid to Exhibits 8 and 15.

There are some other interesting quirks about financial statements which complicate any text mining exercise.

Boiler plate language is common in many sections where the company has nothing to report; for example, Item 4, Mine Safety Disclosures, is only relevant to mining companies, and Item 3, Legal Proceedings, is only relevant to companies which have ongoing litigation.

Other times, companies may have lots to report - perhaps too much to paste into the filing. In this case, they will generally refer readers to other documents which contain the relevant information. This is called "incorporation by reference." Below is pasted output from PG&E's 2014 filing, item 7.

```{r eval = FALSE}
Management's Discussion and Analysis of Financial Condition and Results of Operations A discussion of PG E Corporation's and the Utility s consolidated financial condition and results of operations is set forth under the heading Management's Discussion and Analysis of Financial Condition and Results of Operations as well as the Glossary in the 2013 Annual Report, which discussion is incorporated herein by reference.
```

Finally, poor formatting by companies can create errors in the parsing process. When tagging items, the table of contents is frequently tagged for many companies, resulting in 2 tags for each item in a 10-K. This problem is mostly solved by choosing the "item" with the largest word count. 

Other tagging errors include tagging blocks of text which are not items, and not tagging items when they should have been tagged. However, the parsing process works for the majority of filings and items; across 20 sections for each 10-K, and 22,631 10-Ks, only around 831 instances of blatant mistagging (e.g. finding "Item 1997") occur.

Financial Data
--

For the analysis, holding period returns were calculated for each filing.

For various reasons, a good proportion of the data downloaded from the SEC cannot be used. 31,763 filings on the SEC database were identified as available for downloading. Of those, only 22,631 had mappings between their CIK (identifiers assigned to a filing entity by the SEC) and the ticker symbol corresponding to their identifier on the publicly traded markets. This is because many filing entities are private companies

Financial Data
--

Holding period returns of companies in the time periods after the date they file with the SEC were also calculated using daily returns data from [WRDS](http://www.whartonwrds.com/). The code for calculating normalized holding period returns is [here](https://github.com/EricHe98/Financial-Statements-Text-Analysis/blob/master/Documentation/Calculating-Financial-Returns.Rmd).


Cosine Distance
--

Cosine distance scores are computed for sections 1 (Business), 1A (Risk Factors), 3 (Legal Proceedings), 4 (Mine Disclosures), 7 (Management's Discussion and Analysis of Financial Condition and Results of Operation), 8 (Financial Statement and Supplementary Data), 9 (Changes in and Disagreements with Accountants on Accounting and Financial Disclosure), and 9A (Controls and Procedures). 

Cosine distance scores are calculated for each consecutive pair of filings, with respect to each section. To clarify, an example of the data is shown below.

```{r eval = FALSE}
  filing    CIK COMPANY_NAME FORM_TYPE DATE_FILED TICKER     ret5d previous_filing
1   5844 320193    APPLE INC      10-K 2013-10-30   AAPL 0.9940992              NA
2  11699 320193    APPLE INC      10-K 2014-10-27   AAPL 1.0302392            5844
3  17314 320193    APPLE INC      10-K 2015-10-28   AAPL 1.0511802           11699
4  22478 320193    APPLE INC      10-K 2016-10-26   AAPL 0.9650652           17314
   sec1dist sec1Adist  sec3dist  sec4dist  sec7dist  sec8dist  sec9dist sec9Adist
1        NA        NA        NA        NA        NA        NA        NA        NA
2 0.9064846 0.9064806 0.9064250 0.9064187 0.9063563 0.9063064 0.9062936 0.9062513
3 0.9043750 0.9043723 0.9043223 0.9043202 0.9042717 0.9042223 0.9042122 0.9042195
4 0.9123101 0.9123075 0.9122643 0.9122607 0.9122010 0.9121568 0.9121410 0.9121136
```

For a given filing (e.g. filing 11699), we compare each of the selected sections with that of the previous filing. In the case of filing 11699, we compare with 5844. The cosine distance score lies between 0 and 1, with 0 meaning the two texts have nothing in common and 1 meaning the two texts have words appearing at the exact same relative frequencies. Calculating in this manner allows us to easily compare distance scores with forward returns starting from the date the statement was filed. As a result, the earliest filing of each company has no distance scores, since there is no earlier filing to compare it with.

Several complications arise when naively calculating cosine distance returns. The first is <HOLDING COMPANY DUPLICATES>. When companies switch between incorporation by reference and directly putting information in the filing, the cosine distance data also cannot be trusted. Measures have been taken to take care of these two problems.

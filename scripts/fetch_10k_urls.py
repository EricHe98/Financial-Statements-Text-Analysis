# for analysis of which methods of fetching the URL are best, see the analysis
# at analyses/optimize_url_fetch.ipynb
# bulk download capabilities at https://www.sec.gov/edgar/sec-api-documentation

from sec_api import QueryApi
import pandas as pd


def create_batches(tickers=[], max_length_of_batch=100):
    """
    # create batches of tickers: [[A,B,C], [D,E,F], ...]
    # a single batch has a maximum of max_length_of_batch tickers
    """
    batches = [[]]

    for ticker in tickers:
        if len(batches[len(batches)-1]) == max_length_of_batch:
            batches.append([])

        batches[len(batches)-1].append(ticker)

    return batches

def download_10K_metadata(query_api, tickers, start_year, end_year):
    """
    Given a list of tickers, this function will return a Pandas Dataframe 
    with the ticker, CIK, and URLs to download the 10-K files from the SEC database.

    Example Output
    ------------
        ticker	cik	    formType	filedAt	                    filingUrl
    0	AVGO	1730168	10-K	    2021-12-17T16:42:51-05:00	https://www.sec.gov/Archives/edgar/data/173016...
    1	AMAT	6951	10-K	    2021-12-17T16:14:51-05:00	https://www.sec.gov/Archives/edgar/data/6951/0...
    2	DE	    315189	10-K	    2021-12-16T11:39:34-05:00	https://www.sec.gov/Archives/edgar/data/315189...
    3	ADI	    6281	10-K	    2021-12-03T16:02:52-05:00	https://www.sec.gov/Archives/edgar/data/6281/0...

    Args
    ------------
    query_api: SEC API to run URL fetching queries
    tickers : a list of tickers for which to fetch URLs
    start_year : the start year to begin fetching 10-K URLs
    end_year : the final year for which 10-K URLs should be fetched
    """
    print('✅ Starting download process')

    # create ticker batches, with 100 tickers per batch
    batches = create_batches(tickers)
    frames = []

    for year in range(start_year, end_year + 1):
        for batch in batches:
            tickers_joined = ', '.join(batch)
            ticker_query = 'ticker:({})'.format(tickers_joined)

            query_string = '''
            {ticker_query} 
            AND filedAt:[{start_year}-01-01 TO {end_year}-12-31] 
            AND formType:"10-K" 
            AND NOT formType:"10-K/A" 
            AND NOT formType:NT'''.format(
                ticker_query=ticker_query, start_year=year, end_year=year)

            query = {
                "query": {"query_string": {
                    "query": query_string,
                    "time_zone": "America/New_York"
                }},
                "from": "0",
                "size": "200",
                "sort": [{"filedAt": {"order": "desc"}}]
            }

            response = query_api.get_filings(query)

            filings = response['filings']

            metadata = list(map(lambda f: {'ticker': f['ticker'],
                                           'cik': f['cik'],
                                           'formType': f['formType'],
                                           'filedAt': f['filedAt'],
                                           'filingUrl': f['linkToFilingDetails']}, filings))

            df = pd.DataFrame.from_records(metadata)

            frames.append(df)

        print('✅ Downloaded metadata for year', year)

    result = pd.concat(frames)
    return result


if __name__ == '__main__':
    # this code follows the SEC official documentation
    # to fetch the URLs of the 10-Ks of the 3000 companies of the Russell 3000

    # The SEC official documentation can be found at
    # https://sec-api.io/docs/sec-filings-render-api/python-example
    import json
    import os
    import pandas as pd

    # params
    with open('config.json', 'r') as f:
        c = json.load(f)
    destination_dir = c['DATA_DIR']
    destination_file = os.path.join(destination_dir, 'metadata.csv')
    api_key = c['SEC_API_KEY']

    # read Russell 3000 files
    holdings = pd.read_csv(os.path.join(c['DATA_DIR'], 'russell_3000/russell-3000-clean.csv'))

    query_api = QueryApi(api_key=api_key)
    tickers = list(holdings['Ticker'])

    metadata = download_10K_metadata(
        query_api=query_api, tickers=tickers, start_year=2019, end_year=2023)

    number_metadata_downloaded = len(metadata)
    print('✅ Downloaded completed. Metadata downloaded for {} filings.'.format(
        number_metadata_downloaded))

    print('Writing to file {}'.format(destination_file))
    metadata.to_csv(destination_file, index=False)
    print('Completed writing file. Exiting script.')

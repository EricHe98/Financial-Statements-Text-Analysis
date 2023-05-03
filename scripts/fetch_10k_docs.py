# for analysis of which methods of fetching the file are best,
# see analyses/optimize_doc_fetch.ipynb

from sec_api import RenderApi
import os
import pandas as pd
import json
from pandarallel import pandarallel
import requests

# params
with open('config.json', 'r') as f:
    c = json.load(f)
destination_dir = os.path.join(c['DATA_DIR'], '10k_raw')
api_key = c['SEC_API_KEY']
render_api = RenderApi(api_key=api_key)

def download_filing(url, destination_file, skip_existing=True, skip_ixbrl=True, engine='requests'):
    """
    Given a SEC EDGAR 10-K URL, will download the HTML file to the local destination file.
    If skip, then will not re-download file if the local destination file already exists.

    Args
    ---------
    engine : one of {'sec_api', 'requests'}
        sec_api : uses the proprietary SEC API to fetch the filing
        requests : uses the open source SEC EDGAR database and requests package to fetch the filing
    """
    try:
        destination_dir = os.path.dirname(destination_file)

        if not os.path.isdir(destination_dir):
            os.makedirs(destination_dir)

        if skip_existing and os.path.exists(destination_file):
            print('⏭️ already exists, skipping download: {url}'.format(
            url=url))
            return

        # do not download iXBRL output
        if skip_ixbrl:
            url = url.replace('ix?doc=/', '')
        if engine == 'sec_api':
            file_content = render_api.get_filing(url)
        elif engine == 'requests':
            file_content = requests.get(url).text

        with open(destination_file, "w") as f:
            f.write(file_content)

    except:
        print('❌ download failed: {url}'.format(
            url=url))

def pandarallel_wrapper(metadata):
    """
    Basic wrapper of the download_filing functionality to allow for pandarallel optimization
    """
    ticker = metadata['ticker']
    url = metadata['filingUrl']
    file_name = url.split("/")[-1] 
    destination_file = os.path.join(destination_dir, ticker, file_name)

    download_filing(url, destination_file)

def pandarallel_wrapper_legacy(metadata):
    """
    Basic wrapper of the download_filing functionality to allow for pandarallel optimization
    """
    ticker = metadata['TICKER']
    url = 'https://www.sec.gov/Archives/' + metadata['EDGAR_LINK']
    file_name = url.split("/")[-1] 
    destination_file = os.path.join(destination_dir, ticker, file_name)

    download_filing(url, destination_file)

if __name__ == '__main__':
    # this code follows the SEC API documentation
    # to fetch the files of the 10-Ks of the 3000 companies of the Russell 3000

    # The SEC API documentation can be found at
    # https://sec-api.io/docs/sec-filings-render-api/python-example
    import json
    import os
    import pandas as pd

    number_of_workers = 8

    # read URL table
    metadata = pd.read_csv(os.path.join(c['DATA_DIR'], 'metadata.csv'))
    metadata_legacy = pd.read_csv(os.path.join(c['DATA_DIR'], 'metadata_2017.csv'))

    # only download the data from russell 3000 today
    metadata = metadata_legacy[metadata_legacy['TICKER'].isin(metadata['ticker'])]

    # download multiple files in parallel
    pandarallel.initialize(progress_bar=True, nb_workers=number_of_workers, verbose=0)

    # uncomment to run a quick sample and download 50 filings
    # sample = metadata.head(50)
    # sample.parallel_apply(pandarallel_wrapper, axis=1)

    # download all filings 
    metadata.parallel_apply(pandarallel_wrapper_legacy, axis=1)

    print('✅ Download completed')

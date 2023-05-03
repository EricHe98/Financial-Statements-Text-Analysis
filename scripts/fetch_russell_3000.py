# this code follows the SEC official documentation
# to fetch the 3000 constituents of the Russell 3000

# The SEC official documentation can be found at 
# https://sec-api.io/docs/sec-filings-render-api/python-example

# import libraries
from sec_api import QueryApi, RenderApi
import requests
import os
import json

with open('config.json', 'r') as f:
    c = json.load(f)

# params
destination_dir = os.path.join(c['DATA_DIR'], 'russell_3000')
raw_data_path = os.path.join(destination_dir, 'russell-3000.csv')
clean_data_path = os.path.join(destination_dir, 'russell-3000-clean.csv')
url = c['RUSSELL_3000_URL']

####
# Download the 3000 constituents of the Russell 3000
####
response = requests.get(url)

with open(raw_data_path, 'wb') as f:
    f.write(response.content)

# cleaning the iShares CSV file
import csv

with open(raw_data_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    rows = list(reader)

empty_row_indicies = [i for i in range(len(rows)) if (len(rows[i]) == 0 or '\xa0' in rows[i])]

print('Empty rows:', empty_row_indicies)

start = empty_row_indicies[0] + 1
end = empty_row_indicies[1]
cleaned_rows = rows[start:end]

with open(clean_data_path, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(cleaned_rows)

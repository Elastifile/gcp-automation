To interact with API, use the generate JWT python script to generate a valid JWT token from a service account json credentials file

Create a service account or use an existing one and download its credentials as a JSON file.

Clone git@github.com:Elastifile/elastifileapis.git


Generate JWT
The script generate a Google ID JWT token for authenticating requests with Elastifile Cloud File Service API

Supported Python Versions:
Python >= 3.4

Install the dependencies:
$ virtualenv .env
$ source .env/bin/activate
$ pip install -r requirements.txt
Run the script to generate API JWT token
Set the path to Google Service Account json file in ELASTIFILE_APPLICATION_CREDENTIALS environment variable

(.env)$ export ELASTIFILE_APPLICATION_CREDENTIALS="/path/to/service_account.json"




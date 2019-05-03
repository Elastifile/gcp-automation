#!/usr/bin/env python

# Copyright 2019 Elastifile Ltd.. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import sys
import time
import json
import argparse
import http.client
import urllib.parse
import google.auth.crypt as google_auth_crypt
import google.auth.jwt as google_auth_jwt


__CREDENTIALS_ENV_VAR__ = "ELASTIFILE_APPLICATION_CREDENTIALS"


def generate_jwt(service_account_file: str, client_email: str) -> str:
    """
    Generate service account JWT token

    :param service_account_file: Path to service account json file
    :param client_email: Service account email
    :return: JWT token
    """
    signer = google_auth_crypt.RSASigner.from_service_account_file(service_account_file)
    iat = time.time()
    exp = iat + 3600

    payload = {
        'iat': iat,
        'exp': exp,
        'iss': client_email,
        'target_audience': '563209362155-dmktm1rt2snprao3te1a5gf0tk9l39i8.apps.googleusercontent.com',
        'aud': "https://www.googleapis.com/oauth2/v4/token"
    }
    jwt = google_auth_jwt.encode(signer, payload)
    return jwt.decode('ascii')


def get_google_id_token(sa_jwt_token: str) -> str:
    """
    Request a Google ID Token using the service account JWT.

    :param sa_jwt_token: Service account generated JWT token
    """
    params = urllib.parse.urlencode({
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': sa_jwt_token
    })

    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }

    conn = http.client.HTTPSConnection("www.googleapis.com")
    conn.request("POST", "/oauth2/v4/token", params, headers)
    response = conn.getresponse()
    res = json.loads(response.read())
    conn.close()
    return res['id_token']


def usage() -> str:
    """
    Print usage
    """
    tool_name = os.path.basename(__file__)
    help_message = "This tool must get a credentials file. alternatively, you " \
                   "can set an environment variable to hold the path.\n\nUsage:\n" \
                   "python {} -f/ --file <path/to/credentials-file> \n\n" \
                   "Or, set the environment variable {}:\n" \
                   "export {}=<path/to/credentials-file> \n".format(
        tool_name, __CREDENTIALS_ENV_VAR__, __CREDENTIALS_ENV_VAR__)

    return help_message


def get_credentials_file_path_from_cli() -> str or None:
    parser = argparse.ArgumentParser(epilog=usage(),
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-f', '--file', help='The full path to your json file.')
    args = parser.parse_args()

    return args.file


def get_credentials_file_path_from_environment() -> str or None:
    return os.environ.get(__CREDENTIALS_ENV_VAR__)


def get_credentials_file_path() -> str or None:
    file_path = get_credentials_file_path_from_cli()
    if not file_path:
        file_path = get_credentials_file_path_from_environment()
    if not file_path:
        print("Environment variable {} is not set or missing path to "
              "credentials file.".format(__CREDENTIALS_ENV_VAR__))
        print(usage())
        sys.exit(1)

    return file_path


def main():
    """
    Script main method
    """
    credentials_file = get_credentials_file_path()

    try:
        with open(credentials_file) as f:
            data = json.load(f)
            client_email = data.get('client_email')
            sa_jwt_token = generate_jwt(credentials_file, client_email)
            google_id_jwt_token = get_google_id_token(sa_jwt_token)
            print("\n\nAuthorization: Bearer {}\n\n".format(google_id_jwt_token))
            sys.exit(0)
    except IOError as err:
        print("Filename '{}' {}, incorrect path for credentials file.".format(err.filename, err.strerror))
        sys.exit(1)


if __name__ == '__main__':
    main()


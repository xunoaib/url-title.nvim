#!/usr/bin/env python3
"""Fetch a URL and print its page title to stdout."""

import re
import sys

import requests
from bs4 import BeautifulSoup

USER_AGENT = (
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
)


def get_title(url: str) -> str:
    response = requests.get(url, headers={'User-Agent': USER_AGENT}, timeout=10)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, 'html.parser')
    if not soup.title or not soup.title.string:
        raise ValueError(f'No title found for {url}')
    return ' '.join(soup.title.string.split())


def main():
    if len(sys.argv) != 2:
        print('usage: get_title.py <url>', file=sys.stderr)
        sys.exit(2)

    url = sys.argv[1]
    if not re.match(r'^\w+://', url):
        url = f'https://{url}'

    try:
        print(get_title(url))
    except (requests.RequestException, ValueError) as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

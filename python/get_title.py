#!/usr/bin/env python3
"""Fetch a URL and print its page title to stdout.

If the site refuses us (HTTP 403), fall back to other sources (see
`fallback_title`) and note which one worked on stderr as "Note: ..." (exit
code stays 0). Which fallbacks may be used is chosen with --fallbacks.
"""

from __future__ import annotations

import argparse
import re
import sys
from urllib.parse import parse_qs, unquote, urlparse

import requests
from bs4 import BeautifulSoup

USER_AGENT = (
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
)
HEADERS = {'User-Agent': USER_AGENT}
TIMEOUT = 10


def html_title(html: str) -> str | None:
    soup = BeautifulSoup(html, 'html.parser')
    if soup.title and soup.title.string:
        return ' '.join(soup.title.string.split())
    return None


def words(text: str) -> list[str]:
    return re.findall(r'[^\W_]+', text)


def norm_url(url: str) -> str:
    p = urlparse(url)
    return p.netloc.lower().removeprefix('www.') + p.path.rstrip('/')


def is_truncated(title: str) -> bool:
    return title.endswith(('...', '…'))


def unwrap_redirect(href: str) -> str:
    """Undo search-engine click-tracking wrappers around a result URL."""
    m = re.search(r'/RU=([^/]+)/R[KC]=', href)  # Yahoo
    if m:
        return unquote(m.group(1))
    return parse_qs(urlparse(href).query).get('uddg', [href])[0]  # DuckDuckGo


def wayback(url: str) -> str | None:
    r = requests.get(
        'https://archive.org/wayback/available',
        params={'url': url},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    r.raise_for_status()
    snap = r.json().get('archived_snapshots', {}).get('closest')
    if not snap:
        return None
    page = requests.get(snap['url'], headers=HEADERS, timeout=TIMEOUT)
    page.raise_for_status()
    return html_title(page.text)


def duckduckgo(url: str) -> list[tuple[str, str]]:
    """Search results as (href, title) pairs."""
    r = requests.post(
        'https://html.duckduckgo.com/html/',
        data={'q': url},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    r.raise_for_status()
    soup = BeautifulSoup(r.text, 'html.parser')
    return [
        (str(a.get('href', '')), a.get_text())
        for a in soup.select('a.result__a')
    ]


def yahoo(url: str) -> list[tuple[str, str]]:
    """Search results as (href, title) pairs."""
    r = requests.get(
        'https://search.yahoo.com/search',
        params={'p': url},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    r.raise_for_status()
    soup = BeautifulSoup(r.text, 'html.parser')
    return [
        (str(a.get('href', '')), h.get_text())
        for h in soup.select('a > h3')
        if (a := h.find_parent('a'))
    ]


SEARCH_ENGINES = {'duckduckgo': ('DuckDuckGo', duckduckgo), 'yahoo': ('Yahoo', yahoo)}
FALLBACKS = ['wayback', *SEARCH_ENGINES, 'url_slug']


def search_titles(engine, url: str) -> list[str]:
    """Titles of the search results that point at `url`."""
    try:
        results = engine(url)
    except (requests.RequestException, ValueError):
        return []
    return [
        ' '.join(text.split())
        for href, text in results
        if norm_url(unwrap_redirect(href)) == norm_url(url)
    ]


def slug_words(url: str) -> list[str]:
    """Words of the last path segment, e.g. `123_Some_Title.html` -> Some Title."""
    seg = unquote(urlparse(url).path.rstrip('/').rsplit('/', 1)[-1])
    ws = words(re.sub(r'\.\w{1,5}$', '', seg))
    return ws[1:] if ws and ws[0].isdigit() else ws  # drop a leading numeric id


def complete_from_slug(partial: str, url: str) -> str | None:
    """Finish a truncated search title with the remaining words of the URL slug.

    Only done when the truncated title's words are exactly the start of the
    slug, so the tail is guaranteed to belong to the same page.
    """
    prefix = partial.rstrip('.… ')
    slug, pw = slug_words(url), words(prefix)
    if len(pw) < 2 or [w.lower() for w in slug[: len(pw)]] != [w.lower() for w in pw]:
        return None
    return ' '.join([prefix, *slug[len(pw) :]])


def fallback_title(url: str, enabled: list[str]) -> tuple[str, str] | None:
    """Return (title, description of the source) or None.

    `enabled` lists the fallbacks to use, in order. `wayback` and the search
    engines each ask a third party about the URL. Search engines truncate long
    titles, so a truncated one is completed from the URL slug when it lines up.
    `url_slug` never touches the network: it does that completion, and as a
    last resort builds a title from the URL slug alone.
    """
    partial = None
    for key in enabled:
        if key == 'wayback':
            try:
                title = wayback(url)
            except (requests.RequestException, ValueError):
                title = None
            if title:
                return title, 'title from Wayback Machine'
        elif key in SEARCH_ENGINES:
            name, engine = SEARCH_ENGINES[key]
            titles = search_titles(engine, url)
            full = next((t for t in titles if not is_truncated(t)), None)
            if full:
                return full, f'title from {name} search'
            if titles and partial is None:
                partial = (name, titles[0])

    use_slug = 'url_slug' in enabled
    if partial:
        name, title = partial
        completed = complete_from_slug(title, url) if use_slug else None
        if completed:
            return completed, f'title from {name} search, completed from URL'
        return title.rstrip('.\u2026 '), f'title from {name} search (truncated)'

    slug = slug_words(url)
    if use_slug and len(slug) >= 3:
        return ' '.join(slug), 'title reconstructed from URL'
    return None


def get_title(url: str, fallbacks: list[str]) -> tuple[str, str | None]:
    """Return (title, note); note is set when a fallback was used."""
    response = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
    if response.status_code != 403:
        response.raise_for_status()
        title = html_title(response.text)
        if not title:
            raise ValueError(f'No title found for {url}')
        return title, None

    host = urlparse(url).netloc
    found = fallback_title(url, fallbacks)
    if not found:
        detail = ', '.join(fallbacks) if fallbacks else 'fallbacks disabled'
        raise ValueError(f'HTTP 403 from {host}; no title found ({detail})')
    return found[0], f'HTTP 403 from {host}; {found[1]}'


def fallback_list(value: str) -> list[str]:
    names = list(dict.fromkeys(n for n in value.split(',') if n))
    unknown = [n for n in names if n not in FALLBACKS]
    if unknown:
        raise argparse.ArgumentTypeError(
            f'unknown fallback(s): {", ".join(unknown)} '
            f'(choose from {", ".join(FALLBACKS)})'
        )
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('url')
    parser.add_argument(
        '--fallbacks',
        type=fallback_list,
        default=FALLBACKS,
        metavar='LIST',
        help='comma-separated fallbacks to use, in order, when a site returns '
        f'403 (default: {",".join(FALLBACKS)}; empty disables them)',
    )
    args = parser.parse_args()

    url = args.url
    if not re.match(r'^\w+://', url):
        url = f'https://{url}'

    try:
        title, note = get_title(url, args.fallbacks)
    except (requests.RequestException, ValueError) as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)

    print(title)
    if note:
        print(f'Note: {note}', file=sys.stderr)


if __name__ == '__main__':
    main()

# url-title.nvim

Fetch a URL's page title and turn it into a markdown link: `[Page Title](https://example.com)`.

Title fetching is delegated to a small Python helper (`python/get_title.py`, using
`requests` + `BeautifulSoup`) run asynchronously via `vim.system`, so the editor
never blocks on the network request.

## Requirements

- Neovim 0.10+ (uses `vim.system`)
- Python 3 with `requests` and `beautifulsoup4` installed
- Run `:checkhealth url_title` to verify

## Installation (lazy.nvim)

```lua
{
  "xunoaib/url-title.nvim",
  config = function()
    require("url_title").setup({
      enable_default_keymaps = true,
    })
  end,
}
```

## Usage

| Mode   | Default keymap | Command                   | Action                                                          |
|--------|-----------------|----------------------------|------------------------------------------------------------------|
| Normal | `<leader>ut`    | `:UrlTitleInsert`          | Convert the URL under the cursor into a markdown link, in place  |
| Visual | `<leader>ut`    | `:'<,'>UrlTitleInsertVisual` | Convert the selected URL into a markdown link, in place        |
| Normal | `<leader>uT`    | `:UrlTitlePrompt`          | Prompt for a URL (`vim.ui.input`), insert the link at the cursor |

Default keymaps are off unless you pass `enable_default_keymaps = true` to
`setup()` (see Configuration below); the commands work either way. Keys are
configurable via `keymaps.insert_at_cursor` / `keymaps.prompt`.

Also exposed for other scripts/plugins:

```lua
require("url_title").get_title(url, function(title, err, note)
  -- async; title is nil and err is set on failure.
  -- note is set when a fallback was used (see "403 fallbacks")
end)
```

## Configuration

```lua
require("url_title").setup({
  python = "python3",                 -- interpreter to run the fetch script with
  -- script = "/path/to/get_title.py", -- override the bundled get_title.py path
  timeout = 10000,                    -- ms before the fetch is killed
  fallbacks = { "wayback", "duckduckgo", "yahoo", "url_slug" }, -- see below
  enable_default_keymaps = false,
  keymaps = {
    insert_at_cursor = "<leader>ut",  -- normal + visual mode
    prompt = "<leader>uT",
  },
})
```

## 403 fallbacks

Some sites answer scripted requests with HTTP 403. When that
happens the plugin tries the sources in `fallbacks`, in order, and shows a
warning notification saying which one supplied the title:

| Name         | What it does                                                | Privacy                              |
|--------------|-------------------------------------------------------------|--------------------------------------|
| `wayback`    | Uses the title of the Wayback Machine's archived copy       | URL is sent to archive.org           |
| `duckduckgo` | Searches DuckDuckGo for the URL and uses the matching result | URL is sent to DuckDuckGo            |
| `yahoo`      | Same, using Yahoo Search                                     | URL is sent to Yahoo                 |
| `url_slug`   | Completes a truncated search title from the URL's own text, or builds a title from it if nothing else worked | None (local only) |

Search engines truncate long titles, so a truncated result is completed from the
URL slug when its words match the start of it (punctuation the URL doesn't
carry, such as colons, is lost). Without `url_slug` a truncated title is used
as-is, minus the trailing "...".

The fallbacks only run after a 403; normal pages never contact these services.
To opt out of any of them, remove it from the list, e.g. `fallbacks = { "url_slug" }`
to stay fully local, or `fallbacks = {}` to disable fallbacks entirely.
`:checkhealth url_title` shows which are active.

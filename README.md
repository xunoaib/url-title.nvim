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
require("url_title").get_title(url, function(title, err)
  -- async; title is nil and err is set on failure
end)
```

## Configuration

```lua
require("url_title").setup({
  python = "python3",                 -- interpreter to run the fetch script with
  -- script = "/path/to/get_title.py", -- override the bundled get_title.py path
  timeout = 10000,                    -- ms before the fetch is killed
  enable_default_keymaps = false,
  keymaps = {
    insert_at_cursor = "<leader>ut",  -- normal + visual mode
    prompt = "<leader>uT",
  },
})
```

## Other possible use cases (not implemented)

- Bulk-convert every bare URL in a buffer/range/paragraph in one pass.
- Cache fetched titles (in-memory or on disk) so re-inserting the same URL
  doesn't refetch it.
- Fallback to `og:title`/meta description when `<title>` is missing, or fetch
  a favicon alongside the title.
- Auto-convert a bare URL to a markdown link automatically on paste (e.g. via
  `TextChanged`/`InsertCharPre` in markdown buffers).
- A command that fetches the title and yanks/prints it without editing the
  buffer.
- Support for reference-style links (`[title][n]` + a footnote definition)
  as an alternative to inline links.
- A headless-browser fallback (e.g. Playwright) for JS-rendered pages whose
  `<title>` isn't present in the initial HTML.
- `blink.cmp`/`nvim-cmp` source that offers a title-generated link as
  completion when typing a raw URL.

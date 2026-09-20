local M = {}

-- resolve plugin root (works regardless of where installed)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

M.config = {
  python = "python3",
  script = plugin_root .. "/python/get_title.py",
  timeout = 10000, -- ms
  enable_default_keymaps = false,
  keymaps = {
    insert_at_cursor = "<leader>ut",
    prompt = "<leader>uT",
  },
}

--- Setup user configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.enable_default_keymaps then
    vim.keymap.set("n", M.config.keymaps.insert_at_cursor, function()
      require("url_title").insert_from_cursor()
    end, { desc = "Convert URL under cursor to markdown link" })

    vim.keymap.set("x", M.config.keymaps.insert_at_cursor, function()
      require("url_title").insert_from_selection()
    end, { desc = "Convert visual selection to markdown link" })

    vim.keymap.set("n", M.config.keymaps.prompt, function()
      require("url_title").prompt_and_insert()
    end, { desc = "Prompt for a URL and insert as markdown link" })
  end
end

--- Asynchronously fetch the page title for `url`.
--- Exposed so other scripts/plugins can retrieve a title without going through
--- the buffer-editing commands below.
--- @param url string
--- @param callback fun(title: string|nil, err: string|nil)
function M.get_title(url, callback)
  require("url_title.fetch").get_title(url, callback)
end

local function replace_with_link(row, start_col, end_col, url)
  vim.notify("url_title: fetching title...", vim.log.levels.INFO)
  M.get_title(url, function(title, err)
    if err then
      vim.notify("url_title: " .. err, vim.log.levels.ERROR)
      return
    end
    local util = require("url_title.util")
    local link = string.format("[%s](%s)", util.sanitize_markdown(title), url)
    vim.api.nvim_buf_set_text(0, row - 1, start_col, row - 1, end_col, { link })
  end)
end

--- Convert the URL under the cursor (normal mode) into a markdown link.
function M.insert_from_cursor()
  local util = require("url_title.util")
  local url, start_col, end_col = util.find_url_under_cursor()
  if not url then
    vim.notify("url_title: no URL found under cursor", vim.log.levels.WARN)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  replace_with_link(row, start_col, end_col, url)
end

--- Convert the current (single-line) visual selection into a markdown link.
function M.insert_from_selection()
  local util = require("url_title.util")
  local url, row, start_col, end_col = util.get_visual_selection()
  if not url then
    return
  end
  replace_with_link(row, start_col, end_col, url)
end

--- Prompt the user for a URL, then insert it as a markdown link at the cursor.
function M.prompt_and_insert()
  vim.ui.input({ prompt = "URL: " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    -- strip ALL whitespace, not just leading/trailing: a pasted URL can pick
    -- up an embedded/trailing newline from the clipboard, which a 1-line
    -- input widget may only show blank rather than as visible whitespace
    local url = (input:gsub("%s+", ""))
    if not url:match("^%a[%w+.-]*://") then
      url = "https://" .. url
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.notify("url_title: fetching title...", vim.log.levels.INFO)
    M.get_title(url, function(title, err)
      if err then
        vim.notify("url_title: " .. err, vim.log.levels.ERROR)
        return
      end
      local util = require("url_title.util")
      local link = string.format("[%s](%s)", util.sanitize_markdown(title), url)
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { link })
      vim.api.nvim_win_set_cursor(0, { row, col + #link })
    end)
  end)
end

return M

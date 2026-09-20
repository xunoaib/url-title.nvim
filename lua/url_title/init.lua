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

-- If the vim.ui.input backend just opened is a real prompt-buffer (Snacks,
-- dressing.nvim, etc.), pasting text with a newline splits it across two
-- buffer lines. A height-1 window then shows whichever line the cursor
-- lands on, which can look empty even though the text wasn't lost. Keep it
-- collapsed to a single, already-sanitized line as the user types/pastes so
-- the widget never visually breaks.
local function guard_single_line_input()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "prompt" then
    return
  end
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    buffer = buf,
    callback = function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if #lines <= 1 then
        return
      end
      local sanitized = require("url_title.util").sanitize_url_input(table.concat(lines, "\n"))
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { sanitized })
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        pcall(vim.api.nvim_win_set_cursor, win, { 1, #sanitized })
      end
    end,
  })
end

--- Prompt the user for a URL, then insert it as a markdown link at the cursor.
function M.prompt_and_insert()
  vim.ui.input({ prompt = "URL: " }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    local util = require("url_title.util")
    local url = util.sanitize_url_input(input)
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
      local link = string.format("[%s](%s)", util.sanitize_markdown(title), url)
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { link })
      vim.api.nvim_win_set_cursor(0, { row, col + #link })
    end)
  end)
  guard_single_line_input()
end

return M

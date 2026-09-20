local M = {}

-- http(s) URL, stopping before common trailing/wrapping punctuation.
M.URL_PATTERN = "https?://[^%s()<>%[%]\"']+"

--- Escape markdown-significant characters so a fetched title is safe as a link label.
function M.sanitize_markdown(text)
  return (text:gsub("([\\`*_%[%]()#+.!|<>~%-])", "\\%1"))
end

--- Trim outer whitespace and percent-encode whatever whitespace is left in
--- the middle (rather than dropping it, which could silently corrupt the
--- URL). Used both for the final submitted value and to keep a single-line
--- input widget from visually breaking when a paste contains a newline.
function M.sanitize_url_input(text)
  return (vim.trim(text):gsub("%s", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

--- Find the URL under the cursor on the current line.
--- @return string|nil url
--- @return integer|nil start_col 0-indexed
--- @return integer|nil end_col 0-indexed, exclusive
function M.find_url_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
  local init = 1
  while true do
    local s, e = line:find(M.URL_PATTERN, init)
    if not s then
      return nil
    end
    if cursor_col >= s - 1 and cursor_col < e then
      return line:sub(s, e), s - 1, e
    end
    init = e + 1
  end
end

--- Get the current (single-line) visual selection.
--- Works both while Visual mode is still active (a keymap callback runs
--- *before* '< / '> are updated) and afterwards (e.g. a ranged Ex command),
--- by reading the live "v"/"." positions in the former case.
--- @return string|nil url
--- @return integer|nil row 1-indexed
--- @return integer|nil start_col 0-indexed
--- @return integer|nil end_col 0-indexed, exclusive
function M.get_visual_selection()
  local mode = vim.fn.mode()
  local from, to
  if mode == "v" or mode == "V" or mode == "\22" then
    from = vim.fn.getpos("v")
    to = vim.fn.getpos(".")
  else
    from = vim.fn.getpos("'<")
    to = vim.fn.getpos("'>")
  end

  local srow, scol = from[2], from[3]
  local erow, ecol = to[2], to[3]
  if srow > erow or (srow == erow and scol > ecol) then
    srow, erow, scol, ecol = erow, srow, ecol, scol
  end
  if srow ~= erow then
    vim.notify("url_title: multi-line selections are not supported", vim.log.levels.ERROR)
    return nil
  end

  local line = vim.fn.getline(srow)
  ecol = math.min(ecol, #line)
  local raw = line:sub(scol, ecol)
  local lead, text, trail = raw:match("^(%s*)(.-)(%s*)$")
  if text == "" then
    return nil
  end
  return text, srow, scol - 1 + #lead, ecol - #trail
end

return M

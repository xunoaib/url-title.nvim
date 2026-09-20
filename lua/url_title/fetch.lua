local M = {}

--- Asynchronously fetch the page title for `url`.
--- @param url string
--- @param callback fun(title: string|nil, err: string|nil) called on the main loop
function M.get_title(url, callback)
  local config = require("url_title").config

  vim.system(
    { config.python, config.script, url },
    { text = true, timeout = config.timeout },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local err = vim.trim(result.stderr or "")
          if err == "" then
            err = string.format("failed to fetch title (exit %d)", result.code)
          end
          callback(nil, err)
          return
        end

        local title = vim.trim(result.stdout or "")
        if title == "" then
          callback(nil, "empty title")
          return
        end

        callback(title, nil)
      end)
    end
  )
end

return M

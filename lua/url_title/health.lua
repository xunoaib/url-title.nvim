local M = {}

function M.check()
  local health = vim.health
  health.start("url_title.nvim")

  local config = require("url_title").config

  if vim.fn.executable(config.python) == 1 then
    health.ok(string.format("`%s` is executable", config.python))
  else
    health.error(string.format("`%s` not found on PATH", config.python))
    return
  end

  if vim.fn.filereadable(config.script) == 1 then
    health.ok("fetch script found: " .. config.script)
  else
    health.error("fetch script not found: " .. config.script)
    return
  end

  local result = vim.system({ config.python, "-c", "import requests, bs4" }, { text = true }):wait()
  if result.code == 0 then
    health.ok("`requests` and `beautifulsoup4` are importable")
  else
    health.error("missing python dependencies", { "install with: pip install requests beautifulsoup4" })
  end
end

return M

if vim.g.loaded_url_title then
  return
end
vim.g.loaded_url_title = true

vim.api.nvim_create_user_command("UrlTitleInsert", function()
  require("url_title").insert_from_cursor()
end, { desc = "Convert URL under cursor to a markdown link" })

vim.api.nvim_create_user_command("UrlTitleInsertVisual", function()
  require("url_title").insert_from_selection()
end, { range = true, desc = "Convert visual selection to a markdown link" })

vim.api.nvim_create_user_command("UrlTitlePrompt", function()
  require("url_title").prompt_and_insert()
end, { desc = "Prompt for a URL and insert it as a markdown link" })

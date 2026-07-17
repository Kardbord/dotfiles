vim.api.nvim_create_user_command('UpdateAll', function()
  vim.treesitter.language.update()
  require('mason-registry').update()
  require('lazy').update()
end, { desc = 'Update all plugins and dependencies (Treesitter, Mason, Lazy)' })


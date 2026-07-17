vim.api.nvim_create_user_command('UpdateAll', function()
  require('nvim-treesitter.install').update { with_sync = true }
  require('mason-registry').update()
  require('lazy').update()
end, { desc = 'Update all plugins and dependencies (Treesitter, Mason, Lazy)' })


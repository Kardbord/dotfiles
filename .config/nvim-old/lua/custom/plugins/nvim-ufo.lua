return {
  'kevinhwang91/promise-async',
  {
    'kevinhwang91/nvim-ufo',
    dependencies = { 'kevinhwang91/promise-async' },
    config = function()
      vim.opt.foldcolumn = '1' -- '0' is not bad
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
      vim.opt.foldenable = true

      -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
      vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
      vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)

      -- Setup nvim-ufo with LSP provider
      -- Note: The folding capabilities are added to LSP servers in init.lua
      require('ufo').setup()
    end,
  },
}

return {
  'farmergreg/vim-lastplace',
  'github/copilot.vim',
  'nvim-lua/plenary.nvim',
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'nvim-lua/plenary.nvim', branch = 'master' },
    },
    build = 'make tiktoken',
    opts = {
      model = 'gpt-5-mini', -- AI model to use
      temperature = 0.1, -- Lower = focused, higher = creative
      window = {
        layout = 'float', -- 'vertical', 'horizontal', 'float'
        width = 0.5, -- 50% of screen width
      },
      auto_insert_mode = true, -- Enter insert mode when opening
      functions = {
        file_glob = {
          group = 'copilot',
          description = 'Adds multiple files to the context based on a glob pattern',
          uri = 'files://glob_contents/{pattern}',
          schema = {
            type = 'object',
            required = { 'pattern' },
            properties = {
              pattern = {
                type = 'string',
                description = "Glob pattern to match files (e.g. '*.py')",
                default = '**/*',
              },
            },
          },
          resolve = function(input, source)
            local files = require('CopilotChat.utils.files').glob(source.cwd(), {
              pattern = input.pattern,
            })

            local resources = {}
            for _, file_path in ipairs(files) do
              local data, mimetype = require('CopilotChat.resources').get_file(file_path)
              if data then
                table.insert(resources, {
                  uri = 'file://' .. file_path,
                  name = file_path,
                  mimetype = mimetype,
                  data = data,
                })
              end
            end

            return resources
          end,
        },
      },
    },
  },
}

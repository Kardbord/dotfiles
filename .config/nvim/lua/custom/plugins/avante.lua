return {
  {
    'yetone/avante.nvim',
    -- ⚠️ must add this setting! ! !
    build = vim.fn.has 'win32' ~= 0 and 'powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false' or 'make',
    event = 'VimEnter',
    version = false, -- Never set this value to "*"! Never!
    ---@module 'avante'
    ---@type avante.Config
    opts = {
      -- this file can contain specific instructions for your project
      instructions_file = 'AGENTS.md',
      -- Disabled tools for standard providers
      disabled_tools = {
        'bash', -- Disable the built-in bash tool (replaced by our custom bash_cmd tool)
        'git_commit', -- Disable the built-in git commit tool (replaced by our custom git tool)
      },
      mode = 'agentic',
      behaviour = {
        enable_fastapply = false,
        auto_approve_tool_permissions = false,
        confirmation_ui_style = 'inline_buttons', -- 'inline_buttons' or 'popup'
      },
      -- Use our custom tools for standard providers
      -- NOTE: Wrapped in a function to defer loading until avante modules are available
      custom_tools = function()
        return {
          require 'custom.avante-tools.bash-tool',
          require 'custom.avante-tools.git-tool',
        }
      end,
      provider = 'openrouter_free',
      web_search_engine = {
        provider = 'tavily', -- tavily, serpapi, google, kagi, brave, or searxng
        proxy = nil,
      },
      providers = {
        openrouter_free = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'openrouter/free',
        },
        openrouter_auto = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'openrouter/auto',
        },
        openrouter_haiku = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'anthropic/claude-haiku-4.5:floor',
        },
        openrouter_sonnet = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'anthropic/claude-sonnet-4.6:floor',
        },
        openrouter_deepseek_4_pro = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'deepseek/deepseek-v4-pro:floor',
        },
        openrouter_deepseek_4_flash = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'deepseek/deepseek-v4-flash:floor',
        },
        openrouter_deepseek_4_flash_free = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'deepseek/deepseek-v4-flash:free',
        },
        openrouter_qwen = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'qwen/qwen3.6-flash:floor',
        },
        openrouter_llama = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'nvidia/llama-3.3-nemotron-super-49b-v1.5:floor',
        },
        openrouter_mistral = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'mistralai/codestral-embed-2505:floor',
        },
        openrouter_gemini = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = '~google/gemini-flash-latest:floor',
        },
        openrouter_gemma = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'google/gemma-4-31b-it:free',
        },
        openrouter_kimi = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'moonshotai/kimi-k2.6:floor',
        },
        openrouter_glm = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'z-ai/glm-5.1:floor',
        },
        openrouter_mimo = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'xiaomi/mimo-v2.5-pro:floor',
        },
        openrouter_minimax = {
          __inherited_from = 'openai',
          api_key_name = 'OPENROUTER_API_KEY',
          endpoint = 'https://openrouter.ai/api/v1',
          model = 'minimax/minimax-m2.7:floor',
        },
      },
      acp_providers = {
        opencode_plan_free = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "openrouter/free",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_free = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "openrouter/free",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_auto = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "openrouter/auto",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_auto = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "openrouter/auto",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_deepseek_flash = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "deepseek/deepseek-v4-flash:free",
              "small_model": "deepseek/deepseek-v4-flash:free",
            }
            ]],
          },
        },
        opencode_build_deepseek_flash = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "deepseek/deepseek-v4-flash:free",
              "small_model": "deepseek/deepseek-v4-flash:free",
            }
            ]],
          },
        },
        opencode_plan_anthropic = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "anthropic/claude-sonnet-4.6:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_anthropic = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "anthropic/claude-haiku-4.5:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_kimi = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "moonshotai/kimi-k2.6:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_kimi = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "moonshotai/kimi-k2.6:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_qwen = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "qwen/qwen3.6-plus:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_qwen = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "qwen/qwen3.6-flash:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_mistral = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "mistralai/devstral-2512:floor",
              "small_model": "mistralai/mistral-small-2603:floor",
            }
            ]],
          },
        },
        opencode_build_mistral = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "mistralai/devstral-2512:floor",
              "small_model": "mistralai/mistral-small-2603:floor",
            }
            ]],
          },
        },
        opencode_plan_gemini = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "google/gemini-3.5-flash:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_gemini = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "google/gemini-3.5-flash:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_gemma = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "google/gemma-4-31b-it:free",
              "small_model": "google/gemma-4-31b-it:free",
            }
            ]],
          },
        },
        opencode_build_gemma = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "google/gemma-4-31b-it:free",
              "small_model": "google/gemma-4-31b-it:free",
            }
            ]],
          },
        },
        opencode_plan_glm = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "z-ai/glm-5.1:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_glm = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "z-ai/glm-5.1:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_mimo = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "xiaomi/mimo-v2.5:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_mimo = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "xiaomi/mimo-v2.5:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_minimax = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "minimax/minimax-m2.7:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_minimax = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "minimax/minimax-m2.7:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_granite = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "ibm-granite/granite-4.1-8b:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_granite = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "ibm-granite/granite-4.1-8b:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_kat = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "kwaipilot/kat-coder-pro-v2:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_kat = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "kwaipilot/kat-coder-pro-v2:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_ring = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "inclusionai/ring-2.6-1t:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_ring = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "inclusionai/ring-2.6-1t:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_plan_mercury = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "plan",
              "model": "inception/mercury-2:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
        opencode_build_mercury = {
          command = 'npx',
          args = { '--yes', 'opencode-ai', 'acp' },
          env = {
            OPENROUTER_API_KEY = os.getenv 'OPENROUTER_API_KEY',
            OPENCODE_CONFIG_DIR = './custom/opencode-config',
            OPENCODE_ENABLE_EXA = true,
            OPENCODE_CONFIG_CONTENT = [[
            {
              "default_agent": "build",
              "model": "inception/mercury-2:floor",
              "small_model": "openrouter/free",
            }
            ]],
          },
        },
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      --- The below dependencies are optional,
      'nvim-mini/mini.pick', -- for file_selector provider mini.pick
      'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
      'hrsh7th/nvim-cmp', -- autocompletion for avante commands and mentions
      'ibhagwan/fzf-lua', -- for file_selector provider fzf
      'stevearc/dressing.nvim', -- for input provider dressing
      'folke/snacks.nvim', -- for input provider snacks
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      --'zbirenbaum/copilot.lua', -- for providers='copilot'
      {
        -- support for image pasting
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { 'markdown', 'Avante' },
        },
        ft = { 'markdown', 'Avante' },
      },
    },
  },
}

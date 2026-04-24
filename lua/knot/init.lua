--- knot.nvim — Neovim support for the knot dotfiles manager.
---
--- Provides:
---   - Filetype detection for files named exactly "Knotfile"
---   - Treesitter YAML parser override for knotfile buffers
---   - Optional automatic yaml-language-server schema configuration
---
--- Minimum requirement: Neovim 0.10+

local M = {}

--- The published JSON Schema URL for Knotfile validation.
M.schema_url = "https://raw.githubusercontent.com/oxGrad/knot/main/schema/knotfile.schema.json"

local defaults = {
  -- Automatically tell yaml-language-server to validate Knotfile buffers
  -- using the official JSON Schema. Requires nvim-lspconfig + yamlls.
  auto_configure_yamlls = true,
}

--- Register the 🪢 icon with nvim-web-devicons for the knotfile filetype.
--- Called automatically from setup(); safe to call if devicons is not installed.
function M._register_devicon()
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then return end
  local icon_data = {
    icon  = "🪢",
    color = "#a78bfa",
    cterm_color = "141",
    name  = "Knotfile",
  }
  -- Key must be lowercase: get_icon_data() lowercases the lookup name before
  -- checking icons[], so "Knotfile" as a key would never match.
  devicons.set_icon({ knotfile = icon_data })
  -- set_icon_by_filetype maps filetype → icon name (string), not icon data.
  -- The name "knotfile" must match the key used in set_icon above.
  if devicons.set_icon_by_filetype then
    devicons.set_icon_by_filetype({ knotfile = "knotfile" })
  end
end

--- Set up the plugin.
---@param opts table|nil  Optional overrides for the default config table.
function M.setup(opts)
  local cfg = vim.tbl_deep_extend("force", defaults, opts or {})

  -- 1. Register "Knotfile" → "knotfile" filetype mapping.
  --    Belt-and-suspenders alongside ftdetect/knotfile.vim.
  vim.filetype.add({
    filename = {
      ["Knotfile"] = "knotfile",
    },
  })

  -- 2. Register the 🪢 devicon (no-op if nvim-web-devicons is not installed).
  M._register_devicon()

  -- 3. Tell treesitter that knotfile buffers use the yaml parser, so that
  --    nvim-treesitter's auto-highlight and text-objects work out of the box.
  --    We use language.register() rather than vim.treesitter.start() because
  --    start() disables the Vim syntax engine, which would prevent
  --    syntax/knotfile.vim from providing fallback highlighting for users
  --    who do not have nvim-treesitter installed.
  if vim.fn.has("nvim-0.9") == 1 and vim.treesitter.language ~= nil then
    pcall(vim.treesitter.language.register, "yaml", "knotfile")
  end

  -- 4. Optionally configure yamlls schema at runtime.
  if cfg.auto_configure_yamlls then
    M._configure_yamlls()
  end
end

--- Notify the active yaml-language-server client to associate the Knotfile
--- schema with all files named "Knotfile" via workspace/didChangeConfiguration.
function M._configure_yamlls()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "knotfile",
    group = vim.api.nvim_create_augroup("KnotfileYamlls", { clear = true }),
    callback = function()
      local clients = vim.lsp.get_clients({ name = "yamlls" })
      for _, client in ipairs(clients) do
        local settings = vim.tbl_deep_extend("force", client.config.settings or {}, {
          yaml = {
            schemas = {
              [M.schema_url] = "**/Knotfile",
            },
          },
        })
        client.notify("workspace/didChangeConfiguration", { settings = settings })
      end
    end,
  })
end

return M

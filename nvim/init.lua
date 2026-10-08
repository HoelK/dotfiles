--Config alises
k = vim.keymap
o = vim.opt
a = vim.api
w = vim.wo
g = vim.g

g.mapleader			= ' '

--Formatting
o.tabstop			= 4
o.shiftwidth		= 4
o.relativenumber	= true
o.number			= true

--Keymaps
o.mouse = ""
k.set('i', '<tab>', '<C-n>')
k.set('n', '<Leader>d', '<cmd>Explore<CR>')

-----------PLUGINS-----------
vim.pack.add({
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

--Theme--
require("tokyonight").setup({ transparent = true })
vim.cmd.colorscheme("tokyonight")

--Style--
local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
	
    "TelescopeNormal",
    "TelescopeBorder",

	"TelescopePromptTitle",
    "TelescopePromptNormal",
    "TelescopePromptBorder",

    "TelescopeResultsNormal",
    "TelescopeResultsBorder",
    "TelescopePreviewNormal",
    "TelescopePreviewBorder",

    "FloatBorder",
    "FloatTitle",
}

for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE" })
end

a.nvim_set_hl(0, 'LineNr', { fg = '#33CCFF', bold = true })

a.nvim_set_hl(0, 'LineNrAbove', { link = 'LineNr' })
a.nvim_set_hl(0, 'LineNrBelow', { link = 'LineNr' })
a.nvim_set_hl(0, 'CursorLineNr', { link = 'LineNr' })

--Telescope--
local builtin = require('telescope.builtin')
k.set('n', '<leader>ff', builtin.find_files)

--Treesitter--
require("nvim-treesitter").install({ "go", "gomod", "gosum", "gowork", "gotmpl" })

a.nvim_create_autocmd("FileType",
{
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})

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
k.set('i', '<tab>', '<C-n>')

-----------PLUGINS-----------
vim.pack.add({
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/nvim-telescope/telescope.nvim" },
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
    a.nvim_set_hl(0, group, { bg = "NONE" })
end


--Telescope--
local builtin = require('telescope.builtin')
k.set('n', '<leader>ff', builtin.find_files)

--Treesitter--
a.nvim_create_autocmd("FileType",
{
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})

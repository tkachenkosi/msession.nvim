### A minimalistic and highly-efficient session manager for the Neovim editor.
---
#### Installation and Usage:
```
vim.keymap.set({'n', 'i'}, '<F12>', function() require('mbuffers').start(); end)
vim.keymap.set('n', '<leader><F12>', function() require('msession').start(); end)

Setting up for Lazy:
In the plugins/msession.lua file, we add the commands:

{
"tkachenkosi/msession.nvim",
config = function()
	require("msession").setup({
		width_win = 0,
	})
end,
}

DEFAULT_OPTIONS = {
width_win = 0,				-- the width of the window, if = 0 is calculated
color_cursor_line = "#2b2b2b",		-- the color of the line highlight with the cursor
color_cursor_mane_line = "#2b2b2b",	-- the color of the line highlight in the main editor
color_light_path = "#ada085",	   	-- the color of the path selection from the file name
color_light_filter = "#224466",		-- the color of the filter input line
}
```
#### Keys in the buffer list window:
Esc, q      - close the session manager window

f, c-Up     - switch to the filter input line

s           - save session

CR          - open the selected session

#### Keys in the filter input window:
Esc         - close the session manager window

CR, Down    - go to the session list window

#### Command:

|lua require("msession").start()|

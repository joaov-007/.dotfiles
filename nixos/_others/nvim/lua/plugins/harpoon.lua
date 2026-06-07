return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{ "<leader>a", function() require("harpoon"):list():add() end, desc = "Harpoon add file" },
		{ "<C-e>", function() require("harpoon.ui"):toggle_quick_menu() end, desc = "Harpoon quick menu" },
		{ "<A-1>", function() require("harpoon"):list():select(1) end, desc = "Harpoon to mark 1" },
		{ "<A-2>", function() require("harpoon"):list():select(2) end, desc = "Harpoon to mark 2" },
		{ "<A-3>", function() require("harpoon"):list():select(3) end, desc = "Harpoon to mark 3" },
		{ "<A-4>", function() require("harpoon"):list():select(4) end, desc = "Harpoon to mark 4" },
		{ "<A-5>", function() require("harpoon"):list():select(5) end, desc = "Harpoon to mark 5" },
	},
	config = function()
		require("harpoon").setup()
	end,
}

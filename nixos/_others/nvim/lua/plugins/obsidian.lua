return {
	"epwalsh/obsidian.nvim",
	ft = "markdown",
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {
		workspaces = {
			{
				name = "bigBrain",
				path = "/home/jaov/Documents/data/vault/bigBrain",
			},
		},
		note_id_func = function(title)
			local suffix = ""
			if title then
				suffix = "_" .. title
			end
			return os.date("%Y%m%d%H%M%S") .. suffix
		end,
	},
}

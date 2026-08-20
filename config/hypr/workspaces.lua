-- Workspace-to-monitor bindings
-- Only meaningful on multi-monitor machines. A composing file may skip
-- loading this; rules naming absent outputs are inert either way.
--
-- Monitor mapping (from nwg-displays):
--   DP-3 = Left
--   DP-1 = Center
--   DP-2 = Right

-- Center monitor - terminal, dev
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1" })

-- Left monitor - comms, ai, ai-dev, ai-dev-ext
hl.workspace_rule({ workspace = "4", monitor = "DP-3", default = true, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-3" })
hl.workspace_rule({ workspace = "6", monitor = "DP-3" })
hl.workspace_rule({ workspace = "8", monitor = "DP-3" })

-- Right monitor - web, web-ext, misc
hl.workspace_rule({ workspace = "3", monitor = "DP-2", default = true, persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-2" })
hl.workspace_rule({ workspace = "9", monitor = "DP-2" })

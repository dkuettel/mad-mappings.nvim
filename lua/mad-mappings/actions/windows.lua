-- TODO wrap nicer (in exprs)
-- maybe this file here is actions/layouts.lua instead?
-- ideally the behavior when lavish-layouts doesnt exist is like this:
-- we still have all the keys (new, next, previous, ...) but they just output "lavish-layouts" missing, or just noop
local layouts = require("lavish-layouts")

local nv = require("mad-mappings").make_action_nv

return {
    new = nv { "new window", expr = layouts.new_from_split },
    next = nv { "next window", expr = layouts.next },
    previous = nv { "previous window", expr = layouts.previous },
    focus = nv { "focus window", expr = layouts.focus },
    only = nv { "only window", rhs = "<cmd>windcmd o<enter>" },
    close = nv { "close window", expr = layouts.close },
    close_and_delete = nv { "close and delete window", expr = layouts.close_and_delete },
    switch_main_layout = nv { "windows main layout", expr = layouts.switch_main },
    switch_stacked_layout = nv { "windows stacked layout", expr = layouts.switch_stacked },
}

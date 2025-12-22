return {
    ---@return mad-mappings.Maps
    example_mappings = function()
        local mm = require("mad-mappings")
        local context = mm.actions.context
        local plain = mm.actions.plain
        local windows = mm.actions.windows

        return {
            default = {
                nv = {
                    u = plain.some_up,
                    e = plain.some_down,
                },
                n = {
                    ww = windows.new,
                    wu = context.push("windows", windows.previous),
                    we = context.push("windows", windows.next),
                    ["w."] = windows.only,
                    ["w,"] = windows.close,
                    wd = windows.close_and_delete,
                    wm = windows.switch_main,
                    ws = windows.switch_stacked,
                },
            },
            windows = {
                -- NOTE we can have a config here
                n = {
                    u = windows.next,
                    e = windows.previous,
                    f = context.pop(windows.focus),
                    [","] = context.pop(windows.close),
                    d = windows.close_and_delete,
                    w = context.pop(windows.new),
                },
            },
        }
    end,
}

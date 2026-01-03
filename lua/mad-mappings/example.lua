return {
    ---@return mad-mappings.Maps
    example_mappings = function()
        local mm = require("mad-mappings")
        local context = mm.actions.context
        local plain = mm.actions.plain
        local windows = mm.actions.windows
        local visual = mm.actions.visual

        return {
            default = {
                -- fn = function() end,
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

                    -- visual
                    [" v"] = visual.block,
                    aav = visual.previous,
                    vn = visual.line,
                    ["v."] = visual.char,
                    ve = visual.word,
                    ["n e"] = visual.word_with_space,
                    nu = visual.up_word,
                    ["n u"] = visual.up_word_with_space,
                    np = visual.inner_paragraph,
                    ["n p"] = visual.outer_paragraph,
                    ["n("] = visual.inner_bracket,
                    ["n)"] = visual.outer_bracket,
                    ["n{"] = visual.inner_curly,
                    ["n}"] = visual.outer_curly,
                    ["n["] = visual.inner_square,
                    ["v]"] = visual.outer_square,
                    ["n<"] = visual.inner_angular,
                    ["n>"] = visual.outer_angular,
                    ['n"'] = visual.inner_quote,
                    ['n "'] = visual.outer_quote,
                    ["n'"] = visual.inner_tick,
                    ["n '"] = visual.outer_tick,
                    ["n`"] = visual.inner_backtick,
                    ["n `"] = visual.outer_backtick,
                    vc = visual.comment,
                    -- vt = context.push("treesitter", ts.init_selection),

                    -- { [[v]], v, "exit visual", rhs = "<esc>" },
                    -- { [[ v]], v, "other side", rhs = "o" },
                    -- { [[U]], v, "make uppercase", rhs = "U" },
                    -- { [[E]], v, "make lowercase", rhs = "u" },
                },
            },
            -- treesitter = {
            --     u = treesitter.next,
            --     e = treesitter.previous,
            --     esc = context.pop(nil),
            -- },
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

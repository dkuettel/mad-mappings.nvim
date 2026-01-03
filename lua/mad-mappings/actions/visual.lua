local make = require("mad-mappings").make_action
local v = require("mad-mappings").make_action_v

return {
    block = make { "n", "visual block", rhs = "<c-v>" },
    previous = make { "n", "previous visual", rhs = "gv" },
    other_side = make { "n", "other side", rhs = "o" },
    to_upper = v { "make uppercase", rhs = "U" },
    to_lower = v { "make lowercase", rhs = "u" },

    line = v { "visual line", rhs = "V" },
    char = v { "visual character", rhs = "v" },
    word = v { "visual word", rhs = "viw" },
    word_with_space = v { "visual word with space", rhs = "vaw" },
    up_word = v { "visual word", rhs = "viW" },
    up_word_with_space = v { "visual word with space", rhs = "vaW" },
    inner_paragraph = v { "visual inner paragraph", rhs = "vip" },
    outer_paragraph = v { "visual outer paragraph", rhs = "vap" },
    inner_bracket = v { "visual inner ()", rhs = "vib" },
    outer_bracket = v { "visual outer ()", rhs = "vab" },
    inner_curly = v { "visual inner {}", rhs = "viB" },
    outer_curly = v { "visual outer {}", rhs = "vaB" },
    inner_square = v { "visual inner []", rhs = "vi[" },
    outer_square = v { "visual outer []", rhs = "va]" },
    inner_angular = v { "visual inner <>", rhs = "vi<" },
    outer_angular = v { "visual outer <>", rhs = "va<" },
    inner_quote = v { 'visual inner "', rhs = 'vi"' },
    outer_quote = v { '"visual outer "', rhs = 'va"' },
    inner_tick = v { "visual inner '", rhs = "vi'" },
    outer_tick = v { "visual outer '", rhs = "va'" },
    inner_backtick = v { "visual inner `", rhs = "vi`" },
    outer_backtick = v { "visual outer `", rhs = "va`" },
    comment = v { "visual comment", fn = require("vim._comment").textobject },
}

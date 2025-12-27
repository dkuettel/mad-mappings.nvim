---@param delay number milliseconds
---@param disengage number milliseconds
local function rapid_trigger_context(delay, disengage)
    local last = vim.uv.now() - delay ---@diagnostic disable-line: undefined-field
    local engaged = false

    ---@param slow fun(): string
    ---@param fast fun(): string
    ---@return fun(): string
    return function(slow, fast)
        return function()
            local now = vim.uv.now() ---@diagnostic disable-line: undefined-field
            local elapsed = now - last
            last = now
            if not engaged and elapsed < delay then
                engaged = true
                return fast()
            end
            if engaged and elapsed < disengage then
                return fast()
            end
            engaged = false
            return slow()
        end
    end
end

local rapid = rapid_trigger_context(50, 1000)

local function down()
    return "gj" -- treats wrapped lines as they appear
end

local function down_fast()
    if vim.fn.winline() < vim.fn.winheight(0) / 2 - 1 then
        -- return "j"
        return "gj" -- treats wrapped lines as they appear
    else
        -- return "1<c-d>"
        -- NOTE the above moves the cursor horizontally, the below works, but flickers a bit
        -- (with vim.opt.lazyredraw = true the flicker is gone here)
        if vim.fn.winheight(0) - vim.fn.winline() <= vim.o.scrolloff then
            return "gj"
        else
            return "gj<c-e>"
        end
    end
end

local function up()
    -- return "k"
    return "gk" -- treats wrapped lines as they appear
end

local function up_fast()
    if vim.fn.winline() > vim.fn.winheight(0) / 2 + 1 then
        return "gk" -- treats wrapped lines as they appear
    else
        -- return "1<c-u>"
        -- NOTE the above moves the cursor horizontally, the below works, but flickers a bit
        -- (with vim.opt.lazyredraw = true the flicker is gone here)
        if vim.fn.winline() <= vim.o.scrolloff + 1 then
            return "gk"
        else
            return "gk<c-y>"
        end
    end
end

---@param d number sign is direction, fraction is relative to page size
local function page(d)
    -- NOTE we use this instead of ctrl-u and ctrl-d, they have problems keeping the cursor in the same column always
    -- NOTE this calculation is off with folds, im not using them, also disabled in diff mode
    -- TODO paging is a bit off at the top and bottom with scrolloff, but maybe that's okay?
    return function()
        local view = vim.fn.winsaveview()
        local s = math.floor(d * (vim.api.nvim_win_get_height(0) - 1))
        local h = vim.api.nvim_buf_line_count(0)
        vim.fn.winrestview {
            lnum = math.min(math.max(1, view.lnum + s), h),
            topline = math.min(math.max(1, view.topline + s), h),
            -- NOTE behavior is a bit unspecified, but this works for me so far
            col = view.col + view.coladd,
            coladd = 0,
        }
    end
end

local nv = require("mad-mappings").make_action_nv

return {
    cursor = {
        down = {
            plain = nv { "cursor down visual line", expr = down },
            fast = nv { "cursor down visual line and view if past half screen", expr = down_fast },
            adaptive = nv { "down or down_fast", expr = rapid(down, down_fast) },
        },
        up = {
            plain = nv { "cursor up visual line", expr = up },
            fast = nv { "cursor up visual line and view if past half screen", expr = up_fast },
            adaptive = nv { "up or up_fast", expr = rapid(up, up_fast) },
        },
        left = nv { "cursor left", rhs = "h" },
        right = nv { "cursor right", rhs = "l" },
        word_start = {
            previous = {
                small = nv { "previous word start", rhs = "b" },
                big = nv { "previous WORD start", rhs = "B" },
            },
            next = {
                small = nv { "next word start", rhs = "w" },
            },
        },
        word_end = {
            next = {
                small = nv { "next word end", rhs = "e" },
                big = nv { "next WORD end", rhs = "E" },
            },
            previous = {
                small = nv { "previous word end", rhs = "ge" },
            },
        },
        start_of_text = nv { "cursor to start of text, view to start of line", rhs = "0^" },
        start_of_line = nv { "cursor to start of line", rhs = "0" },
        end_of_line = nv { "cursor to end of line", rhs = "$" },
        page = {
            full = {
                up = nv { "view and cursor one page up", fn = page(-1) },
                down = nv { "view and cursor one page down", fn = page(1) },
            },
            half = {
                up = nv { "view and cursor one page up", fn = page(-0.5) },
                down = nv { "view and cursor one page down", fn = page(0.5) },
            },
        },
        first_line = nv { "cursor to first line", rhs = "gg" },
        first_character = nv { "cursor to first character in first line", rhs = "gg0" },
        last_line = nv { "cursor to last line", rhs = "G" },
        last_character = nv { "cursor to last character in last line", rhs = "G$" },
    },
    view = {
        down = nv { "view down", rhs = "1<c-e>" },
        up = nv { "view up", rhs = "1<c-y>" },
        left = nv { "view left", rhs = "z<left>" },
        right = nv { "view right", rhs = "z<right>" },
        centered = nv { "move view to have cursor centered vertically", rhs = "zz" },
        topped = nv { "move view to have cursor at the top", rhs = "zt" },
        bottomed = nv { "move view to have cursor at the bottom", rhs = "zb" },
    },
}

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

local function fast_down()
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

local function fast_up()
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

local nv = require("mad-mappings").make_action_nv

return {
    down = nv { "cursor down visual line", expr = down },
    fast_down = nv { "cursor and view down visual line", expr = fast_down },
    some_down = nv { "down or fast_down", expr = rapid(down, fast_down) },
    up = nv { "cursor up visual line", expr = up },
    fast_up = nv { "cursor and view up visual line", expr = fast_up },
    some_up = nv { "up or fast_up", expr = rapid(up, fast_up) },
}

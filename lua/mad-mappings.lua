local M = {} -- public interface
local P = {} -- private namespace

--- private ---------------------------------------------------

--- clear mappings
function P.clear()
    -- see :help default_mappings and other places
    -- currently just removing what i bumped into
    -- there was a way to clear all, including built-in I think

    -- NOTE difference between deleting a mapping and unsetting a default

    -- local del = vim.keymap.del
    -- del(n, "<c-w>d")
    -- del(n, "<c-w><c-d>")
    -- TODO damn ... because this happens after us? comes from matchit, a pack, but it's before the config path
    -- but we run init directly, so that happens before somehow?
    -- its a mess, plugins happen after my init ... so how can i undo things from them?
    -- how can i make my init run at the very end then?
    -- del(o, "[%") -- NOTE comes from "matchit"
    vim.cmd([[let loaded_matchit = 1]]) -- TODO as a hack now, still dont know how to not get overwritten by plugins

    -- TODO try generically to delete all
    -- and there is also nvim_buf_get_keymap ... how to make sure we always have a clean slate?
    vim.iter(vim.api.nvim_get_keymap("n")):each(function(map)
        vim.api.nvim_del_keymap("n", map.lhs)
        -- del(map.mode, map.lhs)
    end)

    -- TODO help index.txt has a list, but need to parse it, there is no api to get all of those
    local letters = [[abcdefghijklmnopqrstuvwxyz]]
    local n, v, o = "n", "v", "o"
    for at = 1, #letters do
        local char = string.sub(letters, at, at)
        vim.keymap.set(n, "<c-" .. char .. ">", "<nop>")
        vim.keymap.set(v, "<c-" .. char .. ">", "<nop>")
        vim.keymap.set(o, "<c-" .. char .. ">", "<nop>")
    end
    local keys = [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ&*()\%@;+![]|~":-={}$#_<>?']]
    for at = 1, #keys do
        local char = string.sub(keys, at, at)
        vim.keymap.set(n, char, "<nop>")
        vim.keymap.set(v, char, "<nop>")
        vim.keymap.set(o, char, "<nop>")
    end
end

---@param delay number milliseconds
---@param disengage number milliseconds
function P.rapid_trigger_context(delay, disengage)
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

local expr = {}

expr.rapid = P.rapid_trigger_context(50, 1000)

function expr.down()
    return "gj" -- treats wrapped lines as they appear
end

function expr.fast_down()
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

function expr.up()
    -- return "k"
    return "gk" -- treats wrapped lines as they appear
end

function expr.fast_up()
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

---@param mode string
---@param lhs string
---@param action Action
function P.apply_map(mode, lhs, action)
    if action.rhs then
        vim.keymap.set(mode, lhs, action.rhs, { desc = action.desc })
    elseif action.expr then
        vim.keymap.set(mode, lhs, action.expr, { desc = action.desc, expr = true })
    elseif action.fn then
        vim.keymap.set(mode, lhs, action.fn, { desc = action.desc })
    else
        assert(false)
    end
end

P.modes = {
    nv = "nv",
}

--- public interface ------------------------------------------

---@class (exact) Action
---@field modes "n" | "nv" supported modes
---@field desc string description
---@field rhs? string rhs, or it is a group with no functionality if nothing is mapped
---@field expr? fun() expression
---@field fn? fun() function
---@field context? string context after this

---@return Action
local function a(a)
    return {
        modes = a[1],
        desc = a[2],
        rhs = a.rhs,
        expr = a.expr,
        fn = a.fn,
        context = a.context,
    }
end

---@type table<string, Action>
M.actions = {
    down = a { P.modes.nv, "cursor down visual line", expr = expr.down },
    fast_down = a { P.modes.nv, "cursor and view down visual line", expr = expr.fast_down },
    some_down = a { P.modes.nv, "down or fast_down", expr = expr.rapid(expr.down, expr.fast_down) },
    up = a { P.modes.nv, "cursor up visual line", expr = expr.up },
    fast_up = a { P.modes.nv, "cursor and view up visual line", expr = expr.fast_up },
    some_up = a { P.modes.nv, "up or fast_up", expr = expr.rapid(P.up, P.fast_up) },
}

---maps go from context to mode to lhs to action
---@alias Maps table<string, table<string, table<string, Action>>>

---@param action? Action
---@param context string
---@return Action
function M.context(action, context)
    if action then
        action = vim.deepcopy(action)
    else
        action = a { P.modes.nv("context ") .. context }
    end
    action.context = context
    return action
end

-- local test = {
--     default = {
--         nv = {
--             sn = P.down,
--             si = P.up,
--             [" e"] = P.x,
--             vt = P.mode(P.ts_init, "treesitter"),
--             w = P.mode(nil, "window"),
--         },
--     },
--     treesitter = {
--         n = {},
--     },
--     window = {
--         u = P.next_window,
--         e = P.prev_window,
--     },
-- }

function M.setup() end

---@param maps Maps
---@param context string?
function M.apply(maps, context)
    maps = maps[context or "default"]
    vim.Iter(maps):each(function(modes, mmaps)
        vim.Iter(mmaps):each(function(lhs, action)
            vim.Iter(modes):each(function(mode)
                P.apply_map(mode, lhs, action)
            end)
        end)
    end)
end

return M

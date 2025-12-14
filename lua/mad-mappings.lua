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

---@param context string
function P.push_context(context)
    assert(P.maps.context)
    table.insert(P.contexts, context)
    -- TODO what about context info, like how to visualize it and all
    -- TODO we should also clear mappings
    -- TODO I think we also had an option that any non-context key would pop the context?
    P.flat_map_maps(P.maps, context, P.apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

function P.pop_context()
    assert(#P.contexts > 1)
    table.remove(P.contexts)
    P.flat_map_maps(P.maps, P.contexts[-1], P.apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

---@param context string
function P.switch_context(context)
    assert(P.maps.context)
    P.contexts[-1] = context
    P.flat_map_maps(P.maps, context, P.apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

---@param maps Maps
---@param context string? or "default"
---@param fn fun(mode: string, lhs: string, action: Action)
function P.flat_map_maps(maps, context, fn)
    maps = maps[context or "default"]
    vim.Iter(maps):each(function(modes, mmaps)
        vim.Iter(mmaps):each(function(lhs, action)
            vim.Iter(modes):each(function(mode)
                fn(mode, lhs, action)
            end)
        end)
    end)
end

---@param rhs string
---@param context string
---@return fun(): string
function P.expr_ctx_rhs(rhs, context)
    return function()
        -- TODO not always we want to switch before? in search it would be nice to do it differently
        P.push_context(context)
        return rhs
    end
end

---@param xpr fun(): string
---@param context string
---@return fun(): string
function P.expr_ctx_expr(xpr, context)
    return function()
        -- TODO lsp says nothing when those functions are missing, why?
        P.push_context(context)
        return xpr()
    end
end

---@param fn fun()
---@param context string
---@return fun()
function P.fn_ctx_fn(fn, context)
    return function()
        P.push_context(context)
        -- TODO why did we call fn after here?
        fn()
    end
end

---@param context string
---@return fun()
function P.fn_ctx(context)
    return function()
        P.push_context(context)
    end
end

---@param mode string
---@param lhs string
---@param action Action
function P.apply_map(mode, lhs, action)
    if action.context then
        if action.rhs then
            vim.keymap.set(mode, lhs, P.expr_ctx_rhs(action.rhs, action.context), { desc = action.desc, expr = true })
        elseif action.expr then
            vim.keymap.set(mode, lhs, P.expr_ctx_expr(action.expr, action.context), { desc = action.desc, expr = true })
        elseif action.fn then
            vim.keymap.set(mode, lhs, P.fn_ctx_fn(action.fn, action.context), { desc = action.desc })
        else
            vim.keymap.set(mode, lhs, P.fn_ctx(action.context), { desc = action.desc })
        end
    else
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
end

P.modes = {
    nv = "nv",
}

---@type Maps
P.maps = { default = {} }

---@type string[]
P.contexts = { "default" }

--- public interface ------------------------------------------

---either exactly one of rhs, expr, or fn
---or context and none or exactly one of rhs, expr, or fn
---@class (exact) Action
---@field modes "n" | "nv" supported modes
---@field desc string description
---@field rhs? string rhs, or it is a group with no functionality if nothing is mapped
---@field expr? fun() expression
---@field fn? fun() function
---@field context? string context after this

---@return Action
local function Action(args)
    -- TODO i dont understand why lsp complains here
    return {
        modes = args[1],
        desc = args[2],
        rhs = args.rhs,
        expr = args.expr,
        fn = args.fn,
        context = args.context,
    }
end

-- TODO wrap nicer (in exprs)
local layouts = require("lavish-layouts")

---@type table<string, Action>
M.actions = {
    down = Action { P.modes.nv, "cursor down visual line", expr = expr.down },
    fast_down = Action { P.modes.nv, "cursor and view down visual line", expr = expr.fast_down },
    some_down = Action { P.modes.nv, "down or fast_down", expr = expr.rapid(expr.down, expr.fast_down) },
    up = Action { P.modes.nv, "cursor up visual line", expr = expr.up },
    fast_up = Action { P.modes.nv, "cursor and view up visual line", expr = expr.fast_up },
    some_up = Action { P.modes.nv, "up or fast_up", expr = expr.rapid(P.up, P.fast_up) },
    -- windows
    new_window = Action { P.modes.n, "new window", expr = layouts.new_from_split },
    previous_widnow = Action { { P.modes.n, P.modes.windows }, "previous window", expr = layouts.previous },
    next_widnow = Action { { P.modes.n, P.modes.windows }, "next window", expr = layouts.next },
    focus_window = Action { P.modes.n, "focus window", expr = layouts.focus },
    only_window = Action { P.modes.n, "only window", expr = "<cmd>windcmt o<enter>" },
    close_window = Action { P.modes.n, "close window", expr = layouts.close_window },
    close_and_delete_window = Action { P.modes.n, "close and delete window", expr = layouts.close_and_delete },
    switch_main_layout = Action { P.modes.n, "windows main layout", expr = layouts.switch_main },
    switch_stacked_layout = Action { P.modes.n, "windows stacked layout", expr = layouts.switch_stacked },
}

---maps go from context to mode to lhs to action
---@alias Maps table<string, table<string, table<string, Action>>>

---@return Maps
function M.example_maps()
    return {
        default = {
            nv = {
                u = M.actions.some_up,
                e = M.actions.some_down,
            },
            n = {
                ww = M.actions.new_from_split,
                wu = M.context(M.actions.prev_window, "windows"),
                we = M.context(M.actions.next_window, "windows"),
                ["w."] = M.actions.only_window,
                ["w,"] = M.actions.close_window,
                wd = M.actions.close_and_delete_window,
                wm = M.actions.switch_main,
                ws = M.actions.switch_stacked,
            },
        },
        -- TODO somehow lsp is confused here, it doesnt complain that those actions dont exist
        -- and for the ones that do, it doesnt jump to them
        windows = {
            -- TODO this could I think also just be {}, no need for the key?
            -- [1] = { color = "yellow" },
            n = {
                u = M.actions.next_window,
                e = M.actions.prev_window,
                n = M.context(M.actions.focus, "default"),
                [","] = M.context(M.actions.close_window, "default"),
                d = M.actions.close_and_delete,
                w = M.context(M.actions.new_from_split, "default"),
            },
        },
    }
end

---@param action Action?
---@param context string
---@return Action
function M.context(action, context)
    if action then
        action = vim.deepcopy(action)
    else
        -- TODO without an action we dont know what modes to allow
        action = Action { P.modes.nv, "switch to context " .. context }
    end
    action.context = context
    return action
end

function M.setup() end

---@param maps Maps
function M.apply_maps(maps)
    P.maps = vim.deepcopy(maps)
    P.contexts = { "default" }
    P.flat_map_maps(maps, "default", P.apply_map)
end

return M

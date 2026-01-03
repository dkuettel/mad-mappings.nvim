---either exactly one of rhs, expr, or fn
---or context and none or exactly one of rhs, expr, or fn
---@class (exact) mad-mappings.Action
---@field modes "n" | "nv" supported modes
---@field desc string description
---@field rhs? string rhs, or it is a group with no functionality if nothing is mapped
---@field expr? fun() expression
---@field fn? fun() function
---@field context? string context after this

---@param action mad-mappings.Action
---@return mad-mappings.Action
local function validate_action(action)
    assert(type(action.modes) == "string")
    assert(type(action.desc) == "string")
    assert(type(action.rhs) == "string" and action.expr == nil and action.fn == nil)
    assert(action.rhs == nil and type(action.expr) == "function" and action.fn == nil)
    assert(action.rhs == nil and action.expr == nil and type(action.fn) == "function")
    assert(action.context == nil or type(action.context) == "string")
    return action
end

-- TODO literal table?
---@alias mad-mappings.Mode "n"|"nv"|"v"|"i"

---maps go from context to mode to lhs to action
---@alias mad-mappings.Maps table<string, table<mad-mappings.Mode, table<string, mad-mappings.Action>>>

local state = {
    ---@type mad-mappings.Maps
    maps = { default = {} },

    ---@type string[]
    contexts = { "default" },
}

--- clear "all" mappings (best effort)
local function clear()
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

---@param context string
local function push_context(context)
    assert(P.maps.context)
    table.insert(P.contexts, context)
    -- TODO what about context info, like how to visualize it and all
    -- TODO we should also clear mappings
    -- TODO I think we also had an option that any non-context key would pop the context?
    P.flat_map_maps(P.maps, context, P.apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

local function pop_context()
    assert(#state.contexts > 1)
    table.remove(state.contexts)
    P.flat_map_maps(state.maps, state.contexts[-1], apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

---@param context string
local function switch_context(context)
    assert(state.maps.context)
    state.contexts[-1] = context
    flat_map_maps(state.maps, context, apply_map)
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline { bang = true }
end

---@param maps mad-mappings.Maps
---@param context string? or "default"
---@param fn fun(mode: string, lhs: string, action: mad-mappings.Action)
local function flat_map_maps(maps, context, fn)
    maps = maps[context or "default"]
    vim.iter(maps):each(function(modes, mmaps)
        if modes == "fn" then
            mmaps()
        else
            vim.iter(mmaps):each(function(lhs, action)
                for i = 1, #modes do
                    local mode = modes:sub(i, i)
                    fn(mode, lhs, action)
                end
            end)
        end
    end)
end

---@param rhs string
---@param context string
---@return fun(): string
local function expr_ctx_rhs(rhs, context)
    return function()
        -- TODO not always we want to switch before? in search it would be nice to do it differently
        push_context(context)
        return rhs
    end
end

---@param xpr fun(): string
---@param context string
---@return fun(): string
local function expr_ctx_expr(xpr, context)
    return function()
        -- TODO lsp says nothing when those functions are missing, why?
        push_context(context)
        return xpr()
    end
end

---@param fn fun()
---@param context string
---@return fun()
local function fn_ctx_fn(fn, context)
    return function()
        push_context(context)
        -- TODO why did we call fn after here?
        fn()
    end
end

---@param context string
---@return fun()
local function fn_ctx(context)
    return function()
        push_context(context)
    end
end

---@param mode string
---@param lhs string
---@param action mad-mappings.Action
local function apply_map(mode, lhs, action)
    if action.context then
        if action.rhs then
            vim.keymap.set(mode, lhs, expr_ctx_rhs(action.rhs, action.context), { desc = action.desc, expr = true })
        elseif action.expr then
            vim.keymap.set(mode, lhs, expr_ctx_expr(action.expr, action.context), { desc = action.desc, expr = true })
        elseif action.fn then
            vim.keymap.set(mode, lhs, fn_ctx_fn(action.fn, action.context), { desc = action.desc })
        else
            vim.keymap.set(mode, lhs, fn_ctx(action.context), { desc = action.desc })
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

return {
    setup = function() end,

    ---@param maps mad-mappings.Maps
    apply_maps = function(maps)
        state.maps = vim.deepcopy(maps)
        state.contexts = { "default" }
        flat_map_maps(state.maps, "default", apply_map)
    end,

    actions = {
        context = {
            ---@param context string
            ---@param action? mad-mappings.Action
            ---@return mad-mappings.Action
            push = function(context, action)
                if action then
                    action = vim.deepcopy(validate_action(action))
                else
                    action = { modes = "nv", desc = "push context " .. context }
                end
                -- TODO in a way, .context could instead just be a .fn? after all pop is also like that?
                action.context = context
                return validate_action(action)
            end,
            -- TODO this actually should also take an action optionally
            pop = validate_action { modes = "nv", desc = "pop context", fn = pop_context },
        },
        -- TODO not sure, does this work? does it get types? is it recursive?
        plain = require("mad-mappings.actions.plain"),
        -- TODO window or windows? or layout(s)?
        windows = require("mad-mappings.actions.windows"),
    },

    ---@class (exact) mad-mappings.make_action
    ---@field [1] string
    ---@field [2] string
    ---@field rhs? string
    ---@field expr? fun():string
    ---@field fn? fun()
    ---@field context? string

    ---@param args mad-mappings.make_action
    ---@return mad-mappings.Action
    make_action = function(args)
        return validate_action {
            modes = args[1],
            desc = args[2],
            rhs = args.rhs,
            expr = args.expr,
            fn = args.fn,
            context = args.context,
        }
    end,

    ---@class (exact) mad-mappings.make_action_nv
    ---@field [1] string
    ---@field rhs? string
    ---@field expr? fun():string
    ---@field fn? fun()
    ---@field context? string

    ---@param args mad-mappings.make_action_nv
    ---@return mad-mappings.Action
    make_action_nv = function(args)
        return validate_action {
            modes = "nv",
            desc = args[1],
            rhs = args.rhs,
            expr = args.expr,
            fn = args.fn,
            context = args.context,
        }
    end,

    ---@class (exact) mad-mappings.make_action_v
    ---@field [1] string
    ---@field rhs? string
    ---@field expr? fun():string
    ---@field fn? fun()
    ---@field context? string

    ---@param args mad-mappings.make_action_nv
    ---@return mad-mappings.Action
    make_action_v = function(args)
        return validate_action {
            modes = "v",
            desc = args[1],
            rhs = args.rhs,
            expr = args.expr,
            fn = args.fn,
            context = args.context,
        }
    end,
}

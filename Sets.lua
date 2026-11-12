-- AddOn sets: named lists of addons to enable. Applying one enables its members,
-- disables every other addon ProfileSwap already knows, and leaves new addons alone.
local _, ns = ...

local function Character()
    return UnitGUID("player")
end

function ns.IsProtected(name)
    return name == ns.ADDON or name == "BetterAddonList"
end

function ns.InstalledAddons()
    local list = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title = C_AddOns.GetAddOnInfo(i)
        list[#list + 1] = { name = name, title = (title and title ~= "") and ns.StripColors(title) or name }
    end
    return list
end

function ns.AddonTitle(name)
    local _, title = C_AddOns.GetAddOnInfo(name)
    return (title and title ~= "") and ns.StripColors(title) or name
end

function ns.IsEnabled(name)
    return C_AddOns.GetAddOnEnableState(name, Character()) > 0
end

---------------------------------------------------------------------------
-- Known addons
---------------------------------------------------------------------------

function ns.SeedKnownAddons()
    local known = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        known[(C_AddOns.GetAddOnInfo(i))] = true
    end
    ns.DB().known = known
end

function ns.UnknownAddons()
    local list, known = {}, ns.DB().known or {}
    for _, a in ipairs(ns.InstalledAddons()) do
        if not known[a.name] and not ns.IsProtected(a.name) then list[#list + 1] = a end
    end
    return list
end

function ns.MarkKnown(name)
    ns.DB().known[name] = true
end

---------------------------------------------------------------------------
-- Groups: addons that belong together (an addon and its modules)
---------------------------------------------------------------------------

-- Returns the group key for an addon: its "Group" TOC field if readable,
-- otherwise its first installed required dependency, otherwise itself.
function ns.GroupKeyOf(name)
    local ok, group = pcall(C_AddOns.GetAddOnMetadata, name, "Group")
    if ok and group and group ~= "" then return group end
    for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do
        if C_AddOns.DoesAddOnExist == nil or C_AddOns.DoesAddOnExist(dep) then return dep end
    end
    return name
end

-- Returns { {key, title, members = {addon...}} ... } for groups of 2+, then "Other AddOns".
function ns.GroupAddons(addons)
    local byKey, order = {}, {}
    for _, a in ipairs(addons) do
        local key = ns.GroupKeyOf(a.name)
        if not byKey[key] then
            byKey[key] = { key = key, members = {} }
            order[#order + 1] = key
        end
        table.insert(byKey[key].members, a)
    end
    -- a parent addon joins the group named after it
    for _, a in ipairs(addons) do
        if byKey[a.name] and ns.GroupKeyOf(a.name) ~= a.name then
            local own = byKey[ns.GroupKeyOf(a.name)]
            for i, m in ipairs(own.members) do
                if m.name == a.name then table.remove(own.members, i) break end
            end
            table.insert(byKey[a.name].members, 1, a)
        end
    end
    local groups, other = {}, { key = "__other", title = "Other AddOns", members = {} }
    for _, key in ipairs(order) do
        local g = byKey[key]
        if #g.members >= 2 then
            local present = C_AddOns.DoesAddOnExist == nil or C_AddOns.DoesAddOnExist(key)
            g.title = present and ns.AddonTitle(key) or key
            groups[#groups + 1] = g
        else
            for _, m in ipairs(g.members) do table.insert(other.members, m) end
        end
    end
    table.sort(groups, function(a, b) return a.title:lower() < b.title:lower() end)
    table.sort(other.members, function(a, b) return a.title:lower() < b.title:lower() end)
    if #other.members > 0 then groups[#groups + 1] = other end
    return groups
end

---------------------------------------------------------------------------
-- Set CRUD
---------------------------------------------------------------------------

function ns.SortedSetNames()
    local list = {}
    for name in pairs(ns.DB().sets) do list[#list + 1] = name end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

-- New sets start from what is enabled right now.
function ns.CreateSet(name)
    local db = ns.DB()
    if db.sets[name] then
        ns.Print("An AddOn set named '" .. name .. "' already exists.")
        return false
    end
    local members = {}
    for _, a in ipairs(ns.InstalledAddons()) do
        if not ns.IsProtected(a.name) and ns.IsEnabled(a.name) then members[a.name] = true end
    end
    db.sets[name] = members
    ns.Changed()
    return true
end

function ns.SaveSet(name, members)
    local clean = {}
    for addon, on in pairs(members) do
        if on and not ns.IsProtected(addon) then clean[addon] = true end
    end
    ns.DB().sets[name] = clean
    ns.Changed()
end

function ns.RenameSet(old, new)
    local db = ns.DB()
    if not db.sets[old] or old == new then return false end
    if db.sets[new] then
        ns.Print("An AddOn set named '" .. new .. "' already exists.")
        return false
    end
    db.sets[new], db.sets[old] = db.sets[old], nil
    for _, p in pairs(db.profiles) do
        if p.addonSet == old then p.addonSet = new end
    end
    ns.Changed()
    return true
end

function ns.DeleteSet(name)
    local db = ns.DB()
    db.sets[name] = nil
    for _, p in pairs(db.profiles) do
        if p.addonSet == name then p.addonSet = nil end
    end
    ns.Changed()
end

---------------------------------------------------------------------------
-- Apply + reload tracking
---------------------------------------------------------------------------

local baseline -- enable states when the first change since the last reload was made

local function Snapshot()
    local states = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        states[name] = ns.IsEnabled(name)
    end
    return states
end

local function SameStates(a, b)
    for name, on in pairs(a) do
        if b[name] ~= on then return false end
    end
    for name in pairs(b) do
        if a[name] == nil then return false end
    end
    return true
end

local function NetChanges(base, after)
    local changes = {}
    for name, on in pairs(after) do
        if on ~= (base[name] or false) then
            changes[#changes + 1] = { name = name, title = ns.AddonTitle(name), enable = on }
        end
    end
    table.sort(changes, function(a, b)
        if a.enable ~= b.enable then return a.enable end
        return a.title:lower() < b.title:lower()
    end)
    return changes
end

function ns.ApplyAddonSet(profile, verbose)
    local setName = profile.addonSet
    local members = setName and ns.DB().sets[setName]
    if not members then return end
    local known = ns.DB().known
    local before = Snapshot()
    for name in pairs(before) do
        if ns.IsProtected(name) or members[name] then
            C_AddOns.EnableAddOn(name, Character())
        elseif known[name] then
            C_AddOns.DisableAddOn(name, Character())
        end
    end
    local after = Snapshot()
    if SameStates(before, after) then
        if verbose then ns.Print("AddOn set '" .. setName .. "' already matches.") end
        return
    end
    C_AddOns.SaveAddOns()
    baseline = baseline or before
    local changes = NetChanges(baseline, after)
    if #changes > 0 then
        ns.addonReload = { setName = setName, changes = changes }
        if verbose then ns.Print("AddOn set '" .. setName .. "' applied. Reload the UI to finish.") end
    else
        baseline, ns.addonReload = nil, nil
        if verbose then ns.Print("AddOns match what is loaded again.") end
    end
end

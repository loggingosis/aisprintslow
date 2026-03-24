local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function getCfg()
    -- Optional convars (override config.lua without editing files)
    local mv = GetConvar('ai_sprint_multiplier', tostring(Config.SprintMultiplier))
    local iv = GetConvarInt('ai_sprint_scan_interval', Config.ScanIntervalMs)
    local rv = GetConvar('ai_sprint_radius', tostring(Config.Radius))
    local mm = GetConvarInt('ai_sprint_include_mission', (Config.IncludeMissionPeds and 1 or 0))

    local mult = tonumber(mv) or Config.SprintMultiplier
    local interval = tonumber(iv) or Config.ScanIntervalMs
    local radius = tonumber(rv) or Config.Radius

    mult = clamp(mult, 0.50, 1.00)          -- keep sane
    interval = clamp(interval, 200, 5000)    -- keep sane
    radius = clamp(radius, 10.0, 250.0)      -- keep sane

    return {
        sprintMultiplier = mult,
        scanIntervalMs = interval,
        radius = radius,
        includeMissionPeds = (mm == 1)
    }
end

RegisterNetEvent('ai_sprint_slow:requestConfig', function()
    TriggerClientEvent('ai_sprint_slow:applyConfig', source, getCfg())
end)

AddEventHandler('playerJoining', function()
    local src = source
    TriggerClientEvent('ai_sprint_slow:applyConfig', src, getCfg())
end)

-- Optional admin command to push config to everyone after changing convars
RegisterCommand('ai_sprint_pushcfg', function(src)
    -- allow console (src==0) or in-game admin via ACE
    if src ~= 0 and not IsPlayerAceAllowed(src, 'ai_sprint_slow.admin') then
        return
    end
    TriggerClientEvent('ai_sprint_slow:applyConfig', -1, getCfg())
end, false)

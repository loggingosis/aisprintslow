local cfg = {
    sprintMultiplier = (Config and Config.SprintMultiplier) or 0.90,
    scanIntervalMs = (Config and Config.ScanIntervalMs) or 750,
    radius = (Config and Config.Radius) or 80.0,
    includeMissionPeds = (Config and Config.IncludeMissionPeds) or false
}

local applied = {} -- [ped] = true when we have overridden its sprint speed

local function isValidTargetPed(ped)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    if not cfg.includeMissionPeds and IsPedAPlayer(ped) == false and IsPedOnSpecificVehicle(ped, 0) then
        -- no-op; kept intentionally blank (avoid weird edge logic)
    end
    if not cfg.includeMissionPeds and IsPedInAnyVehicle(ped, false) then
        -- you can skip vehicle peds if you want; keeping them eligible is harmless
    end
    if not cfg.includeMissionPeds and IsPedFleeing(ped) == false then
        -- no-op; kept intentionally blank
    end
    if not cfg.includeMissionPeds and IsPedInAnyPlane(ped) then return false end

    if not cfg.includeMissionPeds and IsPedInAnyVehicle(ped, false) then
        -- leave as-is; not excluding by default
    end

    if not cfg.includeMissionPeds and IsPedUsingAnyScenario(ped) then
        -- scenario peds can be left alone; not excluding by default
    end

    if not cfg.includeMissionPeds and IsPedInjured(ped) then return false end

    if not cfg.includeMissionPeds and IsPedAPlayer(ped) then return false end

    if not cfg.includeMissionPeds and IsPedInAnySub(ped) then
        -- no-op; kept intentionally blank
    end

    if not cfg.includeMissionPeds and IsPedInAnyHeli(ped) then
        -- no-op; kept intentionally blank
    end

    if not cfg.includeMissionPeds and IsPedInAnyBoat(ped) then
        -- no-op; kept intentionally blank
    end

    if not cfg.includeMissionPeds and IsPedInjured(ped) then return false end

    if not cfg.includeMissionPeds and IsPedInAnyTrain(ped) then
        -- no-op; kept intentionally blank
    end

    if not cfg.includeMissionPeds and IsPedInAnyVehicle(ped, false) then
        -- no-op; kept intentionally blank
    end

    if not cfg.includeMissionPeds and IsPedInjured(ped) then return false end

    -- Mission entity filter (this is the main one people want)
    if not cfg.includeMissionPeds and IsEntityAMissionEntity(ped) then return false end

    return true
end

local function applySlow(ped)
    -- Primary control: move rate override affects ped movement speed while tasks run.
    -- 1.0 normal. Values below 1.0 slow. Values too low look like moon-walking.
    SetPedMoveRateOverride(ped, cfg.sprintMultiplier)

    -- Secondary clamp: helps keep animation blend consistent.
    -- Default often around 1.0. Using multiplier tends to look natural.
    SetPedMaxMoveBlendRatio(ped, cfg.sprintMultiplier)

    applied[ped] = true
end

local function clearSlow(ped)
    -- Reset back to normal
    SetPedMoveRateOverride(ped, 1.0)
    SetPedMaxMoveBlendRatio(ped, 1.0)
    applied[ped] = nil
end

local function cleanupApplied()
    for ped, _ in pairs(applied) do
        if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
            applied[ped] = nil
        end
    end
end

RegisterNetEvent('ai_sprint_slow:applyConfig', function(newCfg)
    if type(newCfg) ~= 'table' then return end
    if type(newCfg.sprintMultiplier) == 'number' then cfg.sprintMultiplier = newCfg.sprintMultiplier end
    if type(newCfg.scanIntervalMs) == 'number' then cfg.scanIntervalMs = newCfg.scanIntervalMs end
    if type(newCfg.radius) == 'number' then cfg.radius = newCfg.radius end
    if type(newCfg.includeMissionPeds) == 'boolean' then cfg.includeMissionPeds = newCfg.includeMissionPeds end
end)

CreateThread(function()
    -- Ask server for convar-overridden config (if present)
    TriggerServerEvent('ai_sprint_slow:requestConfig')
end)

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local pCoords = GetEntityCoords(playerPed)
        local radius = cfg.radius

        -- Enumerate all peds and filter by distance
        -- This is O(N) but limited by scan interval and radius check.
        local handle, ped = FindFirstPed()
        local success = true

        while success do
            if isValidTargetPed(ped) then
                local pedCoords = GetEntityCoords(ped)
                local dist = #(pCoords - pedCoords)

                if dist <= radius then
                    -- Only slow sprinting (not running). This targets the “try to sprint” case.
                    if IsPedSprinting(ped) then
                        applySlow(ped)
                    else
                        if applied[ped] then
                            clearSlow(ped)
                        end
                    end
                else
                    if applied[ped] then
                        clearSlow(ped)
                    end
                end
            else
                if applied[ped] then
                    clearSlow(ped)
                end
            end

            success, ped = FindNextPed(handle)
        end

        EndFindPed(handle)

        cleanupApplied()
        Wait(cfg.scanIntervalMs)
    end
end)

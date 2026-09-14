local QBCore = exports['qb-core']:GetCoreObject()
local uiOpen = false
local charCam = nil

-----------------------------------------------------------------------------
-- تجميد اللاعب أثناء عرض واجهة تسجيل الدخول (الشخصية تبقى ظاهرة أمام الكاميرا)
-----------------------------------------------------------------------------
local function SetPlayerFrozen(freeze)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, freeze)
    SetEntityInvincible(ped, freeze)
    SetPlayerControl(PlayerId(), not freeze, 0)
    DisplayRadar(not freeze)
    DisplayHud(not freeze)
end

-----------------------------------------------------------------------------
-- كاميرا ثابتة تركز على الشخصية (نفس فكرة شاشات اختيار الشخصية)
-----------------------------------------------------------------------------
local function CreateCharCam()
    local ped = PlayerPedId()
    SetEntityHeading(ped, Config.HiddenCoords.w or 0.0)

    local camCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.4, 0.05)

    charCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(charCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(charCam, ped, 0.0, 0.0, 0.45, true)
    SetCamFov(charCam, 42.0)
    SetCamActive(charCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function DestroyCharCam()
    if charCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(charCam, false)
        charCam = nil
    end
end

-----------------------------------------------------------------------------
-- بداية تشغيل المورد: نجمد اللاعب بمكان مخصص، نفعّل الكاميرا، ونطلب بياناته
-----------------------------------------------------------------------------
CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(50)
    end

    DoScreenFadeOut(0)
    Wait(300)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z, false, false, false)
    SetPlayerFrozen(true)
    CreateCharCam()

    Wait(300)
    DoScreenFadeIn(500)

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })

    TriggerServerEvent('Nabd-multichar:server:requestCharacter')
end)

-----------------------------------------------------------------------------
-- استقبال بيانات الشخصية (موجودة أو جديدة) وعرضها بالواجهة
-----------------------------------------------------------------------------
RegisterNetEvent('Nabd-multichar:client:setCharacterData', function(data, isNew)
    SendNUIMessage({
        action   = 'setCharacter',
        charinfo = data.charinfo,
        stats    = data.stats,
        isNew    = isNew,
    })
end)

-----------------------------------------------------------------------------
-- ضغط زر "ابدأ" من الواجهة
-----------------------------------------------------------------------------
RegisterNUICallback('start', function(_, cb)
    TriggerServerEvent('Nabd-multichar:server:startCharacter')
    cb('ok')
end)

-----------------------------------------------------------------------------
-- بعد ما السيرفر يسجل دخول الشخصية فعلياً: نسكّر الواجهة ونسبون اللاعب
-----------------------------------------------------------------------------
RegisterNetEvent('Nabd-multichar:client:spawn', function(spawnCoords)
    DoScreenFadeOut(300)
    Wait(400)

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    uiOpen = false

    DestroyCharCam()

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    if spawnCoords.w then
        SetEntityHeading(ped, spawnCoords.w)
    end

    SetPlayerFrozen(false)

    Wait(300)
    DoScreenFadeIn(500)
end)

-----------------------------------------------------------------------------
-- تعطيل بعض التحكمات وإخفاء الهود أثناء عرض الواجهة فقط
-----------------------------------------------------------------------------
CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 1, true)   -- LookLeftRight
            DisableControlAction(0, 2, true)   -- LookUpDown
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 257, true) -- AttackAlternate
            DisableControlAction(0, 288, true) -- Phone
            DisableControlAction(0, 289, true) -- Phone
            HideHudAndRadarThisFrame()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

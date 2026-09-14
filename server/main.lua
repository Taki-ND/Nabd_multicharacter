local QBCore = exports['qb-core']:GetCoreObject()

-- يخزن مؤقتاً بيانات الشخصية "المعلّقة" لحين ما يضغط اللاعب زر "ابدأ"
-- هذا الجدول موجود بالسيرفر فقط، اللاعب ما يقدر يتلاعب فيه من الكلايند
local pendingCharacters = {}

-----------------------------------------------------------------------------
-- جلب اسم الديسكورد عبر بوت الديسكورد (مع Fallback لاسم اللاعب بالسيرفر)
-----------------------------------------------------------------------------
local function GetDiscordName(src, cb)
    if not Config.DiscordName.Enabled or not Config.DiscordName.BotToken or Config.DiscordName.BotToken == '' then
        cb(GetPlayerName(src))
        return
    end

    local discordId = QBCore.Functions.GetIdentifier(src, 'discord')
    if not discordId then
        cb(GetPlayerName(src))
        return
    end

    discordId = discordId:gsub('discord:', '')

    PerformHttpRequest('https://discord.com/api/v10/users/' .. discordId, function(errCode, resultData)
        local finalName = GetPlayerName(src)

        if errCode == 200 and resultData then
            local ok, data = pcall(json.decode, resultData)
            if ok and data then
                local name = data.global_name or data.username
                if name and name ~= '' then
                    finalName = name
                end
            end
        elseif not Config.DiscordName.FallbackToGameName then
            finalName = 'لاعب'
        end

        cb(finalName)
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. Config.DiscordName.BotToken,
        ['Content-Type']  = 'application/json',
    })
end

-----------------------------------------------------------------------------
-- التحقق هل عند هذا الـ license شخصية موجودة مسبقاً
-----------------------------------------------------------------------------
local function GetExistingCharacter(license, cb)
    exports.oxmysql:fetch('SELECT citizenid, charinfo FROM players WHERE license = ? LIMIT 1', { license }, function(result)
        if result and result[1] then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end

-----------------------------------------------------------------------------
-- جلب القتلات/الوفيات (اختياري)، وإذا مو مفعّل أو ما فيه سجل يرجع 0/0
-----------------------------------------------------------------------------
local function GetStats(citizenid, cb)
    if not Config.Stats.Enabled or not citizenid then
        cb({ kills = 0, deaths = 0 })
        return
    end

    local query = ('SELECT `%s` as kills, `%s` as deaths FROM `%s` WHERE `%s` = ? LIMIT 1'):format(
        Config.Stats.KillsColumn, Config.Stats.DeathsColumn, Config.Stats.Table, Config.Stats.CitizenIdColumn
    )

    local ok = pcall(function()
        exports.oxmysql:fetch(query, { citizenid }, function(result)
            if result and result[1] then
                cb({
                    kills  = tonumber(result[1].kills) or 0,
                    deaths = tonumber(result[1].deaths) or 0,
                })
            else
                cb({ kills = 0, deaths = 0 })
            end
        end)
    end)

    if not ok then
        cb({ kills = 0, deaths = 0 })
    end
end

-----------------------------------------------------------------------------
-- الطلب الأول من الكلايند: يحدد هل نعرض "ترحيب عودة" أو "إنشاء شخصية جديدة"
-----------------------------------------------------------------------------
RegisterNetEvent('Nabd-multichar:server:requestCharacter', function()
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')

    if not license then
        DropPlayer(src, Config.NoLicenseKickMessage)
        return
    end

    GetExistingCharacter(license, function(existing)
        if existing then
            local charinfo = existing.charinfo
            if type(charinfo) == 'string' then
                local ok, decoded = pcall(json.decode, charinfo)
                charinfo = ok and decoded or {}
            end

            pendingCharacters[src] = {
                isNew     = false,
                citizenid = existing.citizenid,
            }

            GetStats(existing.citizenid, function(stats)
                TriggerClientEvent('Nabd-multichar:client:setCharacterData', src, {
                    charinfo = charinfo,
                    stats    = stats,
                }, false)
            end)
        else
            GetDiscordName(src, function(discordName)
                local charinfo = {
                    firstname   = discordName,
                    lastname    = Config.DefaultCharInfo.lastname,
                    birthdate   = Config.DefaultCharInfo.birthdate,
                    gender      = Config.DefaultCharInfo.gender,
                    nationality = Config.DefaultCharInfo.nationality,
                }

                pendingCharacters[src] = {
                    isNew    = true,
                    charinfo = charinfo,
                }

                TriggerClientEvent('Nabd-multichar:client:setCharacterData', src, {
                    charinfo = charinfo,
                    stats    = { kills = 0, deaths = 0 },
                }, true)
            end)
        end
    end)
end)

-----------------------------------------------------------------------------
-- ضغط زر "ابدأ": يسجل دخول اللاعب فعلياً (شخصية جديدة أو موجودة)
-- ملاحظة أمنية: هذا الحدث ما يستقبل أي بيانات من الكلايند، كل شي يعتمد
-- على pendingCharacters[src] اللي السيرفر بنى محتواه بنفسه
-----------------------------------------------------------------------------
RegisterNetEvent('Nabd-multichar:server:startCharacter', function()
    local src = source
    local pending = pendingCharacters[src]

    if not pending then
        DropPlayer(src, Config.LoginErrorKickMessage)
        return
    end

    local success
    if pending.isNew then
        local newData = {}
        newData.cid      = 1
        newData.charinfo = pending.charinfo
        success = QBCore.Player.Login(src, false, newData)
    else
        success = QBCore.Player.Login(src, pending.citizenid)
    end

    if not success then
        DropPlayer(src, Config.LoginErrorKickMessage)
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        pendingCharacters[src] = nil
        return
    end

    QBCore.Commands.Refresh(src)

    if pending.isNew and Config.EnableStarterItems and Config.StarterItems and #Config.StarterItems > 0 then
        for _, item in ipairs(Config.StarterItems) do
            Player.Functions.AddItem(item.name, item.amount)
        end
    end

    if pending.isNew and Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            embeds = {
                {
                    title       = '👤 شخصية جديدة - Nabd-Multicharacter',
                    description = string.format(
                        'اللاعب **%s** أنشأ شخصية جديدة باسم **%s %s**\nCitizenID: `%s`',
                        GetPlayerName(src),
                        Player.PlayerData.charinfo.firstname,
                        Player.PlayerData.charinfo.lastname,
                        Player.PlayerData.citizenid
                    ),
                    color = 10038562,
                },
            },
        }), { ['Content-Type'] = 'application/json' })
    end

    TriggerClientEvent('Nabd-multichar:client:spawn', src, Config.DefaultSpawn)

    pendingCharacters[src] = nil
end)

-----------------------------------------------------------------------------
-- تنظيف عند خروج اللاعب قبل ما يضغط "ابدأ"
-----------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    pendingCharacters[source] = nil
end)

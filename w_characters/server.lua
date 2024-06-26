
local SelectedCharacters = {}
local currentSSN = 0

local function GetIdentifier(source)
    for k,v in ipairs(GetPlayerIdentifiers(source)) do
        if string.match(v, 'license:') then
            return string.sub(v, 9)
        end
    end
end

local function DataBaseExecute(query)
    local IsBusy = true
    local result = nil
    MySQL.Async.fetchAll(query, {}, function(data)
        result = data
        IsBusy = false
    end)
    while IsBusy do
        Citizen.Wait(0)
    end
    return result
end

function isSSNUnique(ssn)
    local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE ssn = @ssn", {['@ssn'] = ssn})
    return result == nil or #result == 0 
end

function generateAndSaveSSN()
    currentSSN = currentSSN + 1
    local ssn = currentSSN
    if isSSNUnique(ssn) then
        return ssn
    else
        return generateAndSaveSSN()
    end
end

ESX.RegisterServerCallback('w_characters:SetupCharacters', function(source, cb)
    local identifier = GetIdentifier(source)
    local limit = DataBaseExecute("SELECT * FROM `user_lastcharacter` WHERE license = '"..identifier.."'")
    if limit[1] == nil then
        DataBaseExecute("INSERT INTO `user_lastcharacter` (`license`, `charid`, `limit`) VALUES ('"..identifier.."', '1', '1')")
        limit = 1
    else
        limit = tonumber(limit[1].limit)
    end
    
    MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier LIKE @identifier', {
        ['@identifier'] = '%' .. identifier
    }, function(result)
        local PlayerCharacters = {}
        local limit = limit 

        if result[1] ~= nil then
            for _, data in ipairs(result) do
                local character = {
                    charinfo = json.encode({ firstname = data.firstname, lastname = data.lastname }),
                    accounts = data.accounts,
                    job = data.job,
                    hiddenjob = data.hiddenjob,
                    lastPlayed = os.date("%Y-%m-%d %H:%M:%S", data.last_seen),
                    playedTime = 0, 
                    ssn = data.ssn
                }
                table.insert(PlayerCharacters, character)
            end
        end

        cb(PlayerCharacters, limit)
    end)
end)


-- AddEventHandler('esx:playerLoaded', function(playerId)
--     local xPlayer = ESX.GetPlayerFromId(playerId)
--     local result = MySQL.prepare.await('SELECT skin FROM users WHERE identifier = ?', {xPlayer.identifier})
--     xPlayer.set("skin", result.skin)
--     xPlayer.set("ped", result.ped)
-- end)


ESX.RegisterServerCallback("w_characters:GetSkin", function(source, cb, ssn)
    local _source = source
    local result = DataBaseExecute("SELECT skin FROM `users` WHERE ssn = '"..ssn.."'")
    if result and result[1] then
        if result[1].skin ~= nil then
            cb(json.decode(result[1].skin))
        else
            cb(nil)
        end
    else
        cb(nil)
    end
end)


local PREFIX = "char"

RegisterNetEvent("w_characters:SelectCharacter")
AddEventHandler("w_characters:SelectCharacter", function(ssn, data, character)
    local _source = source
    local identifier = GetIdentifier(_source)
    local charid = data.charid
    local identifier = PREFIX .. charid .. ":" .. GetIdentifier(source)

    if data.firstname and data.lastname then
        MySQL.Async.execute("INSERT INTO users (identifier, firstname, lastname, dateofbirth, sex, ssn, nationality) VALUES  (@identifier, @firstname, @lastname, @dateofbirth, @sex, @ssn, @nationality)", {
            ['@identifier'] = identifier,
            ['@firstname'] = data.firstname,
            ['@lastname'] = data.lastname,
            ['@dateofbirth'] = data.dateofbirth,
            ['@sex'] = data.sex,
            ['@ssn'] = generateAndSaveSSN(),
            ['@nationality'] = data.nationality,
        }, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent("esx_skin:openSaveableMenu", _source)
                --------------tu mozna dac wlasny skin jak ktos ma --------------
                TriggerEvent("esx:onPlayerJoined", _source, PREFIX .. charid)
                ESX.Players[GetIdentifier(_source)] = true
            else
                DropPlayer(_source, "odjebalo sie i sie nie da zrobic ")
            end
        end)
    else
        if ESX.GetPlayerFromIdentifier(identifier) then
            DropPlayer(source, "Your identifier " .. identifier .. " is already on the server!")
            return
        end
        TriggerEvent("esx:onPlayerJoined", source, PREFIX .. charid)
        ESX.Players[GetIdentifier(source)] = true
    end
end)

RegisterServerEvent('w_characters:BucketState')
AddEventHandler('w_characters:BucketState', function(state)
    local _source = source
    SetPlayerRoutingBucket(_source, state and 1 or 0)
end)




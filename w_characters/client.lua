local _Cam, CharPeds, CreatedProps, PlayerCharacters = nil, {}, {}, {}
local JavaScriptLoaded = false
local activeCamera = nil
local CanScrollCamera = true

CreateThread(function()
	while true do
		if NetworkIsPlayerActive(PlayerId()) then
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            TriggerEvent('esx:loadingScreenOff')
            Citizen.Wait(200)
			DoScreenFadeOut(0)
			SetupCharacters()
			break
		end
		Citizen.Wait(0)
	end
end)

RegisterNUICallback('SelectCharacter', function(data)
    if data.changingdata then
        TriggerServerEvent('w_characters:UpdateData', data)
        SetNuiFocus(false, false)
    else
        DoScreenFadeOut(0)
        SetNuiFocus(false, false)
        local a, b, c = 770.74749755859, 1295.2598876953, 361.85641479492
        RequestCollisionAtCoord(a, b, c)
        Wait(1000)
        SetEntityCoords(PlayerPedId(), a, b, c)
        if data.firstname and data.lastname then
            data.firstname = TransformFirstToUpper(data.firstname)
            data.lastname = TransformFirstToUpper(data.lastname)
        end
        local CharacterData = FindCharacterByID(data.charid)
        local ssn = CharacterData and CharacterData.ssn or nil
        for _, ped in pairs(CharPeds) do
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
        CameraState(false)
        TriggerServerEvent('w_characters:SelectCharacter', ssn, data, data.charid)
    end
end)

SetupCharacters = function()
    TriggerServerEvent('w_characters:BucketState', true)
	DisplayRadar(false)
	CameraState(true)
	FreezeEntityPosition(PlayerPedId(), true)
    SetEntityVisible(PlayerPedId(), false)
    RequestCollisionAtCoord(Config.HiddenCoords[1], Config.HiddenCoords[2], Config.HiddenCoords[3])
    SetEntityCoords(PlayerPedId(), Config.HiddenCoords[1], Config.HiddenCoords[2], Config.HiddenCoords[3])
	ESX.TriggerServerCallback('w_characters:SetupCharacters', function(characters, limit)
        PlayerCharacters = characters
        SetNuiFocus(true, true)
        Wait(1000)
        DoScreenFadeIn(1000)
        while not JavaScriptLoaded do
			print('Oczekiwanie na załadowanie JavaScript')
			SendNUIMessage({
				action = 'isLoaded'
			})
			Citizen.Wait(1000)
		end
        local model = 'mp_m_freemode_01'
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end
        local LoadingPed = CreatePed(2, model, Config.PedCreate[1], Config.PedCreate[2], Config.PedCreate[3], Config.PedCreate[4], false, true)
        while not DoesEntityExist(LoadingPed) do
            Wait(0)
        end
        DeletePed(LoadingPed)
        SpawnPreviewPeds(limit)
		SendNUIMessage({
			action = 'show',
			data = {
				limit = limit,
				characters = PlayerCharacters
			}
		})
	end)
end

FindCharacterByID = function(index)
    for k, v in pairs(PlayerCharacters) do
        if tostring(k) == tostring(index) then
            return v
        end
    end
    return nil
end

SpawnPreviewPeds = function(limit)
    for i = #Config.Peds, 1, -1 do
        local v = Config.Peds[i]
        local index = tostring(v.index)
        print(index)
        local FoundedCharacter = FindCharacterByID(v.index)
        local ssn = FoundedCharacter and FoundedCharacter.ssn or nil
        if ssn ~= nil then
            CreateThread(function()
                ESX.TriggerServerCallback('w_characters:GetSkin', function(skin)
                    print(json.encode(skin))
                    local model = 'mp_m_freemode_01'
                    if skin == nil then
                        model = (skin.sex == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01')
                    end
                    RequestModel(model)
                    while not HasModelLoaded(model) do
                        Wait(0)
                    end
                    CharPeds[index] = CreatePed(2, model, Config.PedCreate[1], Config.PedCreate[2], Config.PedCreate[3], Config.PedCreate[4], false, true)
                    SetPedComponentVariation(CharPeds[index], 0, 0, 0, 2)
                    FreezeEntityPosition(CharPeds[index], false)
                    SetEntityInvincible(CharPeds[index], true)
                    SetBlockingOfNonTemporaryEvents(CharPeds[index], true)
                    if skin ~= nil then
                        TriggerEvent('skinchanger:loadPedSkin', CharPeds[index], skin)
                    end
                    TaskGoStraightToCoord(CharPeds[index], v.coords[1], v.coords[2], v.coords[3], 0.2, -1, v.coords[4], 0.0)
                end, ssn)
            end)
        else
            CreateThread(function()
                local model = 'mp_m_freemode_01'
                RequestModel(model)
                while not HasModelLoaded(model) do
                    Wait(0)
                end
                CharPeds[index] = CreatePed(2, model, Config.PedCreate[1], Config.PedCreate[2], Config.PedCreate[3], Config.PedCreate[4], false, true)
                SetPedComponentVariation(CharPeds[index], 0, 0, 0, 2)
                FreezeEntityPosition(CharPeds[index], false)
                SetEntityInvincible(CharPeds[index], true)
                SetBlockingOfNonTemporaryEvents(CharPeds[index], true)
                TaskGoStraightToCoord(CharPeds[index], v.coords[1], v.coords[2], v.coords[3], 0.2, -1, v.coords[4], 0.0)
                SetEntityAlpha(CharPeds[index], (limit >= v.index and 204 or 51), false)
            end)
        end
        Wait(1000)
    end
end

CameraState = function(bool)
    if bool then
        FreezeEntityPosition(PlayerPedId(), false)
        local v = Config.Camera
        _Cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', v.coords.x, v.coords.y, v.coords.z, v.rot.x, v.rot.y, v.rot.z, 50.00, false, 0)
        SetCamActive(_Cam, true)
        RenderScriptCams(true, false, 1000, true, false)
    else
        SetCamActive(_Cam, false)
        DestroyCam(_Cam, true)
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
        _Cam = nil
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
		for _, ped in pairs(CharPeds) do
			DeletePed(ped)
		end
		for _, prop in pairs(CreatedProps) do
			DeleteEntity(prop)
		end
    end
end)

TransformFirstToUpper = function(value)
    return value:sub(1, 1):upper()..value:sub(2):lower()
end

RegisterNuiCallback('jsLoaded', function(data, cb)
    JavaScriptLoaded = true
end)

exports('ChangeData', function()
   ESX.TriggerServerCallback('w_characters:GetData', function(cb)
        if not cb then return end
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'ChangeData',
            data = cb
        })
   end)
end)

exports('Welcome', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OpenInformations',
        config = Config.Informations
    })
end)

exports('SpawnSelector', function()
    local _data = ESX.GetConfig().StartData
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'OpenSpawnSelector',
        spawns = _data.Spawns,
        vehicles = _data.Vehicles
    })
end)

RegisterNuiCallback('Selected', function()
	SetNuiFocus(false, false)
end)

RegisterNuiCallback('Close', function()
    SetNuiFocus(false, false)
end)
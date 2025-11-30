local isMenuOpen = false
local camera = nil
local locale = Config.Locale
local isInNativeMenu = false -- Track if we're in GTA native menus

-- Cache natives for performance
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetPedBoneCoords = GetPedBoneCoords
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetEntityModel = GetEntityModel
local GetModelDimensions = GetModelDimensions
local AttachCamToEntity = AttachCamToEntity
local PointCamAtCoord = PointCamAtCoord
local GetScreenCoordFromWorldCoord = GetScreenCoordFromWorldCoord
local SendNUIMessage = SendNUIMessage
local DoesEntityExist = DoesEntityExist
local CreateCam = CreateCam
local SetCamFov = SetCamFov
local SetCamActive = SetCamActive
local RenderScriptCams = RenderScriptCams
local DestroyCam = DestroyCam
local DoesCamExist = DoesCamExist
local SetNuiFocus = SetNuiFocus
local FreezeEntityPosition = FreezeEntityPosition
local DisableControlAction = DisableControlAction
local SetPauseMenuActive = SetPauseMenuActive
local IsPauseMenuActive = IsPauseMenuActive
local IsControlJustPressed = IsControlJustPressed
local Wait = Wait

-- Camera update function
local function UpdateCameraPosition()
    if not camera or not DoesCamExist(camera) then return end
    
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    
    local coords = GetEntityCoords(ped)
    local boneCoords = GetPedBoneCoords(ped, 60309, -0.6, 0.0, 0.0)
    
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            local vehicleCoords = GetEntityCoords(vehicle)
            local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
            local vehicleLength = maxDim.y - minDim.y
            local cameraOffset = vehicleLength * 0.6
            AttachCamToEntity(camera, vehicle, Config.CamRot.x - 1.0, cameraOffset, Config.CamRot.z + 0.2, true)
            PointCamAtCoord(camera, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z)
        end
    else
        AttachCamToEntity(camera, ped, Config.CamRot.x, Config.CamRot.y, Config.CamRot.z, true)
        PointCamAtCoord(camera, coords.x, coords.y, coords.z)
    end
    
    -- Update UI position
    local isOnScreen, screenX, screenY = GetScreenCoordFromWorldCoord(boneCoords.x, boneCoords.y, boneCoords.z)
    if isOnScreen then
        SendNUIMessage({
            type = "updatePosition",
            x = screenX,
            y = screenY
        })
    end
end

-- Create camera with depth of field
local function CreateMenuCamera()
    camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(camera, Config.CamFov)
    SetCamUseShallowDofMode(camera, true)
    SetCamNearDof(camera, 0.1)
    SetCamFarDof(camera, 5.0)
    SetCamDofStrength(camera, 1.0)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, Config.EaseTime, true, true)
end

-- Get player name with fallback
local function GetPlayerDisplayName()
    local success, result = pcall(function()
        if exports and exports["dn-pausemenu-main"] and exports["dn-pausemenu-main"].getPlayerName then
            return exports["dn-pausemenu-main"]:getPlayerName()
        end
    end)
    
    if success and result and type(result) == "string" and result ~= "" then
        return result
    end
    
    return GetPlayerName(PlayerId())
end

-- Open pause menu
local function OpenPauseMenu()
    if isMenuOpen then return end
    
    isMenuOpen = true
    local playerName = GetPlayerDisplayName()
    
    -- Freeze player
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- Create camera
    CreateMenuCamera()
    
    -- Enable NUI
    SetNuiFocus(true, true)
    
    -- Wait for camera transition
    Wait(Config.EaseTime)
    
    -- Get initial position
    local boneCoords = GetPedBoneCoords(PlayerPedId(), 60309, -0.6, 0.0, 0.0)
    local isOnScreen, screenX, screenY = GetScreenCoordFromWorldCoord(boneCoords.x, boneCoords.y, boneCoords.z)
    
    -- Send open message to NUI
    SendNUIMessage({
        type = "openMenu",
        x = screenX,
        y = screenY,
        locale = locale,
        name = playerName
    })
end

-- Close pause menu
local function ClosePauseMenu()
    if not isMenuOpen then return end
    
    isMenuOpen = false
    
    -- Destroy camera
    if camera and DoesCamExist(camera) then
        DestroyCam(camera, false)
        camera = nil
    end
    
    -- Unfreeze player
    FreezeEntityPosition(PlayerPedId(), false)
    
    -- Disable NUI
    SetNuiFocus(false, false)
    
    -- Restore normal camera
    RenderScriptCams(false, true, Config.EaseTime, true, true)
    
    -- Send close message to NUI
    SendNUIMessage({
        type = "closeMenu"
    })
end

-- Camera update thread
CreateThread(function()
    while true do
        if isMenuOpen and camera then
            UpdateCameraPosition()
            SetUseHiDof()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- Control disable thread
CreateThread(function()
    while true do
        if isMenuOpen then
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 199, true) -- P
            DisableControlAction(0, 1, true)   -- Camera controls
            DisableControlAction(0, 2, true)   -- Camera controls
            SetPauseMenuActive(false)
            Wait(0)
        elseif not isInNativeMenu then
            -- Only block default pause menu when NOT in native menus
            if IsPauseMenuActive() then
                SetPauseMenuActive(false)
            end
            Wait(100)
        else
            Wait(250)
        end
    end
end)

-- Main input thread
CreateThread(function()
    DisableIdleCamera(true)
    
    while true do
        Wait(0)
        
        if IsControlJustPressed(0, 200) then -- ESC
            if not isMenuOpen and not isInNativeMenu and not IsPauseMenuActive() then
                OpenPauseMenu()
            end
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('continue', function(data, cb)
    ClosePauseMenu()
    cb('ok')
end)

RegisterNUICallback('map', function(data, cb)
    ClosePauseMenu()
    cb('ok')
    
    isInNativeMenu = true
    
    Wait(500)
    
    -- Open the map menu
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'), false, -1)
    
    Wait(100)
    
    -- Navigate to the map tab
    PauseMenuceptionGoDeeper(0)
    
    -- Monitor when player exits the native menu
    CreateThread(function()
        while isInNativeMenu do
            Wait(100)
            if not IsPauseMenuActive() then
                isInNativeMenu = false
                break
            end
        end
    end)
end)

RegisterNUICallback('settings', function(data, cb)
    ClosePauseMenu()
    cb('ok')
    
    isInNativeMenu = true
    
    Wait(500)
    
    -- Open the settings menu
    ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_LANDING_MENU'), false, -1)
    
    -- Monitor when player exits the native menu
    CreateThread(function()
        while isInNativeMenu do
            Wait(100)
            if not IsPauseMenuActive() then
                isInNativeMenu = false
                break
            end
        end
    end)
end)

RegisterNUICallback('logout', function(data, cb)
    TriggerServerEvent('futr-pausemenu:logout')
    cb('ok')
end)

-- Fix menu command
RegisterCommand(Config.FixMenuCommand, function()
    ClosePauseMenu()
end)

-- Export function
local function IsMenuActive()
    return isMenuOpen or IsPauseMenuActive()
end

exports('IsInPause', IsMenuActive)
exports('IsMenuOpen', IsMenuActive)
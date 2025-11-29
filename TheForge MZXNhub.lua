--[[
    ╔═══════════════════════════════════════════════════════════╗
    ║   MZXN Hub for The Forge - TRANSPARENT GLASS EDITION    ║
    ║   Status: 100% Original Logic + PVB Systems + Glass UI  ║
    ║   Creator: @mzxn_xd                                     ║
    ╚═══════════════════════════════════════════════════════════╝
]]

local FORGE_GAME_ID = 7671049560
if game.GameId ~= FORGE_GAME_ID then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Wrong Game!"; Text = "This script only works in The Forge"; Duration = 5;
    })
    return
end

repeat task.wait() until game:IsLoaded()
if setfpscap then setfpscap(1000000) end

-- --- LIBRERÍAS Y SERVICIOS ---
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local NetworkClient = game:GetService("NetworkClient")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local CONFIG_FOLDER = "MZXNHubForge"
local SETTINGS_FILE = CONFIG_FOLDER .. "/Forge_SystemSettings.json"

-- --- REMOTOS ---
local KnitServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local function GetServiceRemote(serviceName, remoteType, remoteName)
    local success, result = pcall(function() return KnitServices:WaitForChild(serviceName):WaitForChild("RF"):WaitForChild(remoteName) end)
    return success and result or nil
end

local Remotes = {
    RedeemCode = GetServiceRemote("CodeService", "RF", "RedeemCode"),
    ToolActivated = GetServiceRemote("ToolService", "RF", "ToolActivated"),
    StartBlock = GetServiceRemote("ToolService", "RF", "StartBlock"),
    StopBlock = GetServiceRemote("ToolService", "RF", "StopBlock"),
    Run = GetServiceRemote("CharacterService", "RF", "Run"),
    ChangeSequence = GetServiceRemote("ForgeService", "RF", "ChangeSequence"),
    StartForge = GetServiceRemote("ForgeService", "RF", "StartForge"),
    Forge = GetServiceRemote("ProximityService", "RF", "Forge"),
}

-- --- CONFIGURACIÓN ---
local defaultConfig = {
    AutoMine = false, MineTarget = "Pebble",
    AutoAttack = false, AttackTargets = {}, 
    AutoParry = false, AutoRun = false, InfiniteFly = false, ClickTeleport = false,
    ForgeItemType = "Weapon", theme = "Dark",
    antiAFKEnabled = false, autoReconnectEnabled = false
}
local defaultSettings = { autoLoadConfig = "None", autoLoadEnabled = false }

local currentConfig = table.clone(defaultConfig)
local currentSettings = table.clone(defaultSettings)
local ActiveTargets = { Mining = nil, Combat = nil }
local isBlocking, flying = false, false
local bg, bv, Window = nil, nil, nil
local reconnectAttempts = 0
local rockDropdown, mobDropdown, autoLoadDropdown = nil, nil, nil

-- --- SISTEMAS DE SOPORTE (PVB) ---

local function setupAutoReconnect() 
    pcall(function()
        local prompt = game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 10)
        if prompt then
            prompt.DescendantAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" and currentConfig.autoReconnectEnabled then
                    reconnectAttempts = reconnectAttempts + 1
                    if reconnectAttempts <= 30 then
                        task.wait(6); TeleportService:Teleport(game.PlaceId, localPlayer)
                    end
                end
            end)
        end
    end)
    NetworkClient.ChildRemoved:Connect(function()
        if currentConfig.autoReconnectEnabled then task.wait(6); TeleportService:Teleport(game.PlaceId, localPlayer) end
    end)
end

local function startAntiAFK() 
    localPlayer.Idled:Connect(function()
        if currentConfig.antiAFKEnabled then
            VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

-- --- GESTIÓN DE GUARDADO ---

local function getAvailableConfigs()
    local configs = {"None"}
    pcall(function()
        if isfolder(CONFIG_FOLDER) then
            for _, file in pairs(listfiles(CONFIG_FOLDER)) do
                if file:match("%.json$") and not file:match("SystemSettings") then
                    local fileName = file:match(CONFIG_FOLDER .. "/(.+)%.json$") or file:match("([^/\\]+)%.json$")
                    table.insert(configs, fileName)
                end
            end
        end
    end)
    return configs
end

local function saveSystemSettings()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    writefile(SETTINGS_FILE, HttpService:JSONEncode(currentSettings))
end

local function saveConfig(name)
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    currentConfig.theme = WindUI:GetCurrentTheme()
    writefile(CONFIG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(currentConfig))
    WindUI:Notify({Title = "Saved", Content = name, Duration = 2})
    if autoLoadDropdown and autoLoadDropdown.Refresh then autoLoadDropdown:Refresh(getAvailableConfigs()) end
end

local function loadConfig(name)
    if not name or name == "None" then return end
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        local s, r = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if s and r then
            currentConfig = r
            if currentConfig.antiAFKEnabled then startAntiAFK() end
            if currentConfig.autoReconnectEnabled then setupAutoReconnect() end
            WindUI:SetTheme(currentConfig.theme or "Dark")
            WindUI:Notify({Title = "Loaded", Content = name, Duration = 2})
            if rockDropdown and rockDropdown.Set then rockDropdown:Set(currentConfig.MineTarget) end
            if mobDropdown and mobDropdown.Set then mobDropdown:Set(currentConfig.AttackTargets) end
            return true
        end
    end
    return false
end

if isfile(SETTINGS_FILE) then
    local s, r = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
    if s and r then currentSettings = r end
end
if currentSettings.autoLoadEnabled then loadConfig(currentSettings.autoLoadConfig) end

-- --- LÓGICA DE JUEGO ORIGINAL ---

local function GetPlayerData() 
    local level, gold = "Unknown", "Unknown"
    local gui = localPlayer:FindFirstChild("PlayerGui")
    if gui then
        local hud = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") and gui.Main.Screen:FindFirstChild("Hud")
        if hud then
            if hud:FindFirstChild("Level") then level = hud.Level.Text end
            if hud:FindFirstChild("Gold") then gold = hud.Gold.Text end
        end
    end
    return level, gold
end

local function GetInventoryOres() 
    local ores = {Iron = 0, Copper = 0, Gold = 0}
    local gui = localPlayer:FindFirstChild("PlayerGui")
    if not gui then return ores end
    local forgeFrame = gui:FindFirstChild("Forge") and gui.Forge:FindFirstChild("OreSelect") and gui.Forge.OreSelect:FindFirstChild("OresFrame")
    if forgeFrame and forgeFrame:FindFirstChild("Frame") and forgeFrame.Frame:FindFirstChild("Background") then
        for _, child in ipairs(forgeFrame.Frame.Background:GetChildren()) do
            local main = child:FindFirstChild("Main")
            if main then
                local qtyLbl = main:FindFirstChild("Quantity")
                local qty = qtyLbl and tonumber(qtyLbl.Text:match("%d+"))
                if qty and child.Name then ores[child.Name] = qty end
            end
        end
        return ores 
    end
    local stash = gui:FindFirstChild("Menu") and gui.Menu:FindFirstChild("Frame") and gui.Menu.Frame:FindFirstChild("Frame") 
        and gui.Menu.Frame.Frame:FindFirstChild("Menus") and gui.Menu.Frame.Frame.Menus:FindFirstChild("Stash") 
        and gui.Menu.Frame.Frame.Menus.Stash:FindFirstChild("Background")
    if stash then
        for _, itemFrame in ipairs(stash:GetChildren()) do
            local main = itemFrame:FindFirstChild("Main")
            if main then
                local name = main:FindFirstChild("ItemName") and main.ItemName.Text:gsub(" Ore", "")
                local qty = main:FindFirstChild("Quantity") and tonumber(main.Quantity.Text:match("%d+")) or 0
                if name and ores[name] ~= nil then ores[name] = qty end
            end
        end
    end
    return ores
end

local function RedeemAllCodes() 
    if not Remotes.RedeemCode then return end
    local codes = {"40KLIKES", "20KLIKES", "15KLIKES", "10KLIKES", "5KLIKES", "BETARELEASE!", "POSTRELEASEQNA"}
    for _, code in ipairs(codes) do task.spawn(function() Remotes.RedeemCode:InvokeServer(code) end); task.wait(0.2) end
    WindUI:Notify({Title = "Codes", Content = "Redeeming codes...", Duration = 3})
end

local function GetRockTypes() 
    local rockTypes, seen = {}, {}
    local rocksFolder = Workspace:FindFirstChild("Rocks")
    if rocksFolder then
        for _, cat in ipairs(rocksFolder:GetChildren()) do
            for _, child in ipairs(cat:GetChildren()) do
                if child.Name == "SpawnLocation" then
                    for _, m in ipairs(child:GetChildren()) do
                        if m:IsA("Model") and m:FindFirstChild("Hitbox") and not seen[m.Name] then
                            seen[m.Name] = true; table.insert(rockTypes, m.Name)
                        end
                    end
                elseif child:IsA("Model") and child:FindFirstChild("Hitbox") and not seen[child.Name] then
                    seen[child.Name] = true; table.insert(rockTypes, child.Name)
                end
            end
        end
    end
    table.sort(rockTypes); return rockTypes
end

local function GetMobTypes() 
    local mobs, seen = {}, {}
    local living = Workspace:FindFirstChild("Living")
    if living then
        for _, m in ipairs(living:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChild("Humanoid") and not m:FindFirstChild("RaceFolder") and not m:FindFirstChild("Animate") then
                local n = m.Name:gsub("%d+$", "")
                if not seen[n] then seen[n] = true; table.insert(mobs, n) end
            end
        end
    end
    table.sort(mobs); return mobs
end

local function GetTeleportLocations() 
    local locs = {}
    local prox = Workspace:FindFirstChild("Proximity")
    if prox then
        for _, l in ipairs(prox:GetChildren()) do
            if l:IsA("Model") or l:IsA("BasePart") then table.insert(locs, l) end
        end
    end
    table.sort(locs, function(a,b) return a.Name < b.Name end); return locs
end

local function FindNearestRock(maxDist) 
    local char = localPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local root = char.HumanoidRootPart
    local closest, bestDist = nil, maxDist or 500
    local rocksFolder = Workspace:FindFirstChild("Rocks")
    if not rocksFolder then return nil end
    for _, d in ipairs(rocksFolder:GetDescendants()) do
        if d.Name == "Hitbox" and d:IsA("BasePart") and d.Parent and d.Parent.Name == currentConfig.MineTarget then
            local info = d.Parent:FindFirstChild("infoFrame")
            local hp = info and info.Frame.rockHP.Text
            if not hp or (tonumber(hp:match("%d+")) or 0) > 0 then
                local dist = (d.Position - root.Position).Magnitude
                if dist < bestDist then closest = d; bestDist = dist end
            end
        end
    end
    return closest
end

local function InstantForge(ores, itemType) 
    local totalQty = 0
    for _, q in pairs(ores) do totalQty = totalQty + q end
    if totalQty < 3 then 
        WindUI:Notify({Title = "Error", Content = "Select at least 3 ores!", Duration = 3})
        return
    end
    local forgeModel = Workspace:FindFirstChild("Proximity") and Workspace.Proximity:FindFirstChild("Forge")
    if forgeModel then
        WindUI:Notify({Title = "Forge", Content = "Starting... DO NOT CLOSE", Duration = 3})
        Remotes.Forge:InvokeServer(forgeModel); task.wait()
        Remotes.StartForge:InvokeServer(forgeModel); task.wait(0.1)
        Remotes.ChangeSequence:InvokeServer("Melt", {FastForge = false, ItemType = itemType, Ores = ores})
        task.wait(1); Remotes.ChangeSequence:InvokeServer("Pour", { ClientTime = Workspace:GetServerTimeNow() })
        task.wait(1); Remotes.ChangeSequence:InvokeServer("Hammer", { ClientTime = Workspace:GetServerTimeNow() })
        task.wait(1); task.spawn(function() Remotes.ChangeSequence:InvokeServer("Water", { ClientTime = Workspace:GetServerTimeNow() }) end)
        task.wait(1); Remotes.ChangeSequence:InvokeServer("Showcase", {})
        WindUI:Notify({Title = "Forge", Content = "Completed!", Duration = 3})
    end
end

local function startFly() 
    local char, hum = localPlayer.Character, localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return end
    flying = true; hum.PlatformStand = true
    bg = Instance.new("BodyGyro", root); bg.P = 90000; bg.maxTorque = Vector3.new(9e9,9e9,9e9); bg.cframe = root.CFrame
    bv = Instance.new("BodyVelocity", root); bv.velocity = Vector3.zero; bv.maxForce = Vector3.new(9e9,9e9,9e9)
    task.spawn(function()
        while flying do
            local cam = Workspace.CurrentCamera
            if cam then
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if dir.Magnitude > 0 then bv.velocity = dir.Unit * 50 else bv.velocity = Vector3.zero end
                bg.cframe = cam.CFrame
            end
            RunService.RenderStepped:Wait()
        end
    end)
end
local function stopFly() 
    flying = false; if bg then bg:Destroy() end; if bv then bv:Destroy() end
    if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then localPlayer.Character.Humanoid.PlatformStand = false end
end

localPlayer.CharacterAdded:Connect(function() if flying then stopFly() end end)

-- --- INTERFAZ WINDUI (GLASS MODE) ---

WindUI:SetTheme(currentConfig.theme)
Window = WindUI:CreateWindow({
    Title = "MZXN Hub - The Forge", Icon = "hammer", Author = "@mzxn_xd", Folder = CONFIG_FOLDER, Size = UDim2.fromOffset(620, 520), 
    Theme = currentConfig.theme, SideBarWidth = 180, 
    Transparent = true -- [cite: 113] Transparencia activada como en MM2 Beta
})

local InfoTab = Window:Tab({Title = "Information", Icon = "info"})
local MainTab = Window:Tab({Title = "Farming", Icon = "pickaxe"})
local CombatTab = Window:Tab({Title = "Combat", Icon = "sword"})
local ForgeTab = Window:Tab({Title = "Forge", Icon = "flame"})
local TeleportTab = Window:Tab({Title = "Teleport", Icon = "map-pin"})
local SettingsTab = Window:Tab({Title = "Settings", Icon = "settings"})

Window:SelectTab(1)

-- Info
InfoTab:Section({Title = "User Profile", Icon = "user"})
local l, g = GetPlayerData()
InfoTab:Paragraph({
    Title = "Welcome, " .. localPlayer.Name .. "!",
    Desc = "Stats: Level " .. l .. " | Gold: " .. g
})
InfoTab:Paragraph({
    Title = "Account Information",
    Desc = "Username: @" .. localPlayer.Name .. " | ID: " .. localPlayer.UserId .. " | Age: " .. localPlayer.AccountAge .. " days"
})
InfoTab:Divider()
InfoTab:Paragraph({
    Title = "MZXN Hub - The Forge Edition",
    Desc = [[✨ COMPLETE FEATURES ✨

FEATURES:
• Auto Mine & Combat (Instant TP)
• Instant Forge System
• Infinite Fly & Teleports
• Anti-AFK & Auto-Reconnect
• Save/Load Configs

CONTROLS:
• G = Show/Hide Menu
• Ctrl + Click = Teleport
• WASD = Fly Control

Created by @mzxn_xd ❤️]]
})
InfoTab:Divider()
InfoTab:Button({Title = "Join Discord Server", Icon = "message-circle", Variant = "Primary",
    Callback = function() -- Código Discord PVB Exacto 
        local inviteCode = "KH6RPuGDku"
        if setclipboard then setclipboard("https://discord.gg/" .. inviteCode) end
        
        local function get_executor_request()
            return (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        end
        local requestFunc = get_executor_request()
        
        if not requestFunc then
            WindUI:Notify({Title = "Link Copied!", Content = "Discord link copied to clipboard", Duration = 3})
            return
        end
        
        local function tryJoin(port)
            local url = "http://127.0.0.1:" .. tostring(port) .. "/rpc?v=1"
            local body = {
                cmd = "INVITE_BROWSER",
                args = { code = inviteCode },
                nonce = HttpService:GenerateGUID(false)
            }
            
            local success, response = pcall(function()
                return requestFunc({
                    Url = url,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["Origin"] = "https://discord.com"
                    },
                    Body = HttpService:JSONEncode(body)
                })
            end)
            
            if success and response and (response.StatusCode == 200 or response.Status == 200) then
                return true
            end
            return false
        end
        
        local joined = false
        for port = 6463, 6472 do
            if tryJoin(port) then
                joined = true
                WindUI:Notify({Title = "Discord Opened!", Content = "Join request sent successfully", Duration = 3})
                break
            end
        end
        
        if not joined then
            WindUI:Notify({Title = "Link Copied!", Content = "Discord not found. Link copied to clipboard", Duration = 4})
        end
    end
})

-- Mining
MainTab:Section({Title = "Mining", Icon = "pickaxe"})
local rockList = GetRockTypes()
rockDropdown = MainTab:Dropdown({Title = "Select Rock", Values = #rockList > 0 and rockList or {"Pebble"}, Value = currentConfig.MineTarget, SearchBarEnabled = true, Callback = function(v) currentConfig.MineTarget = v end})
MainTab:Button({Title = "Refresh List", Icon = "refresh-cw", Callback = function() if rockDropdown.Refresh then rockDropdown:Refresh(GetRockTypes()) end end})
MainTab:Toggle({Title = "Auto Mine (TP)", Value = currentConfig.AutoMine, Callback = function(v) currentConfig.AutoMine = v end})

MainTab:Section({Title = "Movement", Icon = "wind"})
MainTab:Toggle({Title = "Auto Run", Value = currentConfig.AutoRun, Callback = function(v) currentConfig.AutoRun = v end})
MainTab:Toggle({Title = "Infinite Fly", Value = currentConfig.InfiniteFly, Callback = function(v) currentConfig.InfiniteFly = v; if v then startFly() else stopFly() end end})
MainTab:Toggle({Title = "Click TP (Ctrl)", Value = currentConfig.ClickTeleport, Callback = function(v) currentConfig.ClickTeleport = v end})

-- Combat
CombatTab:Section({Title = "Combat", Icon = "skull"})
local mobList = GetMobTypes()
mobDropdown = CombatTab:Dropdown({Title = "Select Enemies", Values = mobList, Multi = true, Value = currentConfig.AttackTargets, SearchBarEnabled = true, Callback = function(v) currentConfig.AttackTargets = v end})
CombatTab:Button({Title = "Refresh List", Icon = "refresh-cw", Callback = function() if mobDropdown.Refresh then mobDropdown:Refresh(GetMobTypes()) end end})
CombatTab:Toggle({Title = "Auto Attack (TP)", Value = currentConfig.AutoAttack, Callback = function(v) currentConfig.AutoAttack = v end})
CombatTab:Toggle({Title = "Auto Parry", Value = currentConfig.AutoParry, Callback = function(v) currentConfig.AutoParry = v end})

-- Forge
ForgeTab:Section({Title = "Instant Forge", Icon = "anvil"})
ForgeTab:Paragraph({Title = "⚠️ WARNING", Desc = "You MUST quit and reopen the game before using the forge manually after using this!", Image = "alert-triangle"})
ForgeTab:Dropdown({Title = "Item Type", Values = {"Weapon", "Armor"}, Value = currentConfig.ForgeItemType, Callback = function(v) currentConfig.ForgeItemType = v end})
local oreInputs, selectedOres = {}, {Iron = 0, Copper = 0, Gold = 0}
oreInputs.Iron = ForgeTab:Input({Title = "Iron Amount", Value = "0", Callback = function(t) selectedOres["Iron"] = tonumber(t) or 0 end})
oreInputs.Copper = ForgeTab:Input({Title = "Copper Amount", Value = "0", Callback = function(t) selectedOres["Copper"] = tonumber(t) or 0 end})
oreInputs.Gold = ForgeTab:Input({Title = "Gold Amount", Value = "0", Callback = function(t) selectedOres["Gold"] = tonumber(t) or 0 end})
ForgeTab:Button({Title = "Detect Inventory Ores", Icon = "search", Callback = function()
    local myOres = GetInventoryOres()
    oreInputs.Iron:Set(tostring(myOres.Iron or 0)); oreInputs.Copper:Set(tostring(myOres.Copper or 0)); oreInputs.Gold:Set(tostring(myOres.Gold or 0))
    WindUI:Notify({Title = "Inventory Loaded", Duration = 2})
end})
ForgeTab:Button({Title = "Forge Now", Icon = "hammer", Variant = "Primary", Callback = function() InstantForge(selectedOres, currentConfig.ForgeItemType) end})

-- Teleport
TeleportTab:Section({Title = "Locations", Icon = "map"})
TeleportTab:Button({Title = "Refresh Locations", Icon = "refresh-cw", Callback = function() WindUI:Notify({Title = "Refreshed", Duration = 1}) end})
for _, loc in ipairs(GetTeleportLocations()) do
    TeleportTab:Button({Title = loc.Name, Callback = function()
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local t = loc:IsA("Model") and loc:GetPivot() or loc.CFrame
            localPlayer.Character.HumanoidRootPart.CFrame = t + Vector3.new(0,3,0)
        end
    end})
end

-- Settings
SettingsTab:Section({Title = "System", Icon = "settings"})
SettingsTab:Toggle({Title = "Enable Auto-Load", Value = currentSettings.autoLoadEnabled, Callback = function(v) currentSettings.autoLoadEnabled = v; saveSystemSettings() end})
autoLoadDropdown = SettingsTab:Dropdown({Title = "Startup Config", Values = getAvailableConfigs(), Value = currentSettings.autoLoadConfig, SearchBarEnabled = true, Callback = function(v) currentSettings.autoLoadConfig = v; saveSystemSettings() end})
SettingsTab:Button({Title = "Refresh Configs", Icon = "refresh-cw", Callback = function() if autoLoadDropdown.Refresh then autoLoadDropdown:Refresh(getAvailableConfigs()) end end})
SettingsTab:Divider()
local configNameEntry = "mzxn-forge"
SettingsTab:Input({Title = "Config Name", Value = configNameEntry, Callback = function(v) configNameEntry = v or "mzxn-forge" end})
SettingsTab:Button({Title = "Save Config", Icon = "save", Variant = "Primary", Callback = function() saveConfig(configNameEntry) end})
SettingsTab:Button({Title = "Load Config", Icon = "folder-open", Callback = function() loadConfig(configNameEntry) end})
SettingsTab:Divider()
SettingsTab:Toggle({Title = "Anti-AFK", Value = currentConfig.antiAFKEnabled, Callback = function(v) currentConfig.antiAFKEnabled = v; if v then startAntiAFK() end end})
SettingsTab:Toggle({Title = "Auto-Reconnect", Value = currentConfig.autoReconnectEnabled, Callback = function(v) currentConfig.autoReconnectEnabled = v; if v then setupAutoReconnect() end end})
SettingsTab:Button({Title = "Redeem All Codes", Callback = RedeemAllCodes})

-- --- BUCLES ---

task.spawn(function() -- Auto Mine
    while true do task.wait(0.1)
        local char = localPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if currentConfig.AutoMine and Remotes.ToolActivated and root then
            if not char:FindFirstChild("Pickaxe") then
                local bp = localPlayer.Backpack:FindFirstChild("Pickaxe")
                if bp then char.Humanoid:EquipTool(bp) end
            end
            local valid = false
            if ActiveTargets.Mining and ActiveTargets.Mining.Parent and ActiveTargets.Mining.Parent.Name == currentConfig.MineTarget then
                 local info = ActiveTargets.Mining.Parent:FindFirstChild("infoFrame")
                 local hp = info and info.Frame.rockHP.Text
                 if not hp or (tonumber(hp:match("%d+")) or 0) > 0 then valid = true end
            end
            if not valid then ActiveTargets.Mining = nil end
            if not ActiveTargets.Mining then ActiveTargets.Mining = FindNearestRock(500) end
            if ActiveTargets.Mining and (root.Position - ActiveTargets.Mining.Position).Magnitude <= 15 then
                Remotes.ToolActivated:InvokeServer("Pickaxe")
            end
        end
    end
end)

RunService.Heartbeat:Connect(function() -- Mine CFrame
    if currentConfig.AutoMine and ActiveTargets.Mining and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local r = localPlayer.Character.HumanoidRootPart; r.Anchored = false; r.AssemblyLinearVelocity = Vector3.zero
        local p = ActiveTargets.Mining.Position; r.CFrame = CFrame.lookAt(p + Vector3.new(5,0,0), p)
    end
end)

task.spawn(function() -- Auto Attack
    while true do task.wait(0.1)
        local char = localPlayer.Character
        if currentConfig.AutoAttack and char then
            local t, dist = nil, 500
            local living = Workspace:FindFirstChild("Living")
            if living then
                for _, v in pairs(living:GetChildren()) do
                    if v ~= char and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 and not v:FindFirstChild("RaceFolder") and not v:FindFirstChild("Animate") then
                        local n = v.Name:gsub("%d+$", "")
                        local should = (type(currentConfig.AttackTargets)=="table" and (table.find(currentConfig.AttackTargets,"All") or table.find(currentConfig.AttackTargets,n))) or false
                        if should then
                            local d = (char.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
                            if d < dist then t = v; dist = d end
                        end
                    end
                end
            end
            ActiveTargets.Combat = t
            if t then
                local weapon = char:FindFirstChildWhichIsA("Tool")
                if not weapon or weapon.Name == "Pickaxe" or weapon.Name == "Hammer" then
                    for _, tool in ipairs(localPlayer.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name ~= "Pickaxe" and tool.Name ~= "Hammer" then
                            char.Humanoid:EquipTool(tool); weapon = tool; break
                        end
                    end
                end
                if currentConfig.AutoParry then
                    local s = t:FindFirstChild("Status"); local att = s and s:FindFirstChild("Attacking")
                    if att and att.Value and not isBlocking then Remotes.StartBlock:InvokeServer(); isBlocking = true
                    elseif isBlocking and (not att or not att.Value) then Remotes.StopBlock:InvokeServer(); isBlocking = false end
                end
                if not isBlocking and dist < 15 then Remotes.ToolActivated:InvokeServer("Weapon") end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function() -- Combat CFrame
    if currentConfig.AutoAttack and ActiveTargets.Combat and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local r = localPlayer.Character.HumanoidRootPart; local tr = ActiveTargets.Combat:FindFirstChild("HumanoidRootPart")
        if tr then r.Anchored = false; r.AssemblyLinearVelocity = Vector3.zero; r.CFrame = CFrame.lookAt((tr.CFrame*CFrame.new(0,0,3)).Position, tr.Position) end
    end
end)

task.spawn(function()
    while true do task.wait(0.2)
        local char = localPlayer.Character
        if currentConfig.AutoRun and Remotes.Run and char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then Remotes.Run:InvokeServer() end
        if currentConfig.InfiniteFly and not flying then startFly() elseif not currentConfig.InfiniteFly and flying then stopFly() end
    end
end)

UserInputService.InputBegan:Connect(function(i,g)
    if not g and currentConfig.ClickTeleport and i.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local m = localPlayer:GetMouse()
        if m.Hit and localPlayer.Character then localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(m.Hit.Position + Vector3.new(0,3,0)) end
    end
end)

WindUI:Notify({Title = "MZXN Hub", Content = "Loaded Transparent Edition", Duration = 3})
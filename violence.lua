do
    local cloneref = cloneref or clonereference or function(instance) return instance; end
    local RunService = cloneref(game:GetService("RunService"))
    local UserInputService = cloneref(game:GetService("UserInputService"))
    local Lighting = cloneref(game:GetService("Lighting"))
    local Players = cloneref(game:GetService("Players"))
    local Stats = game:GetService("Stats")
    local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))
    local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local TargetGui = PlayerGui
    pcall(function()
        local core = cloneref(game:GetService("CoreGui"))
        if core then TargetGui = core end
    end)

    local function SafeLoad(url)
        local success, result = pcall(function()
            local source = game:HttpGet(url)
            if type(source) == "string" then
                local func = loadstring(source)
                if type(func) == "function" then
                    return func()
                end
            end
            return nil
        end)
        return success and result or nil
    end

    local WindUI = SafeLoad("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
    if not WindUI then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Error", Text = "Failed to load WindUI. Check executor or internet."})
        end)
        return
    end

    local IconsV2 = SafeLoad("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua")
    if not IconsV2 then
        IconsV2 = {GetIcon = function() return "" end, SetIconsType = function() end}
    end
    IconsV2.SetIconsType("sfsymbols")

    local ESP_COLORS = {
        Killer = Color3.fromRGB(255, 0, 0),
        Survivor = Color3.fromRGB(64, 224, 255),
        Generator = Color3.fromRGB(200, 100, 0),
        Gate = Color3.fromRGB(255, 255, 255),
        Pallet = Color3.fromRGB(74, 255, 181),
        Hook = Color3.fromRGB(132, 255, 169)
    }

    local MaskNames = {
        Richard = "Rooster", Tony = "Tiger", Brandon = "Panther", 
        Cobra = "Cobra", Richter = "Rat", Rabbit = "Rabbit", Alex = "Chainsaw"
    }

    local CachedMapObjects = {Generators = {}, Pallets = {}, Hooks = {}, Gates = {}}

    local function UpdateMapCache()
        local map = workspace:FindFirstChild("Map")
        if not map then return end
        
        CachedMapObjects.Generators = {}
        CachedMapObjects.Pallets = {}
        CachedMapObjects.Hooks = {}
        CachedMapObjects.Gates = {}
        
        for _, obj in ipairs(map:GetDescendants()) do
            if obj:IsA("Model") then
                if obj.Name == "Generator" then
                    table.insert(CachedMapObjects.Generators, obj)
                elseif obj.Name == "Hook" then
                    table.insert(CachedMapObjects.Hooks, obj)
                elseif obj.Name == "Palletwrong" or obj.Name == "Pallet" then
                    table.insert(CachedMapObjects.Pallets, obj)
                elseif obj.Name == "Gate" then
                    table.insert(CachedMapObjects.Gates, obj)
                end
            end
        end
    end

    task.spawn(UpdateMapCache)
    task.spawn(function()
        while task.wait(10) do
            UpdateMapCache()
        end
    end)

    local SpeedBoost, wasSpeedBoostActive, NoSlowdown, InstantHeal, AntiKnock = false, false, false, false, false
    local AntiBlind, AntiStun = false, false
    local IsInvisible = false
    local Aimbot, WallCheck, ShowFOVCircle = false, true, false
    local CustomCameraFOV = false
    local BoostSpeed, CameraFOVValue, AimRadius = 24, 100, 200
    local AutoAttack = false
    local AttackRange = 10
    local PerfectGen = false
    local PerfectHeal = false
    local WarnKiller = true
    local ActiveGenerators = {}
    local ThemeName = "Crimson"
    local Refreshing = false
    local AutoRotate = false
    local AutoUnhook = false
    local EnableLeaveGen = false
    local LeaveGenDistance = 25
    local MobileLeaveButton = nil
    local DoubleDamageGen = false
    local ESP_Survivor, ESP_Killer, ESP_Generator, ESP_Gate, ESP_Pallet, ESP_Hook = false, false, false, false, false, false
    local ActiveESP = {}
    local LastUpdateTick, LastESPRefresh = 0, 0
    local FOVCircle = nil
    local AimDistance = 150
    
    local UIToggleKey = Enum.KeyCode.PageDown

    -- SERVER DESYNC INVISIBILITY VARIABLES
    local seatTeleportPosition = CFrame.new(-25.95, 400, 3537.55)
    local SavedRootJoint = nil
    local SavedRootParent = nil

    local function setCharacterTransparency(transparency)
        local character = Players.LocalPlayer.Character
        if not character then return end
        
        for _, part in ipairs(character:GetDescendants()) do
            if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart" then
                local orig = part:GetAttribute("OrigTrans")
                if orig == nil then
                    part:SetAttribute("OrigTrans", part.Transparency)
                    orig = part.Transparency
                end
                
                if transparency == 0 then
                    part.Transparency = orig
                else
                    if orig < 1 then
                        part.Transparency = transparency
                    end
                end
            end
        end
    end

    local function ToggleInvisibility(state)
        IsInvisible = state
        local character = Players.LocalPlayer.Character
        if not character then return end

        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if IsInvisible then
            setCharacterTransparency(0.5)
            
            if humanoidRootPart and torso then
                -- LO'S FIX : Fixer la caméra sur le Torso pour que l'écran ne saute pas
                workspace.CurrentCamera.CameraSubject = torso

                local motor = humanoidRootPart:FindFirstChild("RootJoint") or torso:FindFirstChild("RootJoint") or torso:FindFirstChild("Root")
                if motor and motor:IsA("Motor6D") then
                    SavedRootJoint = motor:Clone()
                    SavedRootParent = motor.Parent
                    motor:Destroy() 
                end
                
                humanoidRootPart.CFrame = seatTeleportPosition
                
                WindUI:Notify({Title = "Invisible Mode", Content = "Server Desync Active. Screen stable.", Icon = IconsV2.GetIcon("EyeSlashFill")})
            else
                WindUI:Notify({Title = "Error", Content = "Invisibility failed.", Icon = IconsV2.GetIcon("Xmark")})
            end
            
            local h = TargetGui:FindFirstChild("GhostHighlight_" .. LocalPlayer.Name)
            if not h then
                h = Instance.new("Highlight")
                h.Name = "GhostHighlight_" .. LocalPlayer.Name
                h.Adornee = character
                h.FillColor = Color3.fromRGB(255, 255, 255)
                h.FillTransparency = 0.65
                h.OutlineColor = Color3.fromRGB(200, 200, 200)
                h.OutlineTransparency = 0.1
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = TargetGui
            end
        else
            setCharacterTransparency(0)
            
            if humanoidRootPart and torso then
                humanoidRootPart.CFrame = torso.CFrame
                
                if SavedRootJoint and SavedRootParent then
                    local restoredMotor = SavedRootJoint:Clone()
                    restoredMotor.Parent = SavedRootParent
                    SavedRootJoint = nil
                    SavedRootParent = nil
                end

                -- LO'S FIX : Remettre la caméra sur l'Humanoid normal
                if humanoid then
                    workspace.CurrentCamera.CameraSubject = humanoid
                end
            end
            
            local h = TargetGui:FindFirstChild("GhostHighlight_" .. LocalPlayer.Name)
            if h then h:Destroy() end
            
            WindUI:Notify({Title = "Invisible Mode", Content = "Invisibility disabled. Camera restored.", Icon = IconsV2.GetIcon("Eye")})
        end
    end

    -- PERFECT GEN
    task.spawn(function()
        local GeneratorRemote = ReplicatedStorage:WaitForChild("Remotes", 10)
        if GeneratorRemote then
            GeneratorRemote = GeneratorRemote:WaitForChild("Generator", 10)
        end
        local SkillCheckEvent = GeneratorRemote and GeneratorRemote:WaitForChild("SkillCheckEvent", 10)
        
        if SkillCheckEvent then
            SkillCheckEvent.OnClientEvent:Connect(function()
                if not PerfectGen then return end
                task.wait(0.2) 
                
                if type(getgc) == "function" then
                    for _, func in pairs(getgc(true)) do
                        if type(func) == "function" and islclosure(func) then
                            local info = debug.getinfo(func)
                            
                            if info.source and info.source:match("Skillcheck%-gen") and info.nups == 15 then
                                local upvals = debug.getupvalues(func)
                                
                                if upvals[1] == true then
                                    debug.setupvalue(func, 2, false)
                                    
                                    local lineFrame = upvals[5]
                                    local goalFrame = upvals[6]
                                    
                                    if lineFrame and goalFrame then
                                        lineFrame.Rotation = goalFrame.Rotation + 109
                                    end
                                    
                                    func("success")
                                    break 
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- PERFECT HEAL
    task.spawn(function()
        local HealingRemote = ReplicatedStorage:WaitForChild("Remotes", 10)
        if HealingRemote then
            HealingRemote = HealingRemote:WaitForChild("Healing", 10)
        end
        local SkillCheckEventHeal = HealingRemote and HealingRemote:WaitForChild("SkillCheckEvent", 10)
        
        if SkillCheckEventHeal then
            SkillCheckEventHeal.OnClientEvent:Connect(function()
                if not PerfectHeal then return end
                task.wait(0.6) 
                
                if type(getgc) == "function" then
                    for _, func in pairs(getgc(true)) do
                        if type(func) == "function" and islclosure(func) then
                            local info = debug.getinfo(func)
                            
                            if info.source and info.source:match("Skillcheck%-player") and info.nups == 13 then
                                local upvals = debug.getupvalues(func)
                                
                                if typeof(upvals[13]) == "Instance" and upvals[13]:IsA("Sound") then
                                    if upvals[1] == true then
                                        debug.setupvalue(func, 2, false)
                                        
                                        local lineFrame = upvals[5]
                                        local goalFrame = upvals[6]
                                        
                                        if lineFrame and goalFrame then
                                            lineFrame.Rotation = goalFrame.Rotation + 109
                                        end
                                        
                                        func("success")
                                        break 
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)

    local function GetGameValue(obj, name)
        if not obj or not obj.Parent then return nil end
        local success, result = pcall(function()
            local attr = obj:GetAttribute(name)
            if attr ~= nil then return attr end
            local child = obj:FindFirstChild(name)
            if child and child:IsA("ValueBase") then return child.Value end
            return nil
        end)
        return (success and result) or nil
    end

    local function CreateBillboardTag(text, color, size, textSize)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "Tag"
        billboard.AlwaysOnTop = true
        billboard.Size = size or UDim2.new(0, 120, 0, 30)
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.Font = Enum.Font.GothamBold
        label.TextSize = textSize or 10
        label.TextWrapped = true
        label.RichText = true
        label.Parent = billboard
        return billboard
    end

    local function ApplyHighlight(object, color)
        local h = object:FindFirstChild("H")
        if not h then
            h = Instance.new("Highlight")
            h.Name = "H"
            h.Adornee = object
            h.Parent = object
        end
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 0.8
        h.OutlineTransparency = 0.3
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = true
    end

    local function RemoveHighlight(object)
        if object then
            local h = object:FindFirstChild("H")
            if h then h:Destroy() end
        end
    end

    local function ApplyBoxESP(object, color)
        local targetPart = object:IsA("Model") and (object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")) or object
        if not targetPart then return end
        
        local h = object:FindFirstChild("BoxESP")
        if not h then
            h = Instance.new("BoxHandleAdornment")
            h.Name = "BoxESP"
            h.Adornee = targetPart
            h.Parent = object
            h.AlwaysOnTop = true
            h.ZIndex = 10
            h.Size = targetPart.Size + Vector3.new(0.5, 0.5, 0.5)
            h.Transparency = 0.6
        end
        h.Color3 = color
        h.Visible = true
    end

    local function RemoveBoxESP(object)
        if object then
            local h = object:FindFirstChild("BoxESP")
            if h then h:Destroy() end
        end
    end

    local function CreatePlayerESP(player, isKiller)
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        
        local color = isKiller and ESP_COLORS.Killer or ESP_COLORS.Survivor
        local name = player.Name
        
        if isKiller then
            color = ESP_COLORS.Killer 
            local maskAttr = GetGameValue(char, "Mask") or GetGameValue(player, "Mask")
            if maskAttr and MaskNames[maskAttr] then
                name = name .. "\n[" .. string.upper(MaskNames[maskAttr]) .. "]"
            else
                name = name .. "\n[KILLER]"
            end
        end
        
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            local dist = math.floor((char.HumanoidRootPart.Position - myRoot.Position).Magnitude)
            name = name .. "\n[" .. dist .. " m]"
        end
        
        if not isKiller then
            local isHooked = GetGameValue(char, "IsHooked")
            local isKnocked = GetGameValue(char, "Knocked")
            local hum = char:FindFirstChild("Humanoid")
            if isHooked then
                color = Color3.fromRGB(255, 100, 150)
                name = name .. "\n[HOOKED]"
            elseif isKnocked then
                color = Color3.fromRGB(255, 150, 0)
                name = name .. "\n[KNOCKED]"
            elseif hum and (hum.Health < hum.MaxHealth) then
                color = Color3.fromRGB(255, 255, 0)
                name = name .. "\n[INJURED]"
            end
        end
        
        ApplyHighlight(char, color)
        local root = char.HumanoidRootPart
        local bg = root:FindFirstChild("TagESP")
        if not bg then
            bg = CreateBillboardTag(name, color)
            bg.Name = "TagESP"
            bg.StudsOffset = Vector3.new(0, 3.5, 0)
            bg.Adornee = root
            bg.Parent = root
        else
            local lbl = bg:FindFirstChild("Label") or bg:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.Text = name
                lbl.TextColor3 = color
            end
        end
    end

    local function RemovePlayerESP(player)
        local char = player.Character
        if char then
            RemoveHighlight(char)
            local bg = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("TagESP")
            if bg then bg:Destroy() end
        end
    end

    local function updateGeneratorProgress(generator)
        if not generator or not generator.Parent then return true end
        local percent = GetGameValue(generator, "RepairProgress") or GetGameValue(generator, "Progress") or 0
        local billboard = generator:FindFirstChild("GenBitchHook")
        
        if percent >= 100 or not ESP_Generator then
            if billboard then billboard:Destroy() end
            return percent >= 100
        end
        
        local cp = math.clamp(percent, 0, 100)
        local finalColor = (cp < 50) and ESP_COLORS.Generator:Lerp(Color3.fromRGB(180, 180, 0), cp / 50) or Color3.fromRGB(180, 180, 0):Lerp(Color3.fromRGB(8, 200, 8), (cp - 50) / 50)
        
        local percentStr = string.format("[%.2f%%]", percent)
        
        if not billboard then
            billboard = CreateBillboardTag(percentStr, finalColor)
            billboard.Name = "GenBitchHook"
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.Adornee = generator:FindFirstChild("defaultMaterial", true) or generator
            billboard.Parent = generator
        else
            local lbl = billboard:FindFirstChild("Label") or billboard:FindFirstChildOfClass("TextLabel")
            if lbl then
                lbl.Text = percentStr
                lbl.TextColor3 = finalColor
            end
        end
        return false
    end

    local function RefreshESP()
        if Refreshing then return end
        Refreshing = true
        ActiveGenerators = {}
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local teamName = (p.Team and p.Team.Name:lower()) or ""
                local isKiller = teamName:find("killer") ~= nil
                if (isKiller and ESP_Killer) or (not isKiller and ESP_Survivor) then
                    CreatePlayerESP(p, isKiller)
                else
                    RemovePlayerESP(p)
                end
            end
        end
        
        if not CachedMapObjects then
            Refreshing = false
            return
        end
        
        for _, obj in ipairs(CachedMapObjects.Generators) do
            if ESP_Generator then
                table.insert(ActiveGenerators, obj)
            else
                local b = obj:FindFirstChild("GenBitchHook")
                if b then b:Destroy() end
            end
        end
        
        for _, obj in ipairs(CachedMapObjects.Hooks) do
            local m = obj:FindFirstChild("Model")
            if m then
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("MeshPart") then
                        if ESP_Hook then
                            ApplyBoxESP(p, ESP_COLORS.Hook)
                        else
                            RemoveBoxESP(p)
                        end
                    end
                end
            end
        end
        
        for _, obj in ipairs(CachedMapObjects.Pallets) do
            if ESP_Pallet then
                ApplyBoxESP(obj, ESP_COLORS.Pallet)
            else
                RemoveBoxESP(obj)
            end
        end
        
        for _, obj in ipairs(CachedMapObjects.Gates) do
            if ESP_Gate then
                ApplyBoxESP(obj, ESP_COLORS.Gate)
            else
                RemoveBoxESP(obj)
            end
        end
        Refreshing = false
    end

    local function GetClosestPlayer()
        local closestPart = nil
        local shortest = AimRadius
        local myTeam = (LocalPlayer.Team and LocalPlayer.Team.Name:lower()) or ""
        local isKiller = myTeam:find("killer") ~= nil
        local camera = workspace.CurrentCamera
        local centerScreen = camera.ViewportSize / 2
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local enemyTeam = (p.Team and p.Team.Name:lower()) or ""
                if isKiller and enemyTeam:find("killer") then continue end
                if not isKiller and not enemyTeam:find("killer") then continue end
                
                local isKnocked = GetGameValue(p.Character, "Knocked")
                local isHooked = GetGameValue(p.Character, "IsHooked")
                if isKnocked or isHooked then continue end
                
                local targetPart = p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso") or p.Character:FindFirstChild("HumanoidRootPart")
                if not targetPart then continue end
                
                local pos, visible = camera:WorldToViewportPoint(targetPart.Position)
                if visible then
                    local dist2D = (Vector2.new(pos.X, pos.Y) - centerScreen).Magnitude
                    if dist2D <= shortest then
                        shortest = dist2D
                        closestPart = targetPart
                    end
                end
            end
        end
        return closestPart
    end

    -- WINDOW INITIALIZATION
    local Window = WindUI:CreateWindow({
        Title = "FORKT-HUB",
        Author = "by alz",
        Icon = "rbxassetid://92373688580867",
        Theme = ThemeName,
        Size = UDim2.fromOffset(800, 500),
        Resizable = true,
        MinSize = Vector2.new(600, 400),
        MaxSize = Vector2.new(1000, 700),
        NewElements = true,
        ElementsRadius = 12,
        Transparent = true,
        Acrylic = true,
        HideSearchBar = false,
        Folder = "ForktHub",
        ToggleKey = UIToggleKey,
        OpenButton = {
            Title = "FORKT",
            Icon = IconsV2.GetIcon("Command"),
            CornerRadius = UDim.new(0, 14),
            Draggable = true,
            Enabled = true,
            OnlyMobile = true,
            Scale = 0.85,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 45, 85)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 85, 105)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 130))
            })
        },
        Topbar = {Height = 45, ButtonsType = "Mac"}
    })

    -- TAB SECTIONS
    local TabProfile = Window:Tab({Title = "Profile", Icon = "rbxassetid://13585614795", IconThemed = true})
    local Tab1 = Window:Tab({Title = "Main", Icon = IconsV2.GetIcon("GamecontrollerFill")})
    local Tab4 = Window:Tab({Title = "Automation", Icon = IconsV2.GetIcon("CpuFill")})
    local TabKiller = Window:Tab({Title = "Killer", Icon = IconsV2.GetIcon("ExclamationmarkTriangleFill")})
    local Tab2 = Window:Tab({Title = "Visuals", Icon = IconsV2.GetIcon("EyeFill")})
    local Tab3 = Window:Tab({Title = "Combat", Icon = IconsV2.GetIcon("Target")})
    local TabSettings = Window:Tab({Title = "Settings", Icon = "rbxassetid://6125287994"})
    
    TabProfile:Select()

    Tab1:Section({Title = "Movement & Health"})
    Tab1:Toggle({Title = "No Slowdown", Flag = "F_NoSlowdown", Callback = function(v) NoSlowdown = v end})
    Tab1:Toggle({Title = "Instant Heal", Flag = "F_InstantHeal", Callback = function(v) InstantHeal = v end})
    Tab1:Toggle({Title = "Anti Knock", Flag = "F_AntiKnock", Callback = function(v) AntiKnock = v end})
    Tab1:Toggle({Title = "Speed Boost", Flag = "F_SpeedBoost", Callback = function(v) SpeedBoost = v end})
    Tab1:Keybind({Title = "Speed Boost Keybind", Key = Enum.KeyCode.R, Callback = function() SpeedBoost = not SpeedBoost end})
    Tab1:Slider({Title = "Custom Speed", Value = {Min = 16, Max = 100, Default = 24}, Callback = function(v) BoostSpeed = v end})

    Tab1:Section({Title = "Exploits"})
    Tab1:Toggle({Title = "Invisible Mode", Flag = "F_Invisible", Callback = function(v) ToggleInvisibility(v) end})
    Tab1:Keybind({Title = "Invisible Keybind", Key = Enum.KeyCode.T, Callback = function() ToggleInvisibility(not IsInvisible) end})

    Tab1:Section({Title = "Camera"})
    Tab1:Toggle({Title = "Enable Custom FOV", Flag = "F_CustomFOV", Callback = function(v) CustomCameraFOV = v end})
    Tab1:Slider({Title = "Field of View", Value = {Min = 70, Max = 120, Default = 100}, Callback = function(v) CameraFOVValue = v end})

    Tab4:Section({Title = "Game Logic"})
    Tab4:Toggle({Title = "Perfect Gen", Flag = "F_PerfectGen", Callback = function(v) PerfectGen = v end})
    Tab4:Toggle({Title = "Perfect Heal", Flag = "F_PerfectHeal", Callback = function(v) PerfectHeal = v end})
    Tab4:Toggle({Title = "Instant Unhook", Flag = "F_AutoUnhook", Callback = function(v) AutoUnhook = v end})

    Tab2:Section({Title = "Visuals"})
    Tab2:Toggle({Title = "ESP Survivor", Flag = "F_ESPSurvivor", Callback = function(v) ESP_Survivor = v RefreshESP() end})
    Tab2:Toggle({Title = "ESP Killer", Flag = "F_ESPKiller", Callback = function(v) ESP_Killer = v RefreshESP() end})
    Tab2:Toggle({Title = "ESP Generator", Flag = "F_ESPGen", Callback = function(v) ESP_Generator = v RefreshESP() end})
    Tab2:Toggle({Title = "ESP Exit Gate", Flag = "F_ESPGate", Callback = function(v) ESP_Gate = v RefreshESP() end})
    Tab2:Toggle({Title = "ESP Pallet", Flag = "F_ESPPallet", Callback = function(v) ESP_Pallet = v RefreshESP() end})
    Tab2:Toggle({Title = "ESP Hook", Flag = "F_ESPHook", Callback = function(v) ESP_Hook = v RefreshESP() end})
    Tab2:Button({Title = "Force Fullbright", Callback = function() Lighting.Brightness, Lighting.ClockTime, Lighting.GlobalShadows = 2, 12, false end})

    TabSettings:Section({Title = "Interface"})
    -- LO'S FIX : Utiliser la méthode officielle pour changer la touche de l'UI
    TabSettings:Keybind({
        Title = "UI Toggle Key",
        Desc = "Change the key used to hide/show the menu.",
        Key = UIToggleKey,
        Callback = function(key)
            UIToggleKey = key
            Window:SetToggleKey(key) -- LA SEULE LIGNE NÉCESSAIRE
            WindUI:Notify({Title = "Keybind Changed", Content = "UI Toggle key is now " .. key.Name})
        end
    })

    -- RENDERING LOOPS
    RunService.RenderStepped:Connect(function(deltaTime)
        if SpeedBoost and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.MoveDirection.Magnitude > 0 then
                local actualSpeed = hum.WalkSpeed
                if actualSpeed < BoostSpeed then
                    root.CFrame = root.CFrame + (hum.MoveDirection * ((BoostSpeed - actualSpeed) * deltaTime))
                end
            end
        end

        if FOVCircle then
            FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            FOVCircle.Size = UDim2.new(0, AimRadius * 2, 0, AimRadius * 2)
        end
    end)

    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if (now - LastUpdateTick) < 0.05 then return end
        LastUpdateTick = now
        
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        
        if IsInvisible and myChar then
            for _, part in ipairs(myChar:GetDescendants()) do
                if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart" then
                    if part:GetAttribute("SavedTrans") == nil then part:SetAttribute("SavedTrans", part.Transparency) end
                    part.Transparency = 1
                end
            end
        end

        if (now - LastESPRefresh) > 0.4 then LastESPRefresh = now RefreshESP() end

        if myChar and myHum then
            if InstantHeal and myHum.Health < myHum.MaxHealth then myHum.Health = myHum.MaxHealth end
            if AutoUnhook and GetGameValue(myChar, "IsHooked") then
                myChar:SetAttribute("IsHooked", false)
                myHum.PlatformStand = false
                myHum:ChangeState(Enum.HumanoidStateType.Running)
                if myChar:FindFirstChild("HumanoidRootPart") then
                    myChar.HumanoidRootPart.CFrame = myChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
                end
            end
        end
        
        for i = #ActiveGenerators, 1, -1 do
            if updateGeneratorProgress(ActiveGenerators[i]) then table.remove(ActiveGenerators, i) end
        end
    end)

    WindUI:Notify({Title = "FORKT-HUB", Content = "Script fully fixed by LO & ENI.", Icon = IconsV2.GetIcon("CheckmarkCircle")})
end

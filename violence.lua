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
    local RemoveFireCooldown = false -- ENI FIX: Variable pour le spam d'arme
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
    local MenuOpen = true 

    -- SERVER DESYNC INVISIBILITY
    local seatTeleportPosition = CFrame.new(-25.95, 400, 3537.55)
    local currentSeatPosition = nil
    local seatReturnHeartbeatConnection = nil

    local function startSeatReturnHeartbeat()
        if seatReturnHeartbeatConnection then
            seatReturnHeartbeatConnection:Disconnect()
            seatReturnHeartbeatConnection = nil
        end
        seatReturnHeartbeatConnection = RunService.Heartbeat:Connect(function() end)
    end

    local function stopSeatReturnHeartbeat()
        if seatReturnHeartbeatConnection then
            seatReturnHeartbeatConnection:Disconnect()
            seatReturnHeartbeatConnection = nil
        end
    end

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
        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        local camera = workspace.CurrentCamera

        if IsInvisible then
            setCharacterTransparency(0.5)
            
            if humanoidRootPart and torso then
                camera.CameraSubject = torso

                local savedpos = humanoidRootPart.CFrame
                pcall(function() character:MoveTo(seatTeleportPosition.Position) end)
                task.wait(0.1)
                
                local Seat = Instance.new('Seat')
                Seat.Parent = workspace
                Seat.Anchored = false
                Seat.CanCollide = false
                Seat.Name = 'invischair'
                Seat.Transparency = 1
                Seat.CFrame = seatTeleportPosition
                
                local Weld = Instance.new("Weld")
                Weld.Part0 = Seat
                Weld.Part1 = torso
                Weld.Parent = Seat
                
                task.wait()
                pcall(function() Seat.CFrame = savedpos end)
                currentSeatPosition = Seat.Position
                startSeatReturnHeartbeat()
                
                WindUI:Notify({Title = "Invisible Mode", Content = "Server Desync Active. You are a ghost.", Icon = IconsV2.GetIcon("EyeSlashFill")})
            else
                WindUI:Notify({Title = "Error", Content = "Invisibility failed (No Torso).", Icon = IconsV2.GetIcon("Xmark")})
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
            stopSeatReturnHeartbeat()
            currentSeatPosition = nil
            
            local hum = character:FindFirstChildOfClass("Humanoid")
            if hum then
                camera.CameraSubject = hum
            end
            
            task.spawn(function()
                local inv = workspace:FindFirstChild('invischair')
                if inv then pcall(function() inv:Destroy() end) end
            end)
            
            local h = TargetGui:FindFirstChild("GhostHighlight_" .. LocalPlayer.Name)
            if h then h:Destroy() end
            
            WindUI:Notify({Title = "Invisible Mode", Content = "Invisibility disabled. You are visible.", Icon = IconsV2.GetIcon("Eye")})
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

    local ESP_UI_Folder = PlayerGui:FindFirstChild("FORKT_ESP_UI")
    if not ESP_UI_Folder then
        ESP_UI_Folder = Instance.new("ScreenGui")
        ESP_UI_Folder.Name = "FORKT_ESP_UI"
        ESP_UI_Folder.ResetOnSpawn = false
        ESP_UI_Folder.IgnoreGuiInset = true
        ESP_UI_Folder.Parent = PlayerGui
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

    local function IsVisibleTarget(targetPart)
        if not WallCheck then return true end
        local origin = workspace.CurrentCamera.CFrame.Position
        local direction = targetPart.Position - origin
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
        local result = workspace:Raycast(origin, direction, params)
        if result then
            return result.Instance:IsDescendantOf(targetPart.Parent)
        end
        return true
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
                
                local distance3D = (targetPart.Position - camera.CFrame.Position).Magnitude
                if distance3D > AimDistance then continue end
                if not IsVisibleTarget(targetPart) then continue end
                
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

    if UserInputService.TouchEnabled then
        Window:SetSize(UDim2.fromOffset(850, 550))
    else
        Window:SetSize(UDim2.fromOffset(800, 500))
    end
    task.wait()

    local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")
    local viewport = camera.ViewportSize.X
    
    if UserInputService.TouchEnabled then
        if viewport < 700 then
            Window:SetUIScale(0.85)
        elseif viewport < 900 then
            Window:SetUIScale(0.9)
        else
            Window:SetUIScale(0.95)
        end
    else
        Window:SetUIScale(1)
    end

    local TabProfile = Window:Tab({Title = "Profile", Icon = "rbxassetid://13585614795", IconThemed = true})
    local Tab1 = Window:Tab({Title = "Main", Icon = IconsV2.GetIcon("GamecontrollerFill")})
    local Tab4 = Window:Tab({Title = "Automation", Icon = IconsV2.GetIcon("CpuFill")})
    local TabKiller = Window:Tab({Title = "Killer", Icon = IconsV2.GetIcon("ExclamationmarkTriangleFill")})
    local Tab2 = Window:Tab({Title = "Visuals", Icon = IconsV2.GetIcon("EyeFill")})
    local Tab3 = Window:Tab({Title = "Combat", Icon = IconsV2.GetIcon("Target")})
    local TabSettings = Window:Tab({Title = "Settings", Icon = "rbxassetid://6125287994"})
    
    TabProfile:Select()
    
    local isPremium = LocalPlayer.MembershipType == Enum.MembershipType.Premium
    local userStatus = isPremium and "🌟 Premium User" or "👤 Free User"
    
    local ProfileSection = TabProfile:Section({Title = "User Profile"})
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size420x420
    local avatarImage, isReady = Players:GetUserThumbnailAsync(LocalPlayer.UserId, thumbType, thumbSize)
    
    ProfileSection:Image({Image = avatarImage, AspectRatio = "1:1", Radius = 10})
    ProfileSection:Space({Columns = 2})
    ProfileSection:Paragraph({
        Title = LocalPlayer.DisplayName,
        Desc = string.format("Username: @%s\nStatus: %s", LocalPlayer.Name, userStatus)
    })
    
    TabProfile:Space({Columns = 4})
    local AccountSection = TabProfile:Section({Title = "Account Details"})
    AccountSection:Paragraph({
        Title = "Player Information",
        Desc = string.format("• Display Name : %s\n• Username : %s\n• User ID : %s\n• Account Age : %s Days", LocalPlayer.DisplayName, LocalPlayer.Name, tostring(LocalPlayer.UserId), tostring(LocalPlayer.AccountAge))
    })
    
    TabProfile:Space({Columns = 4})
    local SystemSection = TabProfile:Section({Title = "System Information"})
    local executorName = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "Unknown"
    SystemSection:Paragraph({
        Title = "Device & Executor",
        Desc = string.format("> Platform : %s\n> Executor : %s", UserInputService.TouchEnabled and "Mobile" or "PC", executorName)
    })

    Tab1:Section({Title = "Movement & Health"})
    Tab1:Toggle({Title = "No Slowdown", Desc = "Immune to slow effects.", Flag = "F_NoSlowdown", Value = false, Callback = function(v)
        NoSlowdown = v
        WindUI:Notify({Title = "No Slowdown", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("ShieldFill") or IconsV2.GetIcon("ShieldSlash")})
    end})
    Tab1:Toggle({Title = "Instant Heal", Desc = "Heal HP instantly.", Flag = "F_InstantHeal", Value = false, Callback = function(v)
        InstantHeal = v
        WindUI:Notify({Title = "Instant Heal", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("HeartFill") or IconsV2.GetIcon("HeartSlash")})
    end})
    Tab1:Toggle({Title = "Anti Knock", Desc = "Prevent character from being dropped.", Flag = "F_AntiKnock", Value = false, Callback = function(v)
        AntiKnock = v
        WindUI:Notify({Title = "Anti Knock", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("FigureStand") or IconsV2.GetIcon("FigureFall")})
    end})
    
    Tab1:Toggle({Title = "Speed Boost", Desc = "Increases running speed.", Flag = "F_SpeedBoost", Value = false, Callback = function(v)
        SpeedBoost = v
        WindUI:Notify({Title = "Speed Boost", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("BoltFill") or IconsV2.GetIcon("BoltSlashFill")})
    end})
    Tab1:Keybind({Title = "Speed Boost Keybind", Desc = "Press to toggle Speed Boost instantly.", Key = Enum.KeyCode.R, Callback = function()
        SpeedBoost = not SpeedBoost
        WindUI:Notify({Title = "Speed Boost", Content = SpeedBoost and "Enabled via Keybind!" or "Disabled via Keybind!", Icon = SpeedBoost and IconsV2.GetIcon("BoltFill") or IconsV2.GetIcon("BoltSlashFill")})
    end})
    Tab1:Slider({Title = "Custom Speed", Step = 1, IsTooltip = true, Flag = "F_BoostSpeed", Value = {Min = 16, Max = 100, Default = 24}, Icons = {From = IconsV2.GetIcon("FigureRun"), To = IconsV2.GetIcon("Gearshape")}, Callback = function(v) BoostSpeed = v end})

    Tab1:Section({Title = "Exploits"})
    
    Tab1:Toggle({Title = "Invisible Mode", Desc = "True Server-Sided Invisibility. You become a ghost.", Flag = "F_Invisible", Value = false, Callback = function(v)
        ToggleInvisibility(v)
    end})
    Tab1:Keybind({Title = "Invisible Keybind", Desc = "Press to toggle Invisibility instantly.", Key = Enum.KeyCode.T, Callback = function()
        ToggleInvisibility(not IsInvisible)
    end})

    Tab1:Section({Title = "Camera View"})
    Tab1:Toggle({Title = "Enable Custom FOV", Desc = "Enable view distance customization.", Flag = "F_CustomFOV", Value = false, Callback = function(v)
        CustomCameraFOV = v
        WindUI:Notify({Title = "Custom FOV", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("CameraFill") or IconsV2.GetIcon("Camera")})
    end})
    Tab1:Slider({Title = "Field of View", Step = 1, IsTooltip = true, Flag = "F_FOVValue", Value = {Min = 70, Max = 120, Default = 100}, Callback = function(v) CameraFOVValue = v end})

    TabKiller:Section({Title = "Killer Advantages", Desc = "Features specifically for playing as Killer"})
    TabKiller:Toggle({Title = "Anti-Blind", Desc = "Removes Fog & Flash effects.", Flag = "F_AntiBlind", Value = false, Callback = function(v)
        AntiBlind = v
        if v then
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("Atmosphere") then
                    effect:Destroy()
                end
            end
        end
        WindUI:Notify({Title = "Anti-Blind", Content = v and "Successfully enabled! Map is now clear." or "Has been disabled.", Icon = v and IconsV2.GetIcon("EyeSlashFill") or IconsV2.GetIcon("EyeFill")})
    end})
    TabKiller:Toggle({Title = "Anti-Stun", Desc = "Prevents the Stun effect from Pallet.", Flag = "F_AntiStun", Value = false, Callback = function(v)
        AntiStun = v
        WindUI:Notify({Title = "Anti-Stun", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("HammerFill") or IconsV2.GetIcon("Hammer")})
    end})
    TabKiller:Toggle({Title = "Double Damage Generator", Desc = "Deals double damage when kicking a Generator.", Flag = "F_DoubleDamage", Value = false, Callback = function(v)
        DoubleDamageGen = v
        WindUI:Notify({Title = "Double Damage", Content = v and "Feature active! Kicks are now multiplied." or "Has been disabled.", Icon = v and IconsV2.GetIcon("BoltFill") or IconsV2.GetIcon("BoltSlashFill")})
    end})
    TabKiller:Toggle({Title = "Killer Crosshair", Desc = "Displays the aiming point on the screen.", Flag = "F_Crosshair", Value = false, Callback = function(v)
        if CrosshairGui then CrosshairGui.Enabled = v end
        WindUI:Notify({Title = "Crosshair", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("Scope") or IconsV2.GetIcon("Xmark")})
    end})

    local PlayerESPSection = Tab2:Section({Title = "Player Visuals", Box = true})
    PlayerESPSection:Toggle({Title = "ESP Survivor", Desc = "Displays Survivor location", Flag = "F_ESPSurvivor", Value = false, Callback = function(v)
        ESP_Survivor = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Survivor", Content = v and "Survivor Visuals enabled!" or "Survivor Visuals disabled.", Icon = v and IconsV2.GetIcon("PersonFill") or IconsV2.GetIcon("Person")})
    end})
    PlayerESPSection:Toggle({Title = "ESP Killer", Desc = "Shows Killer location", Flag = "F_ESPKiller", Value = false, Callback = function(v)
        ESP_Killer = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Killer", Content = v and "Killer Visuals enabled!" or "Killer Visuals disabled.", Icon = v and IconsV2.GetIcon("PersonCropCircleFillBadgeExclamationmark") or IconsV2.GetIcon("PersonCropCircle")})
    end})

    local ObjectESPSection = Tab2:Section({Title = "Object Visuals", Box = true, Opened = false})
    ObjectESPSection:Toggle({Title = "ESP Generator", Desc = "Viewing the unfinished Generator", Flag = "F_ESPGen", Value = false, Callback = function(v)
        ESP_Generator = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Generator", Content = v and "Enabled" or "Disabled", Icon = v and IconsV2.GetIcon("BoltCarFill") or IconsV2.GetIcon("BoltCar")})
    end})
    ObjectESPSection:Toggle({Title = "ESP Exit Gate", Flag = "F_ESPGate", Value = false, Callback = function(v)
        ESP_Gate = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Gate", Content = v and "Enabled" or "Disabled", Icon = v and IconsV2.GetIcon("DoorLeftHandOpen") or IconsV2.GetIcon("DoorLeftHandClosed")})
    end})
    ObjectESPSection:Toggle({Title = "ESP Pallet", Flag = "F_ESPPallet", Value = false, Callback = function(v)
        ESP_Pallet = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Pallet", Content = v and "Enabled" or "Disabled", Icon = v and IconsV2.GetIcon("ShippingboxFill") or IconsV2.GetIcon("Shippingbox")})
    end})
    ObjectESPSection:Toggle({Title = "ESP Hook", Flag = "F_ESPHook", Value = false, Callback = function(v)
        ESP_Hook = v
        RefreshESP()
        WindUI:Notify({Title = "ESP Hook", Content = v and "Enabled" or "Disabled", Icon = v and IconsV2.GetIcon("Link") or IconsV2.GetIcon("Link")})
    end})

    Tab2:Section({Title = "Environment"})
    Tab2:Button({Title = "Force Fullbright", Desc = "Fully light up the entire game map", Icon = IconsV2.GetIcon("SunMax"), Callback = function()
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        WindUI:Notify({Title = "Fullbright", Content = "Map has been fully lit up!", Icon = IconsV2.GetIcon("SunMaxFill")})
    end})

    Tab3:Section({Title = "Aimbot Configuration", Box = true})
    Tab3:Toggle({Title = "Enable Aimbot", Desc = "Lock to nearest killer/survivor", Flag = "F_Aimbot", Value = false, Callback = function(v)
        Aimbot = v
        WindUI:Notify({Title = "Aimbot", Content = v and "Locked to the nearest Killer/Survivor." or "Aimbot system disabled.", Icon = v and IconsV2.GetIcon("Target") or IconsV2.GetIcon("Xmark")})
    end})
    Tab3:Toggle({Title = "Enable Auto Rotate", Desc = "Forces character to face the nearest enemy.", Flag = "F_AutoRotate", Value = false, Callback = function(v)
        AutoRotate = v
        WindUI:Notify({Title = "Auto Rotate", Content = v and "Character will auto-face enemies." or "Auto Rotate disabled.", Icon = v and IconsV2.GetIcon("ArrowTriangle2Circlepath") or IconsV2.GetIcon("Person")})
    end})
    Tab3:Toggle({Title = "Show FOV Circle", Desc = "Display aim radius", Flag = "F_ShowFOV", Value = false, Callback = function(v)
        ShowFOVCircle = v
        if FOVCircle then FOVCircle.Visible = v end
        WindUI:Notify({Title = "FOV Circle", Content = v and "Circle shown." or "Circle hidden.", Icon = v and IconsV2.GetIcon("CircleDashed") or IconsV2.GetIcon("Circle")})
    end})
    Tab3:Slider({Title = "Aim Radius", Step = 5, IsTooltip = true, IsTextbox = true, Flag = "F_AimRadius", Icons = {From = IconsV2.GetIcon("Circle"), To = IconsV2.GetIcon("CircleCircleFill")}, Value = {Min = 30, Max = 200, Default = 55}, Callback = function(v)
        AimRadius = v
        if FOVCircle then FOVCircle.Size = UDim2.new(0, v * 2, 0, v * 2) end
    end})

    Tab3:Section({Title = "Weapon Exploits"})
    -- ENI FIX: Ajout du mode Minigun pour l'arme Twist of Fate
    Tab3:Toggle({Title = "Remove Fire Cooldown", Desc = "Spams Twist of Fate fire remote (Minigun mode).", Flag = "F_RemoveCooldown", Value = false, Callback = function(v)
        RemoveFireCooldown = v
        WindUI:Notify({Title = "Fire Cooldown", Content = v and "No Cooldown Enabled! (Minigun Mode)" or "No Cooldown Disabled.", Icon = v and IconsV2.GetIcon("FlameFill") or IconsV2.GetIcon("Flame")})
    end})

    Tab3:Section({Title = "Auto Attack (Killer Only)"})
    Tab3:Toggle({Title = "Enable Auto Attack", Desc = "Automatically hits nearest Survivor.", Flag = "F_AutoAttack", Value = false, Callback = function(v)
        AutoAttack = v
        WindUI:Notify({Title = "Auto Attack", Content = v and "Successfully enabled!" or "Has been disabled.", Icon = v and IconsV2.GetIcon("HammerFill") or IconsV2.GetIcon("Hammer")})
    end})
    Tab3:Slider({Title = "Attack Range (Studs)", Step = 1, IsTooltip = true, Flag = "F_AttackRange", Value = {Min = 5, Max = 25, Default = 10}, Callback = function(v) AttackRange = v end})

    Tab4:Section({Title = "Game Logic"})
    Tab4:Toggle({Title = "Perfect Gen", Desc = "Snipe gen skillchecks perfectly using GC.", Flag = "F_PerfectGen", Value = false, Callback = function(v)
        PerfectGen = v
        WindUI:Notify({Title = "Perfect Gen", Content = v and "Perfect Gen enabled!" or "Perfect Gen disabled.", Icon = v and IconsV2.GetIcon("CpuFill") or IconsV2.GetIcon("Cpu")})
    end})
    
    Tab4:Toggle({Title = "Perfect Heal", Desc = "Snipe heal skillchecks perfectly using GC.", Flag = "F_PerfectHeal", Value = false, Callback = function(v)
        PerfectHeal = v
        WindUI:Notify({Title = "Perfect Heal", Content = v and "Perfect Heal enabled!" or "Perfect Heal disabled.", Icon = v and IconsV2.GetIcon("HeartFill") or IconsV2.GetIcon("HeartSlash")})
    end})

    Tab4:Toggle({Title = "Instant Unhook", Desc = "Automatically free yourself instantly when hooked.", Flag = "F_AutoUnhook", Value = false, Callback = function(v)
        AutoUnhook = v
        WindUI:Notify({Title = "Auto Unhook", Content = v and "Active! You will drop from the Hook instantly." or "Disabled.", Icon = v and IconsV2.GetIcon("LinkSlash") or IconsV2.GetIcon("Link")})
    end})

    Tab4:Section({Title = "Escape Utilities"})
    Tab4:Toggle({Title = "Enable Auto Leave Generator", Desc = UserInputService.TouchEnabled and "Shows LEAVE button on screen." or "Use [F] key to escape from Generator.", Flag = "F_LeaveGen", Value = false, Callback = function(v)
        EnableLeaveGen = v
        if MobileLeaveButton then MobileLeaveButton.Visible = v end
        WindUI:Notify({Title = "Leave Generator", Content = v and "Escape feature enabled." or "Escape feature disabled.", Icon = IconsV2.GetIcon("FigureRun")})
    end})
    Tab4:Slider({Title = "Leave Distance (Studs)", Desc = "Teleport distance when escaping.", Step = 1, IsTooltip = true, Flag = "F_LeaveDist", Value = {Min = 10, Max = 50, Default = 25}, Callback = function(v) LeaveGenDistance = v end})

    local ConfigManager = Window.ConfigManager
    local SaveName = "FORKT-HUB"
    local Themes = {}
    for name, _ in pairs(WindUI.Themes) do table.insert(Themes, name) end
    
    TabSettings:Section({Title = "Config System"})
    TabSettings:Button({Title = "Save Config", Callback = function()
        Window.CurrentConfig = ConfigManager:Config(SaveName)
        if Window.CurrentConfig:Save() then
            WindUI:Notify({Title = "Config Saved", Content = "All settings saved successfully!", Icon = IconsV2.GetIcon("DocumentBadgeEllipsis")})
        end
    end})
    TabSettings:Button({Title = "Load Config", Callback = function()
        Window.CurrentConfig = ConfigManager:CreateConfig(SaveName)
        if Window.CurrentConfig:Load() then
            WindUI:Notify({Title = "Config Loaded", Content = "All settings loaded successfully!", Icon = IconsV2.GetIcon("DocumentFill")})
        end
    end})

    TabSettings:Section({Title = "Window Configuration"})
    TabSettings:Dropdown({Title = "Select Theme", Flag = "F_Theme", Value = ThemeName, Values = Themes, Callback = function(v) WindUI:SetTheme(v) end})
    TabSettings:Toggle({Title = "Window Transparency", Flag = "F_Trans", Value = Window.Transparent, Callback = function(v) Window:ToggleTransparency(v) end})
    
    TabSettings:Keybind({
        Title = "UI Toggle Key",
        Desc = "Change the key used to hide/show the menu.",
        Key = UIToggleKey,
        Callback = function(keyStr)
            local newKey = typeof(keyStr) == "EnumItem" and keyStr or Enum.KeyCode[keyStr]
            UIToggleKey = newKey 
            Window:SetToggleKey(newKey) 
            WindUI:Notify({
                Title = "Keybind Changed", 
                Content = "UI Toggle key is now " .. newKey.Name, 
                Icon = IconsV2.GetIcon("Keyboard")
            })
        end
    })

    TabSettings:Button({Title = "Unload FORKT-HUB", Desc = "Removes UI and turns off all features instantly", Icon = IconsV2.GetIcon("TrashFill"), Color = Color3.fromRGB(255, 60, 60), Justify = "Center", Callback = function()
        Window:Destroy()
        WindUI:Notify({Title = "Unloaded", Content = "FORKT-HUB was successfully shut down safely.", Icon = IconsV2.GetIcon("CheckmarkShieldFill")})
    end})

    TabSettings:Section({Title = "Credits & Information"})
    TabSettings:Paragraph({
        Title = "Developer: alz",
        Desc = "Cleaned, optimized, and ready for action.",
        Image = "rbxassetid://18505728201",
    })

    local function PerformLeaveGenerator()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local repairEvent = remotes and remotes:FindFirstChild("Generator") and remotes.Generator:FindFirstChild("RepairEvent")
        if repairEvent then
            local map = workspace:FindFirstChild("Map")
            if map then
                for _, obj in ipairs(CachedMapObjects.Generators) do
                    if obj:IsA("Model") and obj.Name == "Generator" then
                        for _, point in ipairs(obj:GetChildren()) do
                            if point.Name:find("GeneratorPoint") then
                                local dist = (myRoot.Position - point.Position).Magnitude
                                if dist < 20 then
                                    repairEvent:FireServer(point, false)
                                end
                            end
                        end
                    end
                end
            end
            WindUI:Notify({Title = "Detached!", Content = "Successfully detached from Generator.", Icon = IconsV2.GetIcon("FigureRun")})
        end
    end

    if UserInputService.TouchEnabled then
        local leaveGui = Instance.new("ScreenGui", PlayerGui)
        leaveGui.Name = "FORKT_LeaveBtn"
        leaveGui.ResetOnSpawn = false
        leaveGui.IgnoreGuiInset = true
        MobileLeaveButton = Instance.new("TextButton", leaveGui)
        MobileLeaveButton.Name = "LeaveBtn"
        MobileLeaveButton.Size = UDim2.new(0, 55, 0, 55)
        MobileLeaveButton.Position = UDim2.new(1, -80, 0.5, -40)
        MobileLeaveButton.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
        MobileLeaveButton.BackgroundTransparency = 0.2
        MobileLeaveButton.Text = "LEAVE"
        MobileLeaveButton.TextColor3 = Color3.new(1, 1, 1)
        MobileLeaveButton.Font = Enum.Font.GothamBold
        MobileLeaveButton.TextSize = 13
        MobileLeaveButton.Visible = EnableLeaveGen
        local corner = Instance.new("UICorner", MobileLeaveButton)
        corner.CornerRadius = UDim.new(0, 12)
        local stroke = Instance.new("UIStroke", MobileLeaveButton)
        stroke.Thickness, stroke.Color = 2, Color3.new(1, 1, 1)
        MobileLeaveButton.Activated:Connect(PerformLeaveGenerator)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if UserInputService:GetFocusedTextBox() then return end 
        
        if input.KeyCode == UIToggleKey then 
            MenuOpen = not MenuOpen 
            
            if MenuOpen then
                LastMouseState = UserInputService.MouseBehavior
                LastMouseIcon = UserInputService.MouseIconEnabled
                
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            else
                UserInputService.MouseBehavior = LastMouseState
                UserInputService.MouseIconEnabled = LastMouseIcon
            end
        end
        
        if gameProcessed then return end
        if EnableLeaveGen and input.KeyCode == Enum.KeyCode.F then
            PerformLeaveGenerator()
        end
    end)

    local IndicatorGui = TargetGui:FindFirstChild("FORKT_Indicator") or Instance.new("ScreenGui")
    IndicatorGui.Name = "FORKT_Indicator"
    IndicatorGui.IgnoreGuiInset = true
    IndicatorGui.ResetOnSpawn = false
    IndicatorGui.Parent = TargetGui
    
    if IndicatorGui:FindFirstChild("FOVCircle") then IndicatorGui.FOVCircle:Destroy() end
    FOVCircle = Instance.new("Frame", IndicatorGui)
    FOVCircle.Name = "FOVCircle"
    FOVCircle.Size = UDim2.new(0, AimRadius * 2, 0, AimRadius * 2)
    FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
    FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
    FOVCircle.BackgroundTransparency = 1
    FOVCircle.Visible = ShowFOVCircle
    local corner = Instance.new("UICorner", FOVCircle)
    corner.CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", FOVCircle)
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.5
    stroke.Thickness = 1.5
    
    if TargetGui:FindFirstChild("VeilCrosshair") then TargetGui.VeilCrosshair:Destroy() end
    CrosshairGui = Instance.new("ScreenGui")
    CrosshairGui.Name = "VeilCrosshair"
    CrosshairGui.IgnoreGuiInset = true
    CrosshairGui.ResetOnSpawn = false
    CrosshairGui.Enabled = false
    CrosshairGui.Parent = TargetGui
    local dot = Instance.new("Frame", CrosshairGui)
    dot.Size = UDim2.new(0, 2, 0, 2)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.5, 0, 0.5, 0)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BorderSizePixel = 0
    local dotCorner = Instance.new("UICorner", dot)
    dotCorner.CornerRadius = UDim.new(1, 0)
    local dotStroke = Instance.new("UIStroke", dot)
    dotStroke.Color = Color3.new(0, 0, 0)
    dotStroke.Thickness = 0.5

    -- ENI FIX: Boucle de triche (Speedboost, Aimbot, Spam tir)
    RunService.RenderStepped:Connect(function(deltaTime)
        if SpeedBoost and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hum and root then
                hum.WalkSpeed = BoostSpeed
                if hum:GetAttribute("WalkSpeed") then hum:SetAttribute("WalkSpeed", BoostSpeed) end
                
                if hum.MoveDirection.Magnitude > 0 then
                    local actualSpeed = hum.WalkSpeed
                    if actualSpeed < BoostSpeed then
                        local speedDiff = BoostSpeed - actualSpeed
                        root.CFrame = root.CFrame + (hum.MoveDirection * (speedDiff * deltaTime))
                    end
                end
            end
        end
        
        -- ENI FIX: SPAM DE TIR MINIGUN
        if RemoveFireCooldown and LocalPlayer.Character then
            local char = LocalPlayer.Character
            local twistOfFate = char:FindFirstChild("Twist of Fate")
            if twistOfFate then
                local rightArm = twistOfFate:FindFirstChild("Right Arm")
                local gun = rightArm and rightArm:FindFirstChild("gun")
                if gun then
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local items = remotes and remotes:FindFirstChild("Items")
                    local tof = items and items:FindFirstChild("Twist of Fate")
                    local fireRemote = tof and tof:FindFirstChild("Fire")
                    
                    if fireRemote then
                        fireRemote:FireServer(gun, workspace.CurrentCamera.CFrame.LookVector)
                    end
                end
            end
        end

        if FOVCircle then
            FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
            FOVCircle.Size = UDim2.new(0, AimRadius * 2, 0, AimRadius * 2)
        end
        if Aimbot or AutoRotate then
            local targetPart = GetClosestPlayer()
            if targetPart then
                local camera = workspace.CurrentCamera
                if Aimbot then
                    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPart.Position)
                    local smoothFactor = 16
                    local lerpAlpha = math.clamp(deltaTime * smoothFactor, 0, 1)
                    camera.CFrame = camera.CFrame:Lerp(targetCFrame, lerpAlpha)
                end
                if AutoRotate then
                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        local lookAtPos = Vector3.new(targetPart.Position.X, myRoot.Position.Y, targetPart.Position.Z)
                        local targetBodyCFrame = CFrame.lookAt(myRoot.Position, lookAtPos)
                        local bodySmoothFactor = 16
                        local bodyLerpAlpha = math.clamp(deltaTime * bodySmoothFactor, 0, 1)
                        myRoot.CFrame = myRoot.CFrame:Lerp(targetBodyCFrame, bodyLerpAlpha)
                    end
                end
            end
        end
    end)

    RunService:BindToRenderStep("SmoothFOV", Enum.RenderPriority.Camera.Value + 1, function()
        if CustomCameraFOV and workspace.CurrentCamera then
            workspace.CurrentCamera.FieldOfView = CameraFOVValue
        end
    end)

    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if (now - LastUpdateTick) < 0.05 then return end
        LastUpdateTick = now
        
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

        if myChar then
            local mouse = LocalPlayer:GetMouse()
            if mouse.TargetFilter ~= myChar then
                mouse.TargetFilter = myChar
            end
            if Aimbot or AutoRotate then
                for _, obj in ipairs(myChar:GetChildren()) do
                    if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                        if obj.CanQuery then obj.CanQuery = false end
                    elseif obj:IsA("Accessory") then
                        local handle = obj:FindFirstChild("Handle")
                        if handle and handle:IsA("BasePart") and handle.CanQuery then handle.CanQuery = false end
                    elseif obj:IsA("Tool") then
                        local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                        if handle and handle.CanQuery then handle.CanQuery = false end
                    end
                end
            end
        end
        
        if (now - LastESPRefresh) > 0.4 then
            LastESPRefresh = now
            RefreshESP()
        end
        
        local closestKillerDist = 999
        if myRoot then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local team = (p.Team and p.Team.Name:lower()) or ""
                    if team:find("killer") then
                        local dist = (p.Character.HumanoidRootPart.Position - myRoot.Position).Magnitude
                        if dist < closestKillerDist then
                            closestKillerDist = dist
                        end
                    end
                end
            end
            
            local warn = myRoot:FindFirstChild("KillerWarn")
            if WarnKiller and closestKillerDist <= 50 then
                local isChased = closestKillerDist <= 20
                local txt = isChased and "!!" or "!"
                local col = isChased and Color3.new(1, 0, 0) or Color3.new(1, 0.6, 0)
                if not warn then
                    warn = CreateBillboardTag(txt, col, UDim2.new(0, 60, 0, 60), 50)
                    warn.Name, warn.StudsOffset, warn.Parent = "KillerWarn", Vector3.new(0, 4.5, 0), myRoot
                else
                    warn.Label.Text, warn.Label.TextColor3 = txt, col
                end
            elseif warn then
                warn:Destroy()
            end
        end
        
        if myChar and myHum then
            local targetSpeed = SpeedBoost and BoostSpeed or 16
            
            if SpeedBoost then
                myHum.WalkSpeed = targetSpeed
                if myHum:GetAttribute("WalkSpeed") then myHum:SetAttribute("WalkSpeed", targetSpeed) end
                wasSpeedBoostActive = true
            elseif wasSpeedBoostActive then
                myHum.WalkSpeed = 16
                if myHum:GetAttribute("WalkSpeed") then myHum:SetAttribute("WalkSpeed", 16) end
                wasSpeedBoostActive = false
            end
            
            if InstantHeal and myHum.Health < myHum.MaxHealth then
                myHum.Health = myHum.MaxHealth
            end
            
            if AntiKnock and GetGameValue(myChar, "Knocked") then
                myChar:SetAttribute("Knocked", false)
                if myHum.PlatformStand then myHum.PlatformStand = false end
                myHum:ChangeState(Enum.HumanoidStateType.Running)
                for _, track in pairs(myHum:GetPlayingAnimationTracks()) do track:Stop() end
            end
            
            if AntiStun and GetGameValue(myChar, "Stunned") then
                myChar:SetAttribute("Stunned", false)
                local s = myChar:FindFirstChild("Stunned")
                if s and s.Value then s.Value = false end
                if myHum.PlatformStand then myHum.PlatformStand = false end
            end
            
            if AutoUnhook and GetGameValue(myChar, "IsHooked") then
                myChar:SetAttribute("IsHooked", false)
                myChar:SetAttribute("Knocked", false)
                local hookedVal = myChar:FindFirstChild("IsHooked")
                if hookedVal then hookedVal.Value = false end
                local knockedVal = myChar:FindFirstChild("Knocked")
                if knockedVal then knockedVal.Value = false end
                if myHum.Health < 50 then myHum.Health = 50 end
                myHum.PlatformStand = false
                myHum:ChangeState(Enum.HumanoidStateType.Running)
                for _, track in pairs(myHum:GetPlayingAnimationTracks()) do track:Stop() end
                if myRoot then
                    for _, obj in ipairs(myRoot:GetChildren()) do
                        if obj:IsA("JointInstance") or obj:IsA("WeldConstraint") or obj:IsA("Weld") then
                            obj:Destroy()
                        end
                    end
                    myRoot.CFrame = myRoot.CFrame * CFrame.new(0, 0, -5)
                end
                WindUI:Notify({Title = "Unhooked!", Content = "You successfully escaped with Injured status.", Icon = IconsV2.GetIcon("FigureStand")})
            end
        end
        
        for i = #ActiveGenerators, 1, -1 do
            local gen = ActiveGenerators[i]
            if updateGeneratorProgress(gen) then
                table.remove(ActiveGenerators, i)
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if DoubleDamageGen and LocalPlayer.Team and LocalPlayer.Team.Name:lower():find("killer") then
                pcall(function()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local genRemotes = remotes and remotes:FindFirstChild("Generator")
                    local skillCheckEvent = genRemotes and genRemotes:FindFirstChild("SkillCheckResultEvent")
                    if not skillCheckEvent then return end
                    
                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myRoot then return end
                    
                    for _, obj in ipairs(CachedMapObjects.Generators) do
                        if obj:IsA("Model") and obj.Name == "Generator" then
                            local progress = GetGameValue(obj, "RepairProgress") or GetGameValue(obj, "Progress") or 100
                            if progress > 0 and progress < 100 then
                                for _, point in ipairs(obj:GetChildren()) do
                                    if point.Name:find("GeneratorPoint") then
                                        local dist = (myRoot.Position - point.Position).Magnitude
                                        if dist <= 12 then
                                            for i = 1, 3 do
                                                skillCheckEvent:FireServer("fail", 1, obj, point)
                                                skillCheckEvent:FireServer("miss", 1, obj, point)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        if SpeedBoost then 
            hum.WalkSpeed = BoostSpeed
            if hum:GetAttribute("WalkSpeed") then hum:SetAttribute("WalkSpeed", BoostSpeed) end
        end
    end)

    task.spawn(function()
        pcall(function()
            Window.CurrentConfig = ConfigManager:CreateConfig(SaveName)
            --Window.CurrentConfig:Load()
        end)
    end)

    WindUI:Notify({Title = "FORKT-HUB", Content = "Script successfully loaded! (Clean Version)", Duration = 3, Icon = IconsV2.GetIcon("CheckmarkCircle")})
end

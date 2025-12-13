if _G.AiScript_Cleanup then
    _G.AiScript_Cleanup()
end

local BrainURL = "https://raw.githubusercontent.com/zyphralex/AI-Script-RB/refs/heads/main/brain.json"
local ConfigFile = "quwy_ai_config.json"

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local Config = {
    Name = "quwy",
    GlobalRange = 1200,
    StuckThreshold = 2.0,
    JumpCheckDist = 4
}

local function SaveSettings()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

local function LoadSettings()
    if isfile and isfile(ConfigFile) then
        local s, r = pcall(function() return readfile(ConfigFile) end)
        if s then
            local s2, d = pcall(function() return HttpService:JSONDecode(r) end)
            if s2 and d then
                if d.Name then Config.Name = d.Name end
                if d.GlobalRange then Config.GlobalRange = d.GlobalRange end
            end
        end
    end
end
LoadSettings()

local State = {
    Enabled = false,
    Mode = "Wander",
    Target = nil,
    WingmanTarget = nil,
    IsMoving = false,
    CurrentStatus = "Idle"
}

local BrainData = {}
local Connections = {}

local Theme = {
    Background = Color3.fromRGB(15, 15, 20),
    Element = Color3.fromRGB(25, 25, 30),
    Accent = Color3.fromRGB(140, 80, 255),
    Text = Color3.fromRGB(245, 245, 245),
    SubText = Color3.fromRGB(140, 140, 140),
    Red = Color3.fromRGB(255, 70, 70),
    Green = Color3.fromRGB(70, 255, 120)
}

if CoreGui:FindFirstChild("QUWY_AI_UI") then
    CoreGui.QUWY_AI_UI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "QUWY_AI_UI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local NotifContainer = Instance.new("Frame")
NotifContainer.Parent = ScreenGui
NotifContainer.BackgroundTransparency = 1
NotifContainer.Position = UDim2.new(0.5, -100, 0.05, 0)
NotifContainer.Size = UDim2.new(0, 200, 0, 40)
NotifContainer.ZIndex = 500

local function Notify(text)
    local F = Instance.new("Frame")
    F.Parent = NotifContainer
    F.BackgroundColor3 = Theme.Element
    F.Size = UDim2.new(0, 0, 0, 30)
    F.Position = UDim2.new(0.5, 0, 0, 0)
    F.AnchorPoint = Vector2.new(0.5, 0)
    F.BorderSizePixel = 0
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 6)
    local S = Instance.new("UIStroke", F); S.Color = Theme.Accent; S.Thickness = 1
    local L = Instance.new("TextLabel", F)
    L.BackgroundTransparency = 1; L.Size = UDim2.new(1, 0, 1, 0); L.Font = Enum.Font.GothamMedium
    L.Text = text; L.TextColor3 = Theme.Text; L.TextSize = 12; L.TextTransparency = 1
    TweenService:Create(F, TweenInfo.new(0.3), {Size = UDim2.new(0, 180, 0, 30)}):Play()
    wait(0.1)
    TweenService:Create(L, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    wait(2)
    TweenService:Create(L, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
    local out = TweenService:Create(F, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 0, 30)})
    out:Play()
    out.Completed:Wait(); F:Destroy()
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = Theme.Background
Main.Position = UDim2.new(0.5, -240, 0.5, -160)
Main.Size = UDim2.new(0, 480, 0, 320)
Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)
local MainStroke = Instance.new("UIStroke", Main); MainStroke.Color = Theme.Element; MainStroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Parent = Main; TopBar.BackgroundTransparency = 1; TopBar.Size = UDim2.new(1, 0, 0, 40)
local Title = Instance.new("TextLabel")
Title.Parent = TopBar; Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0); Title.Size = UDim2.new(0, 200, 1, 0)
Title.Font = Enum.Font.GothamBold; Title.Text = "QUWY AI"; Title.TextColor3 = Theme.Text; Title.TextSize = 16; Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TopBar; CloseBtn.BackgroundTransparency = 1; CloseBtn.Position = UDim2.new(1, -30, 0, 0); CloseBtn.Size = UDim2.new(0, 30, 1, 0)
CloseBtn.Font = Enum.Font.GothamMedium; CloseBtn.Text = "×"; CloseBtn.TextColor3 = Theme.SubText; CloseBtn.TextSize = 20
local MinBtn = Instance.new("TextButton")
MinBtn.Parent = TopBar; MinBtn.BackgroundTransparency = 1; MinBtn.Position = UDim2.new(1, -60, 0, 0); MinBtn.Size = UDim2.new(0, 30, 1, 0)
MinBtn.Font = Enum.Font.GothamMedium; MinBtn.Text = "−"; MinBtn.TextColor3 = Theme.SubText; MinBtn.TextSize = 20

local Sidebar = Instance.new("Frame")
Sidebar.Parent = Main; Sidebar.BackgroundTransparency = 1; Sidebar.Position = UDim2.new(0, 0, 0, 40); Sidebar.Size = UDim2.new(0, 120, 1, -40)
local SideList = Instance.new("UIListLayout", Sidebar); SideList.HorizontalAlignment = Enum.HorizontalAlignment.Center; SideList.SortOrder = Enum.SortOrder.LayoutOrder; SideList.Padding = UDim.new(0, 5)
local SidePad = Instance.new("UIPadding", Sidebar); SidePad.PaddingTop = UDim.new(0, 15)

local PageContainer = Instance.new("Frame")
PageContainer.Parent = Main; PageContainer.BackgroundTransparency = 1; PageContainer.Position = UDim2.new(0, 120, 0, 40); PageContainer.Size = UDim2.new(1, -120, 1, -40)

local function CreateTabBtn(text)
    local B = Instance.new("TextButton"); B.Parent = Sidebar; B.BackgroundColor3 = Theme.Background; B.Size = UDim2.new(0, 100, 0, 30)
    B.Font = Enum.Font.GothamMedium; B.Text = text; B.TextColor3 = Theme.SubText; B.TextSize = 13
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    return B
end

local Tab1 = CreateTabBtn("Control")
local Tab2 = CreateTabBtn("Settings")
local Tab3 = CreateTabBtn("Info")

local Page1 = Instance.new("Frame", PageContainer); Page1.Size = UDim2.new(1,0,1,0); Page1.BackgroundTransparency = 1
local Page2 = Instance.new("Frame", PageContainer); Page2.Size = UDim2.new(1,0,1,0); Page2.BackgroundTransparency = 1; Page2.Visible = false
local Page3 = Instance.new("Frame", PageContainer); Page3.Size = UDim2.new(1,0,1,0); Page3.BackgroundTransparency = 1; Page3.Visible = false

local function SwitchTab(btn, page)
    for _, t in pairs({Tab1, Tab2, Tab3}) do t.TextColor3 = Theme.SubText; t.BackgroundColor3 = Theme.Background end
    for _, p in pairs({Page1, Page2, Page3}) do p.Visible = false end
    btn.TextColor3 = Theme.Accent; btn.BackgroundColor3 = Theme.Element; page.Visible = true
end
SwitchTab(Tab1, Page1)
Tab1.MouseButton1Click:Connect(function() SwitchTab(Tab1, Page1) end)
Tab2.MouseButton1Click:Connect(function() SwitchTab(Tab2, Page2) end)
Tab3.MouseButton1Click:Connect(function() SwitchTab(Tab3, Page3) end)

local function CreateButton(text, parent, x, y, callback)
    local B = Instance.new("TextButton"); B.Parent = parent; B.BackgroundColor3 = Theme.Element; B.Position = UDim2.new(0, x, 0, y); B.Size = UDim2.new(0, 165, 0, 35)
    B.Font = Enum.Font.GothamMedium; B.Text = text; B.TextColor3 = Theme.Text; B.TextSize = 12; B.AutoButtonColor = false
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    local S = Instance.new("UIStroke", B); S.Color = Theme.Element; S.Thickness = 1; S.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local Toggled = false
    B.MouseButton1Click:Connect(function()
        Toggled = not Toggled
        if Toggled then
            TweenService:Create(B, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25,25,25)}):Play()
            TweenService:Create(S, TweenInfo.new(0.2), {Color = Theme.Accent}):Play()
            TweenService:Create(B, TweenInfo.new(0.2), {TextColor3 = Theme.Accent}):Play()
        else
            TweenService:Create(B, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Element}):Play()
            TweenService:Create(S, TweenInfo.new(0.2), {Color = Theme.Element}):Play()
            TweenService:Create(B, TweenInfo.new(0.2), {TextColor3 = Theme.Text}):Play()
        end
        callback(Toggled, B)
    end)
    return B
end

local function CreateClickButton(text, parent, x, y, callback)
    local B = Instance.new("TextButton"); B.Parent = parent; B.BackgroundColor3 = Theme.Element; B.Position = UDim2.new(0, x, 0, y); B.Size = UDim2.new(0, 165, 0, 35)
    B.Font = Enum.Font.GothamMedium; B.Text = text; B.TextColor3 = Theme.Text; B.TextSize = 12
    Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
    local S = Instance.new("UIStroke", B); S.Color = Theme.Element; S.Thickness = 1
    B.MouseButton1Click:Connect(function()
        TweenService:Create(B, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
        wait(0.1)
        TweenService:Create(B, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Element}):Play()
        callback()
    end)
end

local function CreateInput(text, parent, x, y, callback)
    local F = Instance.new("Frame"); F.Parent = parent; F.BackgroundColor3 = Theme.Element; F.Position = UDim2.new(0, x, 0, y); F.Size = UDim2.new(0, 165, 0, 35)
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 4)
    local TB = Instance.new("TextBox"); TB.Parent = F; TB.BackgroundTransparency = 1; TB.Size = UDim2.new(1, 0, 1, 0)
    TB.Font = Enum.Font.GothamMedium; TB.Text = text; TB.TextColor3 = Theme.SubText; TB.TextSize = 12
    TB.FocusLost:Connect(function()
        callback(TB.Text)
        TB.TextColor3 = Theme.Accent
        Notify("Saved: " .. TB.Text)
    end)
end

local function LoadBrain()
    local success, result = pcall(function() return game:HttpGet(BrainURL) end)
    if success then
        local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(result) end)
        if decodeSuccess then BrainData = decoded; Notify("Brain Loaded!") end
    else
        Notify("Brain Error. Using Backup.")
        BrainData = {greeting={triggers={"privet"}, responses={"Offline Mode"}, action="none"}}
    end
end
task.spawn(LoadBrain)

CreateButton("Activate AI", Page1, 10, 15, function(s, btn)
    State.Enabled = s
    btn.Text = s and "AI: ONLINE" or "Activate AI"
    if s then 
        State.Mode = "Wander"
        Humanoid:MoveTo(RootPart.Position)
    else 
        State.Mode = "Idle"
        State.Target = nil
        State.WingmanTarget = nil
        State.IsMoving = false
        Humanoid:MoveTo(RootPart.Position)
    end
end)

CreateClickButton("Reload Brain DB", Page1, 185, 15, function()
    LoadBrain()
end)

local StatusLbl = Instance.new("TextLabel", Page1)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Position = UDim2.new(0, 10, 0, 60); StatusLbl.Size = UDim2.new(0, 300, 0, 20)
StatusLbl.Font = Enum.Font.GothamBold; StatusLbl.Text = "Current Status: Idle"; StatusLbl.TextColor3 = Theme.SubText; StatusLbl.TextSize = 14; StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while wait(0.5) do
        if State.Enabled then
            StatusLbl.Text = "Current Status: " .. State.Mode
            StatusLbl.TextColor3 = Theme.Green
        else
            StatusLbl.Text = "Current Status: Offline"
            StatusLbl.TextColor3 = Theme.Red
        end
    end
end)

CreateInput(Config.Name, Page2, 10, 15, function(txt)
    Config.Name = string.lower(txt)
    SaveSettings()
end)

CreateInput(tostring(Config.GlobalRange), Page2, 185, 15, function(txt)
    local n = tonumber(txt)
    if n then 
        Config.GlobalRange = n 
        SaveSettings()
    end
end)

local SettingsNote = Instance.new("TextLabel", Page2)
SettingsNote.BackgroundTransparency = 1; SettingsNote.Position = UDim2.new(0, 10, 0, 60); SettingsNote.Size = UDim2.new(1, -20, 0, 100)
SettingsNote.Font = Enum.Font.Gotham; SettingsNote.Text = "Settings are saved automatically.\nPress Enter after typing.\n\nAI supports swimming and climbing."; SettingsNote.TextColor3 = Theme.SubText; SettingsNote.TextSize = 12; SettingsNote.TextWrapped = true; SettingsNote.TextXAlignment = Enum.TextXAlignment.Left

local AboutTitle = Instance.new("TextLabel", Page3)
AboutTitle.BackgroundTransparency = 1; AboutTitle.Size = UDim2.new(1, 0, 0.3, 0); AboutTitle.Position = UDim2.new(0, 0, 0.1, 0)
AboutTitle.Font = Enum.Font.FredokaOne; AboutTitle.Text = "QUWY AI"; AboutTitle.TextColor3 = Theme.Accent; AboutTitle.TextSize = 40

local function CreateLinkBtn(text, url, yPos)
    local Btn = Instance.new("TextButton", Page3); Btn.BackgroundColor3 = Theme.Element; Btn.Position = UDim2.new(0.5, -100, 0.55, yPos); Btn.Size = UDim2.new(0, 200, 0, 35)
    Btn.Font = Enum.Font.GothamBold; Btn.Text = text; Btn.TextColor3 = Theme.Text; Btn.TextSize = 13
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 20); Instance.new("UIStroke", Btn).Color = Theme.Accent; Instance.new("UIStroke", Btn).Thickness = 1
    Btn.MouseButton1Click:Connect(function() if setclipboard then setclipboard(url); Notify("Link Copied!") else Notify("No Copy Support") end end)
end
CreateLinkBtn("Telegram: QLogovo", "https://t.me/QLogovo", 0)
CreateLinkBtn("Discord Server", "https://discord.gg/9wCEUewSbN", 45)
CreateLinkBtn("GitHub Repository", BrainURL, 90)

local Circle = Instance.new("TextButton"); Circle.Parent = ScreenGui; Circle.BackgroundColor3 = Theme.Background; Circle.Size = UDim2.new(0, 45, 0, 45); Circle.Position = UDim2.new(0.05, 0, 0.1, 0)
Circle.Text = "Q"; Circle.Font = Enum.Font.GothamBold; Circle.TextColor3 = Theme.Accent; Circle.TextSize = 22; Circle.Visible = false; Circle.AutoButtonColor = true
local CC = Instance.new("UICorner", Circle); CC.CornerRadius = UDim.new(1, 0)
local CS = Instance.new("UIStroke", Circle); CS.Color = Theme.Accent; CS.Thickness = 1.5; CS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function EnableUniversalDrag(frame, handle)
    local dragging, dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            TweenService:Create(frame, TweenInfo.new(0.05), {Position = newPos}):Play()
        end
    end)
end

EnableUniversalDrag(Main, TopBar)
EnableUniversalDrag(Circle, Circle)

local function CleanAndClose()
    ScreenGui:Destroy()
    _G.AiScript_Cleanup = nil
    for _, c in pairs(Connections) do c:Disconnect() end
end
_G.AiScript_Cleanup = CleanAndClose

CloseBtn.MouseButton1Click:Connect(CleanAndClose)
MinBtn.MouseButton1Click:Connect(function() Main.Visible = false; Circle.Visible = true; Circle.Size = UDim2.new(0,0,0,0); TweenService:Create(Circle, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0,45,0,45)}):Play() end)
Circle.MouseButton1Click:Connect(function() Circle.Visible = false; Main.Visible = true; Main.Size = UDim2.new(0,0,0,0); TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 480, 0, 320)}):Play() end)
Main.Size = UDim2.new(0,0,0,0); TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 480, 0, 320)}):Play()

local function SendChat(msg)
    if not msg then return end
    task.spawn(function()
        task.wait(math.random(0.5, 1.5))
        pcall(function()
            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if channel then channel:SendAsync(msg) end
            else
                ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
            end
        end)
    end)
end

local function FindPlayerByName(nameFragment)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (string.find(p.Name:lower(), nameFragment) or string.find(p.DisplayName:lower(), nameFragment)) then
            return p
        end
    end
    return nil
end

local function HandleChat(player, message)
    if not State.Enabled then return end
    local cleanMsg = message:lower()
    
    if not string.find(cleanMsg, Config.Name) then return end

    if player.Character then
        local lookPos = Vector3.new(player.Character.HumanoidRootPart.Position.X, RootPart.Position.Y, player.Character.HumanoidRootPart.Position.Z)
        RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
    end
    
    if string.find(cleanMsg, "найди") or string.find(cleanMsg, "find") then
        local targetName = string.match(cleanMsg, "найди%s+(.+)") or string.match(cleanMsg, "find%s+(.+)")
        
        if targetName and (string.find(targetName, "друг") or string.find(targetName, "friend") or string.find(targetName, "парн") or string.find(targetName, "девуш")) then
            State.Mode = "Wingman"
            State.WingmanTarget = nil
            SendChat("Окей, ищу кого-нибудь!")
            return
        end

        if targetName then
            local found = FindPlayerByName(targetName)
            if found then
                State.Mode = "TargetSearch"
                State.Target = found
                SendChat("Ищу " .. found.Name .. "...")
            else
                SendChat("Не вижу такого игрока.")
            end
        end
        return
    end

    if string.find(cleanMsg, "стоп") or string.find(cleanMsg, "stop") or string.find(cleanMsg, "хватит") then
        State.Mode = "Wander"
        State.Target = nil
        State.WingmanTarget = nil
        SendChat("Окей, перестаю.")
        return
    end
    
    local foundResponse = false
    for categoryName, categoryData in pairs(BrainData) do
        for _, trigger in pairs(categoryData.triggers) do
            if string.find(cleanMsg, trigger) then
                local responses = categoryData.responses
                local reply = responses[math.random(1, #responses)]
                SendChat(reply)
                
                local action = categoryData.action
                if action == "follow" then
                    State.Mode = "Follow"
                    State.Target = player.Character
                elseif action == "stop" then
                    State.Mode = "Wander"
                    State.Target = nil
                    State.WingmanTarget = nil
                elseif action == "wingman" then
                    State.Mode = "Wingman"
                    State.WingmanTarget = nil
                elseif action == "getout" then
                     if Humanoid.Sit then Humanoid.Sit = false; Humanoid.Jump = true end
                end
                
                foundResponse = true
                break
            end
        end
        if foundResponse then break end
    end
    
    if not foundResponse then SendChat("?") end
end

table.insert(Connections, Players.PlayerAdded:Connect(function(plr) plr.Chatted:Connect(function(msg) HandleChat(plr, msg) end) end))
for _, plr in pairs(Players:GetPlayers()) do table.insert(Connections, plr.Chatted:Connect(function(msg) HandleChat(plr, msg) end)) end

local function UpdateCharacter()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    
    table.insert(Connections, Humanoid.Seated:Connect(function(active)
        if not State.Enabled then return end
        if active then 
            State.IsMoving = false
            State.CurrentStatus = "Seated"
            task.spawn(function()
                while Humanoid.Sit and State.Enabled do
                    local waitTime = math.random(15, 40)
                    task.wait(waitTime)
                    if Humanoid.Sit and State.Enabled then
                        if math.random() > 0.3 then 
                            Humanoid.Sit = false
                            Humanoid.Jump = true
                            local escapeDir = RootPart.CFrame.LookVector * 15
                            RootPart.AssemblyLinearVelocity = escapeDir + Vector3.new(0, 15, 0)
                            Humanoid:MoveTo(RootPart.Position + escapeDir)
                            task.wait(2)
                            break
                        end
                    end
                end
            end)
        else 
            State.CurrentStatus = "Active" 
        end
    end))
end
UpdateCharacter()
table.insert(Connections, LocalPlayer.CharacterAdded:Connect(UpdateCharacter))

local function IsPathBlocked(targetPos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    
    local dir = targetPos - RootPart.Position
    if dir.Magnitude < 1 then return false end
    
    local ray = workspace:Raycast(RootPart.Position, dir.Unit * math.min(dir.Magnitude, 100), params)
    return ray ~= nil
end

local function CheckForObstacles()
    local lookVector = RootPart.CFrame.LookVector
    local startPos = RootPart.Position - Vector3.new(0, 1, 0)
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {Character}
    local ray = workspace:Raycast(startPos, lookVector * Config.JumpCheckDist, params)
    
    if ray then
        local highRay = workspace:Raycast(startPos + Vector3.new(0, 3, 0), lookVector * Config.JumpCheckDist, params)
        if not highRay then 
            Humanoid.Jump = true 
        else
            local rightRay = workspace:Raycast(startPos, (lookVector + RootPart.CFrame.RightVector).Unit * Config.JumpCheckDist, params)
            local leftRay = workspace:Raycast(startPos, (lookVector - RootPart.CFrame.RightVector).Unit * Config.JumpCheckDist, params)
            
            if rightRay and not leftRay then
                Humanoid:Move(Vector3.new(-1, 0, 0), true)
            elseif leftRay and not rightRay then
                Humanoid:Move(Vector3.new(1, 0, 0), true)
            end
        end
    end
end

local function UnstuckAction()
    Humanoid:MoveTo(RootPart.Position - RootPart.CFrame.LookVector * 5)
    task.wait(0.5)
    local sideDir = math.random() > 0.5 and 1 or -1
    Humanoid:Move(Vector3.new(sideDir, 0, 0), true) 
    task.wait(0.5)
end

local function MoveToPoint(destination)
    if Humanoid.Sit then return false end
    State.IsMoving = true
    
    if not IsPathBlocked(destination) then
        Humanoid:MoveTo(destination)
        
        local timer = 0
        repeat
            task.wait(0.1)
            timer = timer + 0.1
            if (RootPart.Position - destination).Magnitude < 4 then
                State.IsMoving = false
                return true
            end
        until timer > 2 or Humanoid.Sit
        
        if timer > 2 then
             -- If we timed out walking straight, assume we are stuck or logic failed, enforce pathfinding next
        end
    end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 1.0, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6,
        Costs = { Water = 1.0, Plastic = 1 }
    })
    
    local success, _ = pcall(function() path:ComputeAsync(RootPart.Position, destination) end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for i, waypoint in pairs(waypoints) do
            if not State.Enabled then return false end
            if Humanoid.Sit then State.IsMoving = false; return false end
            
            if State.Mode == "Follow" and State.Target then
                if (State.Target.HumanoidRootPart.Position - destination).Magnitude > 20 then return false end
            elseif (State.Mode == "Wingman" and State.WingmanTarget) or (State.Mode == "TargetSearch" and State.Target) then
                 local t = State.WingmanTarget or State.Target
                 if t and t.Character and (t.Character.HumanoidRootPart.Position - destination).Magnitude > 15 then return false end
            end

            if waypoint.Action == Enum.PathWaypointAction.Jump then Humanoid.Jump = true end
            Humanoid:MoveTo(waypoint.Position)
            local moveTimer = 0
            local stuckTimer = 0
            repeat
                local dt = RunService.Heartbeat:Wait()
                moveTimer = moveTimer + dt
                if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                     if waypoint.Position.Y > RootPart.Position.Y + 2 then Humanoid.Jump = true end
                end
                CheckForObstacles()
                if moveTimer > 0.5 then
                    stuckTimer = stuckTimer + dt
                    if stuckTimer > 1 then Humanoid.Jump = true end
                end
                if RootPart.Position.Y < -300 then State.IsMoving = false; return false end
            until (RootPart.Position - waypoint.Position).Magnitude < 4 or stuckTimer > Config.StuckThreshold or Humanoid.Sit
            
            if stuckTimer > Config.StuckThreshold then
                UnstuckAction()
                State.IsMoving = false
                return false
            end
        end
    else
        UnstuckAction()
    end
    State.IsMoving = false
    return true
end

local function FindNewFriend()
    local candidates = {}
    local myPos = RootPart.Position
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
            table.insert(candidates, {plr = p, dist = dist})
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    if #candidates > 0 then return candidates[1].plr end
    return nil
end

task.spawn(function()
    while task.wait(0.2) do
        if not State.Enabled then continue end
        if not Character or not Character.Parent then continue end
        if Humanoid.Sit then continue end
        
        if not State.IsMoving then
            if State.Mode == "Follow" and State.Target and State.Target.Parent then
                local dist = (RootPart.Position - State.Target.HumanoidRootPart.Position).Magnitude
                if dist > 8 then MoveToPoint(State.Target.HumanoidRootPart.Position) end
            
            elseif State.Mode == "TargetSearch" then
                if State.Target and State.Target.Parent and State.Target.Character then
                    local targetPos = State.Target.Character.HumanoidRootPart.Position
                    local dist = (RootPart.Position - targetPos).Magnitude
                    if dist > 8 then
                        MoveToPoint(targetPos)
                    else
                        local lookPos = Vector3.new(targetPos.X, RootPart.Position.Y, targetPos.Z)
                        RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
                        SendChat("Нашел!")
                        task.wait(2)
                        State.Mode = "Wander"
                        State.Target = nil
                    end
                else
                    State.Mode = "Wander"
                    SendChat("Цель потеряна (игрок вышел или исчез).")
                end

            elseif State.Mode == "Wingman" then
                if not State.WingmanTarget then
                    local friend = FindNewFriend()
                    if friend then
                        State.WingmanTarget = friend
                        Notify("Target: " .. friend.Name)
                    else
                        State.Mode = "Wander"
                    end
                elseif State.WingmanTarget and State.WingmanTarget.Parent and State.WingmanTarget.Character then
                    local targetPos = State.WingmanTarget.Character.HumanoidRootPart.Position
                    local dist = (RootPart.Position - targetPos).Magnitude
                    
                    if dist > 8 then
                        MoveToPoint(targetPos)
                    else
                        local lookPos = Vector3.new(targetPos.X, RootPart.Position.Y, targetPos.Z)
                        RootPart.CFrame = CFrame.new(RootPart.Position, lookPos)
                        
                        local phrases = {"Привет! Давай дружить?", "Го дружить?", "Привет, давай знакомиться!", "Ты классный, давай дружить?"}
                        SendChat(phrases[math.random(1, #phrases)])
                        
                        task.wait(3)
                        State.WingmanTarget = nil
                        State.Mode = "Wander"
                    end
                else
                    State.WingmanTarget = nil
                    State.Mode = "Wander"
                end

            elseif State.Mode == "Wander" then
                local rx = math.random(-Config.GlobalRange, Config.GlobalRange)
                local rz = math.random(-Config.GlobalRange, Config.GlobalRange)
                local potentialDest = RootPart.Position + Vector3.new(rx, 0, rz)
                local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {Character}
                local ray = workspace:Raycast(potentialDest + Vector3.new(0,500,0), Vector3.new(0,-1000,0), params)
                if ray then MoveToPoint(ray.Position) end
            end
        end
    end
end)

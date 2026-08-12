-- PlayerRadar - Module
-- API: { Start(), Stop(), Radar = { settings = { ... } } }

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera

local Radar = {
   settings = {
      radius = 100,
      scale = 1,
      teamcheck = false,
      teamcolor = true,
      background = Color3.fromRGB(10, 10, 10),
      border = Color3.fromRGB(75, 75, 75),
      enemycolor = Color3.fromRGB(255, 0, 0),
      teamcolor_friendly = Color3.fromRGB(0, 255, 0),
      teamcolor_enemy = Color3.fromRGB(255, 0, 0),
      localdot = Color3.fromRGB(255, 255, 255),
      healthcolor = true,
      position = Vector2.new(200, 200),
   }
}

local LerpColorModule = loadstring(game:HttpGet("https://pastebin.com/raw/wRnsJeid"))()
local HealthBarLerp = LerpColorModule:Lerp(Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0))

local Connections = {}
local Drawings = {}
local Dragging = false
local DragOffset = Vector2.new(0, 0)
local RadarRunning = false

local function NewCircle(transparency, color, radius, filled, thickness)
   local c = Drawing.new("Circle")
   c.Transparency = transparency
   c.Color = color
   c.Visible = false
   c.Thickness = thickness
   c.Position = Vector2.new(0, 0)
   c.Radius = radius
   c.NumSides = math.clamp(radius * 55 / 100, 10, 75)
   c.Filled = filled
   return c
end

local function GetRelative(pos)
   local char = Player.Character
   if char and char.PrimaryPart then
      local pmpart = char.PrimaryPart
      local camerapos = Vector3.new(Camera.CFrame.Position.X, pmpart.Position.Y, Camera.CFrame.Position.Z)
      local newcf = CFrame.new(pmpart.Position, camerapos)
      local r = newcf:PointToObjectSpace(pos)
      return r.X, r.Z
   end
   return 0, 0
end

local function PlaceDot(plr)
   local dot = NewCircle(1, Radar.settings.enemycolor, 3, true, 1)
   local c

   local function Update()
      c = RunService.RenderStepped:Connect(function()
         local char = plr.Character
         local hum = char and char:FindFirstChildOfClass("Humanoid")
         if char and hum and char.PrimaryPart and hum.Health > 0 then
            -- Team Check (hide same team)
            if Radar.settings.teamcheck and plr.TeamColor == Player.TeamColor then
               dot.Visible = false
               return
            end

            local scale = Radar.settings.scale
            local relx, rely = GetRelative(char.PrimaryPart.Position)
            local newpos = Radar.settings.position - Vector2.new(relx * scale, rely * scale)

            -- Determine color
            local dotColor = Radar.settings.enemycolor
            if Radar.settings.teamcolor then
               if plr.TeamColor == Player.TeamColor then
                  dotColor = Radar.settings.teamcolor_friendly
               else
                  dotColor = Radar.settings.teamcolor_enemy
               end
            end
            if Radar.settings.healthcolor then
               dotColor = HealthBarLerp(hum.Health / hum.MaxHealth)
            end

            dot.Color = dotColor

            if (newpos - Radar.settings.position).Magnitude < Radar.settings.radius - 2 then
               dot.Radius = 3
               dot.Position = newpos
               dot.Visible = true
            else
               local dist = (Radar.settings.position - newpos).Magnitude
               local calc = (Radar.settings.position - newpos).Unit * (dist - Radar.settings.radius)
               local inside = Vector2.new(newpos.X + calc.X, newpos.Y + calc.Y)
               dot.Radius = 2
               dot.Position = inside
               dot.Visible = true
            end
         else
            dot.Visible = false
            if not Players:FindFirstChild(plr.Name) then
               dot:Remove()
               if c then c:Disconnect() end
            end
         end
      end)
   end
   coroutine.wrap(Update)()
end

local function NewLocalDot()
   local d = Drawing.new("Triangle")
   d.Visible = true
   d.Thickness = 1
   d.Filled = true
   d.Color = Radar.settings.localdot
   d.PointA = Radar.settings.position + Vector2.new(0, -6)
   d.PointB = Radar.settings.position + Vector2.new(-3, 6)
   d.PointC = Radar.settings.position + Vector2.new(3, 6)
   return d
end

local function Start()
   if RadarRunning then return end
   RadarRunning = true
   Drawings = {}

   -- Background
   local bg = NewCircle(0.9, Radar.settings.background, Radar.settings.radius, true, 1)
   bg.Visible = true
   bg.Position = Radar.settings.position
   Drawings.bg = bg

   local border = NewCircle(0.75, Radar.settings.border, Radar.settings.radius, false, 3)
   border.Visible = true
   border.Position = Radar.settings.position
   Drawings.border = border

   -- Player dots
   for _, v in pairs(Players:GetChildren()) do
      if v.Name ~= Player.Name then
         PlaceDot(v)
      end
   end

   -- Local player dot
   Drawings.localdot = NewLocalDot()

   -- Player added/removed
   table.insert(Connections, Players.PlayerAdded:Connect(function(v)
      if v.Name ~= Player.Name then
         PlaceDot(v)
      end
      if Drawings.localdot then
         Drawings.localdot:Remove()
         Drawings.localdot = NewLocalDot()
      end
   end))
   table.insert(Connections, Players.PlayerRemoving:Connect(function()
      if Drawings.localdot then
         Drawings.localdot:Remove()
         Drawings.localdot = NewLocalDot()
      end
   end))

   -- Loop: update local dot + background
   local loop
   loop = RunService.RenderStepped:Connect(function()
      if Drawings.localdot then
         Drawings.localdot.Color = Radar.settings.localdot
         Drawings.localdot.PointA = Radar.settings.position + Vector2.new(0, -6)
         Drawings.localdot.PointB = Radar.settings.position + Vector2.new(-3, 6)
         Drawings.localdot.PointC = Radar.settings.position + Vector2.new(3, 6)
      end
      if Drawings.bg then
         Drawings.bg.Position = Radar.settings.position
         Drawings.bg.Radius = Radar.settings.radius
         Drawings.bg.Color = Radar.settings.background
      end
      if Drawings.border then
         Drawings.border.Position = Radar.settings.position
         Drawings.border.Radius = Radar.settings.radius
         Drawings.border.Color = Radar.settings.border
      end
   end)
   table.insert(Connections, loop)

   -- Draggable
   local inset = GuiService:GetGuiInset()
   table.insert(Connections, UIS.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1
         and (Vector2.new(Mouse.X, Mouse.Y + inset.Y) - Radar.settings.position).Magnitude < Radar.settings.radius then
         DragOffset = Radar.settings.position - Vector2.new(Mouse.X, Mouse.Y)
         Dragging = true
      end
   end))
   table.insert(Connections, UIS.InputEnded:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 then
         Dragging = false
      end
   end))

   -- Mouse hover dot + drag update
   local hover
   hover = RunService.RenderStepped:Connect(function()
      if (Vector2.new(Mouse.X, Mouse.Y + inset.Y) - Radar.settings.position).Magnitude < Radar.settings.radius then
         if not Drawings.hover then
            Drawings.hover = NewCircle(1, Color3.fromRGB(255, 255, 255), 3, true, 1)
         end
         Drawings.hover.Position = Vector2.new(Mouse.X, Mouse.Y + inset.Y)
         Drawings.hover.Visible = true
      else
         if Drawings.hover then Drawings.hover.Visible = false end
      end
      if Dragging then
         Radar.settings.position = Vector2.new(Mouse.X, Mouse.Y) + DragOffset
      end
   end)
   table.insert(Connections, hover)
end

local function Stop()
   if not RadarRunning then return end
   RadarRunning = false
   for _, conn in ipairs(Connections) do
      pcall(conn.Disconnect, conn)
   end
   Connections = {}
   for _, d in pairs(Drawings) do
      pcall(d.Remove, d)
   end
   Drawings = {}
end

return {
   Start = Start,
   Stop = Stop,
   Radar = Radar,
}

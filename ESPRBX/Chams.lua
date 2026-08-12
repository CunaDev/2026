-- Chams Public - Highlight 기반 Chams 모듈
-- API: { Start(), Stop(), Cham = { settings = { ... } } }

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

local Cham = {
   settings = {
      fillcolor = Color3.fromRGB(255, 60, 60),
      outlinecolor = Color3.fromRGB(0, 0, 0),
      filltransparency = 0.3,
      outlinetransparency = 0,
      teamcolor = true,     -- 팀 컬러 사용
      teamcheck = false,    -- 같은 팀 숨김
      maxdistance = 500,
      depthmode = "AlwaysOnTop", -- "AlwaysOnTop" (벽 뚫고 보임) / "Occluded" (벽 뒤 숨김)
   }
}

local chamCache = {}
local _playerAdded, _playerRemoved, _hbConnection

local function getDistance(char)
   local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char.PrimaryPart)
   if not root then return math.huge end
   local cam = workspace.CurrentCamera
   if not cam then return math.huge end
   return (root.Position - cam.CFrame.Position).Magnitude
end

local function createCham(player)
   local cham = Instance.new("Highlight")
   cham.FillColor = Cham.settings.fillcolor
   cham.OutlineColor = Cham.settings.outlinecolor
   cham.FillTransparency = Cham.settings.filltransparency
   cham.OutlineTransparency = Cham.settings.outlinetransparency
   cham.DepthMode = Cham.settings.depthmode == "Occluded"
         and Enum.HighlightDepthMode.Occluded
         or Enum.HighlightDepthMode.AlwaysOnTop
   cham.Parent = player.Character or nil
   cham.Adornee = player.Character or nil
   cham.Enabled = false
   chamCache[player] = cham
end

local function removeCham(player)
   local cham = chamCache[player]
   if cham then
      pcall(function() cham:Destroy() end)
      chamCache[player] = nil
   end
end

local function updateCham(player, cham)
   local char = player.Character
   local hum = char and char:FindFirstChildOfClass("Humanoid")

   -- 캐릭터 로드 / 파괴 감지
   if not cham.Parent or cham.Parent ~= char then
      if cham.Parent then pcall(function() cham.Parent = nil end) end
      if char then
         cham.Parent = char
         cham.Adornee = char
      end
   end

   if not char or not hum or hum.Health <= 0 then
      cham.Enabled = false
      return
   end

   -- 팀 체크
   if Cham.settings.teamcheck and player.TeamColor == localPlayer.TeamColor then
      cham.Enabled = false
      return
   end

   -- 거리
   if getDistance(char) > (Cham.settings.maxdistance or 500) then
      cham.Enabled = false
      return
   end

   -- 컬러 업데이트
   local color = Cham.settings.teamcolor and player.TeamColor.Color or Cham.settings.fillcolor
   cham.FillColor = color
   cham.OutlineColor = Cham.settings.outlinecolor
   cham.FillTransparency = Cham.settings.filltransparency
   cham.OutlineTransparency = Cham.settings.outlinetransparency
   cham.DepthMode = Cham.settings.depthmode == "Occluded"
         and Enum.HighlightDepthMode.Occluded
         or Enum.HighlightDepthMode.AlwaysOnTop
   cham.Enabled = true
end

local function Start()
   if Cham.State then return end
   Cham.State = true

   for _, player in next, players:GetPlayers() do
      if player ~= localPlayer then
         if player.Character then
            createCham(player)
         end
      end
   end

   _playerAdded = players.PlayerAdded:Connect(function(player)
      if player == localPlayer then return end
      player.CharacterAdded:Connect(function(char)
         local cham = chamCache[player] or Instance.new("Highlight")
         cham.Parent = char
         cham.Adornee = char
         chamCache[player] = cham
      end)
      if player.Character then
         createCham(player)
      end
   end)

   _playerRemoved = players.PlayerRemoving:Connect(function(player)
      removeCham(player)
   end)

   _hbConnection = runService.Heartbeat:Connect(function()
      for player, cham in pairs(chamCache) do
         local ok, err = pcall(updateCham, player, cham)
         if not ok then print("[Chams] error:", err) end
      end
   end)
end

local function Stop()
   if not Cham.State then return end
   Cham.State = false
   if _hbConnection then _hbConnection:Disconnect() _hbConnection = nil end
   if _playerAdded then _playerAdded:Disconnect() _playerAdded = nil end
   if _playerRemoved then _playerRemoved:Disconnect() _playerRemoved = nil end
   for player in pairs(chamCache) do
      removeCham(player)
   end
end

return {
   Start = Start,
   Stop = Stop,
   Cham = Cham,
}

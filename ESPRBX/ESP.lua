-- API: { Start(), Stop(), ESP = { settings = { ... } } }

-- services
local runService = game:GetService("RunService");
local players = game:GetService("Players");

-- settings (허브에서 ESP.settings로 접근)
local ESP = {
   settings = {
      defaultcolor = Color3.fromRGB(255,0,0),
      teamcheck = false,
      teamcolor = true,
      maxdistance = 500,
      boxes = true,
      tracers = false,
      names = true,
      distance = true,
      health = true,
      boxthickness = 1,
      tracerthickness = 1,
      healthbarposition = "Left",
   }
};

-- variables
local localPlayer = players.LocalPlayer;
local camera;

-- functions
local newVector2, newColor3, newDrawing = Vector2.new, Color3.new, Drawing.new;
local tan, rad = math.tan, math.rad;
local round = function(...) local a = {}; for i,v in next, table.pack(...) do a[i] = math.round(v); end return unpack(a); end;
local wtvp = function(...) local a, b = camera.WorldToViewportPoint(camera, ...) return newVector2(a.X, a.Y), b, a.Z end;

local espCache = {};
local _playerAdded, _playerRemoved;

local function createEsp(player)
   local drawings = {};

   drawings.box = newDrawing("Square");
   drawings.box.Thickness = ESP.settings.boxthickness;
   drawings.box.Filled = false;
   drawings.box.Color = ESP.settings.defaultcolor;
   drawings.box.Visible = false;
   drawings.box.ZIndex = 2;

   drawings.boxoutline = newDrawing("Square");
   drawings.boxoutline.Thickness = 3;
   drawings.boxoutline.Filled = false;
   drawings.boxoutline.Color = newColor3();
   drawings.boxoutline.Visible = false;
   drawings.boxoutline.ZIndex = 1;

   drawings.tracer = newDrawing("Line");
   drawings.tracer.Thickness = ESP.settings.tracerthickness;
   drawings.tracer.Color = ESP.settings.defaultcolor;
   drawings.tracer.Visible = false;

   drawings.healthbg = newDrawing("Line");
   drawings.healthbg.Thickness = 3;
   drawings.healthbg.Color = Color3.fromRGB(30,30,30);
   drawings.healthbg.Visible = false;

   drawings.healthfill = newDrawing("Line");
   drawings.healthfill.Thickness = 2;
   drawings.healthfill.Color = Color3.fromRGB(0,255,0);
   drawings.healthfill.Visible = false;

   drawings.nametag = newDrawing("Text");
   drawings.nametag.Center = true;
   drawings.nametag.Outline = true;
   drawings.nametag.Size = 13;
   drawings.nametag.Color = Color3.fromRGB(255,255,255);
   drawings.nametag.Visible = false;

   drawings.disttag = newDrawing("Text");
   drawings.disttag.Center = true;
   drawings.disttag.Outline = true;
   drawings.disttag.Size = 12;
   drawings.disttag.Color = Color3.fromRGB(200,200,200);
   drawings.disttag.Visible = false;

   espCache[player] = drawings;
end

local function removeEsp(player)
   if rawget(espCache, player) then
       for _, drawing in next, espCache[player] do
           drawing:Remove();
       end
       espCache[player] = nil;
   end
end

local function updateEsp(player, esp)
   local character = player and player.Character;
   local hum = character and character:FindFirstChildOfClass("Humanoid");
   local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart);
   local head = character and character:FindFirstChild("Head");

   if not character or not hum or not root or not head or hum.Health <= 0 then
      esp.box.Visible = false;
      esp.boxoutline.Visible = false;
      esp.tracer.Visible = false;
      esp.healthbg.Visible = false;
      esp.healthfill.Visible = false;
      esp.nametag.Visible = false;
      esp.disttag.Visible = false;
      return;
   end

   local dist = (root.Position - camera.CFrame.Position).Magnitude;
   if dist > (ESP.settings.maxdistance or 500) then
      esp.box.Visible = false;
      esp.boxoutline.Visible = false;
      esp.tracer.Visible = false;
      esp.healthbg.Visible = false;
      esp.healthfill.Visible = false;
      esp.nametag.Visible = false;
      esp.disttag.Visible = false;
      return;
   end

   if ESP.settings.teamcheck and player.TeamColor == localPlayer.TeamColor then
      esp.box.Visible = false;
      esp.boxoutline.Visible = false;
      esp.tracer.Visible = false;
      esp.healthbg.Visible = false;
      esp.healthfill.Visible = false;
      esp.nametag.Visible = false;
      esp.disttag.Visible = false;
      return;
   end

   local cframe = character:GetModelCFrame();
   local position, visible, depth = wtvp(cframe.Position);
   esp.box.Thickness = ESP.settings.boxthickness;
   esp.tracer.Thickness = ESP.settings.tracerthickness;
   esp.boxoutline.Thickness = ESP.settings.boxthickness + 2;

   if cframe and visible then
      local scaleFactor = 1 / (math.abs(depth or 1) * tan(rad(camera.FieldOfView / 2)) * 2) * 1000;
      local width, height = round(4 * scaleFactor, 5 * scaleFactor);
      local x, y = round(position.X, position.Y);
      local color = ESP.settings.teamcolor and player.TeamColor.Color or ESP.settings.defaultcolor;

      -- Box (원본 유지)
      esp.box.Size = newVector2(width, height);
      esp.box.Position = newVector2(round(x - width / 2, y - height / 2));
      esp.box.Color = color;
      esp.box.Visible = ESP.settings.boxes and visible;

      esp.boxoutline.Size = esp.box.Size;
      esp.boxoutline.Position = esp.box.Position;
      esp.boxoutline.Visible = esp.box.Visible;

      -- Health bar
      if ESP.settings.health then
         local hpRatio = math.clamp(hum.Health / hum.MaxHealth, 0, 1);
         local hpColor = Color3.fromRGB(0,255,0):Lerp(Color3.fromRGB(255,0,0), 1 - hpRatio);
         local gap = 4;

         if ESP.settings.healthbarposition == "Left" then
            local bx = x - width / 2 - gap;
            esp.healthbg.From = newVector2(bx, y + height / 2);
            esp.healthbg.To = newVector2(bx, y - height / 2);
            esp.healthfill.From = newVector2(bx, y + height / 2);
            esp.healthfill.To = newVector2(bx, y + height / 2 - height * hpRatio);
         elseif ESP.settings.healthbarposition == "Right" then
            local bx = x + width / 2 + gap;
            esp.healthbg.From = newVector2(bx, y + height / 2);
            esp.healthbg.To = newVector2(bx, y - height / 2);
            esp.healthfill.From = newVector2(bx, y + height / 2);
            esp.healthfill.To = newVector2(bx, y + height / 2 - height * hpRatio);
         elseif ESP.settings.healthbarposition == "Top" then
            local by = y - height / 2 - gap;
            esp.healthbg.From = newVector2(x - width / 2, by);
            esp.healthbg.To = newVector2(x + width / 2, by);
            esp.healthfill.From = newVector2(x - width / 2, by);
            esp.healthfill.To = newVector2(x - width / 2 + width * hpRatio, by);
         else -- Bottom
            local by = y + height / 2 + gap;
            esp.healthbg.From = newVector2(x - width / 2, by);
            esp.healthbg.To = newVector2(x + width / 2, by);
            esp.healthfill.From = newVector2(x - width / 2, by);
            esp.healthfill.To = newVector2(x - width / 2 + width * hpRatio, by);
         end

         esp.healthbg.Visible = true;
         esp.healthfill.Color = hpColor;
         esp.healthfill.Visible = true;
      else
         esp.healthbg.Visible = false;
         esp.healthfill.Visible = false;
      end

      -- Nametag (박스 위)
      if ESP.settings.names then
         esp.nametag.Text = player.Name;
         esp.nametag.Color = color;
         esp.nametag.Position = newVector2(x, y - height / 2 - 14);
         esp.nametag.Visible = true;
      else
         esp.nametag.Visible = false;
      end

      -- Distance + Health (박스 아래)
      if ESP.settings.distance then
         local text = math.floor(dist) .. "s";
         if ESP.settings.health then
            text = text .. " | " .. math.floor(hum.Health) .. "hp";
         end
         esp.disttag.Text = text;
         esp.disttag.Position = newVector2(x, y + height / 2 + 4);
         esp.disttag.Visible = true;
      else
         esp.disttag.Visible = false;
      end

      -- Tracer
      if ESP.settings.tracers then
         local origin = newVector2(camera.ViewportSize.X / 2, camera.ViewportSize.Y);
         local target = newVector2(x, y + height / 2);
         esp.tracer.From = origin;
         esp.tracer.To = target;
         esp.tracer.Color = color;
         esp.tracer.Visible = true;
      else
         esp.tracer.Visible = false;
      end
   else
      esp.box.Visible = false;
      esp.boxoutline.Visible = false;
      esp.tracer.Visible = false;
      esp.healthbg.Visible = false;
      esp.healthfill.Visible = false;
      esp.nametag.Visible = false;
      esp.disttag.Visible = false;
   end
end

local function Start()
   if ESP.State then return end
   ESP.State = true
   camera = workspace.CurrentCamera;
   print("[ESP] Start() called");

   -- main (원본 유지)
   for _, player in next, players:GetPlayers() do
      if player ~= localPlayer then
         createEsp(player);
      end
   end

   _playerAdded = players.PlayerAdded:Connect(function(player)
      createEsp(player);
   end);

   _playerRemoved = players.PlayerRemoving:Connect(function(player)
      removeEsp(player);
   end)

   runService:BindToRenderStep("esp", Enum.RenderPriority.Camera.Value, function()
      if not camera or camera.Parent ~= workspace then
         camera = workspace.CurrentCamera;
         if not camera then return end
      end

      for player, drawings in next, espCache do
         local ok, err = pcall(updateEsp, player, drawings);
         if not ok then print("[ESP] error:", err) end
      end
   end)
end

local function Stop()
   if not ESP.State then return end
   ESP.State = false
   runService:UnbindFromRenderStep("esp");
   if _playerAdded then _playerAdded:Disconnect() _playerAdded = nil end
   if _playerRemoved then _playerRemoved:Disconnect() _playerRemoved = nil end
   for player in next, espCache do
      removeEsp(player);
   end
end

return {
   Start = Start,
   Stop = Stop,
   ESP = ESP,
}

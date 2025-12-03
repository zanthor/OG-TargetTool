-- OG-TargetTool: Target management utilities

local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_TARGET_CHANGED")
evt:RegisterEvent("ADDON_LOADED")

-- ===== Simple Toggle Tracking (Original Feature) =====
local toggleSlot1 = nil
local toggleSlot2 = nil

-- ===== Pool Configuration =====
local poolSize = 2  -- Default to 2 targets
local targetPool = {}  -- Circular buffer of GUIDs
local poolIndex = 0  -- Current position in pool (0 = not in pool)
local lastKnownTarget = nil

-- ===== Forward Declarations =====
local widget, numberText, minusText, plusText, minusBtn, plusBtn

-- ===== Helper Functions =====
local function IsGUIDInPool(guid)
  for i = 1, getn(targetPool) do
    if targetPool[i] == guid then
      return i
    end
  end
  return nil
end

local function AddToPool(guid)
  -- Don't add if already in pool
  if IsGUIDInPool(guid) then
    return
  end
  
  -- Add to pool (shift oldest out if full)
  if getn(targetPool) >= poolSize then
    table.remove(targetPool, 1)  -- Remove oldest
  end
  table.insert(targetPool, guid)  -- Add newest at end
end

local function CleanPool()
  -- Remove any dead/invalid targets from pool
  local i = 1
  while i <= getn(targetPool) do
    if not UnitExists or not UnitExists(targetPool[i]) then
      table.remove(targetPool, i)
    else
      i = i + 1
    end
  end
end

local function GetPoolIndex(guid)
  for i = 1, getn(targetPool) do
    if targetPool[i] == guid then
      return i
    end
  end
  return 0
end

-- ===== Helper to check if widget is on screen =====
local function EnsureWidgetOnScreen()
  if not widget then return end
  
  local screenWidth = GetScreenWidth()
  local screenHeight = GetScreenHeight()
  local scale = widget:GetEffectiveScale()
  local widgetWidth = widget:GetWidth() * scale
  local widgetHeight = widget:GetHeight() * scale
  
  local point, relativeTo, relativePoint, xOfs, yOfs = widget:GetPoint()
  if not xOfs or not yOfs then
    -- No position set, center it
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", 0, -200)
    OGTT_Settings.widgetPos.x = 0
    OGTT_Settings.widgetPos.y = -200
    return
  end
  
  -- Convert to screen coordinates
  local centerX = (screenWidth / 2) + xOfs
  local centerY = (screenHeight / 2) + yOfs
  
  -- Check if any part of widget is visible
  local left = centerX - (widgetWidth / 2)
  local right = centerX + (widgetWidth / 2)
  local bottom = centerY - (widgetHeight / 2)
  local top = centerY + (widgetHeight / 2)
  
  local isOffScreen = (right < 0 or left > screenWidth or top < 0 or bottom > screenHeight)
  
  if isOffScreen then
    -- Center the widget
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", 0, -200)
    OGTT_Settings.widgetPos.x = 0
    OGTT_Settings.widgetPos.y = -200
  end
end

-- ===== Target Change Tracking =====
evt:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    DEFAULT_CHAT_FRAME:AddMessage("ADDON_LOADED: " .. tostring(arg1))
  end
  
  if event == "ADDON_LOADED" and arg1 == "OG-TargetTool" then
    -- Initialize saved variables with defaults
    OGTT_Settings = OGTT_Settings or {}
    if OGTT_Settings.widgetVisible == nil then OGTT_Settings.widgetVisible = false end
    if OGTT_Settings.showButtons == nil then OGTT_Settings.showButtons = true end
    if OGTT_Settings.widgetLocked == nil then OGTT_Settings.widgetLocked = false end
    OGTT_Settings.widgetPos = OGTT_Settings.widgetPos or {}
    if OGTT_Settings.widgetPos.x == nil then OGTT_Settings.widgetPos.x = 0 end
    if OGTT_Settings.widgetPos.y == nil then OGTT_Settings.widgetPos.y = -200 end
    if OGTT_Settings.minimapPos == nil then OGTT_Settings.minimapPos = 180 end
    if OGTT_Settings.poolSize == nil then OGTT_Settings.poolSize = 2 end
    
    -- Load pool size from saved settings
    poolSize = OGTT_Settings.poolSize
    
    -- Initialize widget
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", OGTT_Settings.widgetPos.x, OGTT_Settings.widgetPos.y)
    
    numberText:SetText(poolSize)
    if poolSize <= 2 then
      minusText:SetTextColor(0.5, 0.5, 0.5)
    else
      minusText:SetTextColor(1, 0.82, 0)
    end
    if poolSize >= 10 then
      plusText:SetTextColor(0.5, 0.5, 0.5)
    else
      plusText:SetTextColor(1, 0.82, 0)
    end
    if OGTT_Settings.showButtons then
      minusBtn:Show()
      plusBtn:Show()
      widget:SetWidth(95)
    else
      minusBtn:Hide()
      plusBtn:Hide()
      widget:SetWidth(50)
    end
    
    if OGTT_Settings.widgetVisible then
      widget:Show()
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    local exists, newGUID = UnitExists("target")
    if exists and newGUID and newGUID ~= "0x0000000000000000" then
      -- New valid target
      if newGUID ~= lastKnownTarget then
        -- Update simple toggle slots
        if newGUID ~= toggleSlot1 and newGUID ~= toggleSlot2 then
          toggleSlot2 = toggleSlot1
          toggleSlot1 = newGUID
        end
        
        -- Update pool
        AddToPool(newGUID)
        poolIndex = GetPoolIndex(newGUID)
      end
      lastKnownTarget = newGUID
    else
      -- Target cleared
      lastKnownTarget = nil
      poolIndex = 0
    end
  end
end)

-- ===== Simple Toggle Function (Original Feature) =====
function OGTT_TargetLastTarget()
  -- Validate both slots still exist
  if toggleSlot1 and UnitExists and not UnitExists(toggleSlot1) then
    toggleSlot1 = nil
  end
  
  if toggleSlot2 and UnitExists and not UnitExists(toggleSlot2) then
    toggleSlot2 = nil
  end
  
  -- Need at least one valid slot
  if not toggleSlot1 and not toggleSlot2 then
    return
  end
  
  -- Determine which slot to target
  local exists, currentGUID = UnitExists("target")
  local targetGUID = nil
  
  if currentGUID == toggleSlot1 then
    -- Currently on slot1, switch to slot2 (or stay on slot1 if slot2 is nil)
    targetGUID = toggleSlot2 or toggleSlot1
  elseif currentGUID == toggleSlot2 then
    -- Currently on slot2, switch to slot1
    targetGUID = toggleSlot1
  else
    -- Not on either slot, target slot1 (most recent)
    targetGUID = toggleSlot1
  end
  
  if targetGUID then
    TargetUnit(targetGUID)
  end
end

-- ===== Pool Navigation Functions =====
function OGTT_TargetLastPoolTarget()
  CleanPool()
  
  if getn(targetPool) == 0 then
    return
  end
  
  -- Get current target
  local exists, currentGUID = UnitExists("target")
  
  -- If we're in the pool, go backwards
  if currentGUID and poolIndex > 0 then
    poolIndex = poolIndex - 1
    if poolIndex < 1 then
      poolIndex = getn(targetPool)  -- Wrap to end
    end
  else
    -- Not in pool or no target, go to most recent
    poolIndex = getn(targetPool)
  end
  
  TargetUnit(targetPool[poolIndex])
end

function OGTT_TargetNextPoolTarget()
  CleanPool()
  
  if getn(targetPool) == 0 then
    return
  end
  
  -- Get current target
  local exists, currentGUID = UnitExists("target")
  
  -- If we're in the pool, go forwards
  if currentGUID and poolIndex > 0 then
    poolIndex = poolIndex + 1
    if poolIndex > getn(targetPool) then
      poolIndex = 1  -- Wrap to start
    end
  else
    -- Not in pool or no target, go to oldest
    poolIndex = 1
  end
  
  TargetUnit(targetPool[poolIndex])
end

-- ===== Pool Size Management (Forward declared) =====
local OGTT_UpdateWidgetFunc = nil

function OGTT_IncreasePoolSize()
  if poolSize < 10 then
    poolSize = poolSize + 1
    OGTT_Settings.poolSize = poolSize
    if OGTT_UpdateWidgetFunc then
      OGTT_UpdateWidgetFunc()
    end
  end
end

function OGTT_DecreasePoolSize()
  if poolSize > 2 then
    poolSize = poolSize - 1
    OGTT_Settings.poolSize = poolSize
    while getn(targetPool) > poolSize do
      table.remove(targetPool, 1)
    end
    if OGTT_UpdateWidgetFunc then
      OGTT_UpdateWidgetFunc()
    end
  end
end

-- ===== Widget UI =====
widget = CreateFrame("Frame", "OGTT_Widget", UIParent)
widget:SetWidth(150)
widget:SetHeight(40)
widget:SetPoint("CENTER", 0, -200)  -- Temporary position, will be set properly in ADDON_LOADED
widget:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 5, right = 5, top = 5, bottom = 5 }
})
widget:SetBackdropColor(0, 0, 0, 0.8)
widget:EnableMouse(true)
widget:SetMovable(true)
widget:RegisterForDrag("LeftButton")
widget:Hide()

-- Minus button (anchored to left edge)
minusBtn = CreateFrame("Button", nil, widget)
minusBtn:SetWidth(24)
minusBtn:SetHeight(24)
minusBtn:SetPoint("LEFT", widget, "LEFT", 10, 0)

minusText = minusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
minusText:SetPoint("CENTER", 0, 0)
minusText:SetText("-")
minusText:SetTextColor(1, 0.82, 0)

local minusBg = minusBtn:CreateTexture(nil, "BACKGROUND")
minusBg:SetAllPoints()
minusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
minusBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

-- Plus button (anchored to right edge)
plusBtn = CreateFrame("Button", nil, widget)
plusBtn:SetWidth(24)
plusBtn:SetHeight(24)
plusBtn:SetPoint("RIGHT", widget, "RIGHT", -10, 0)

-- Widget number display (centered in widget)
numberText = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
numberText:SetPoint("CENTER", widget, "CENTER", 0, 0)
numberText:SetText(poolSize)

plusText = plusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
plusText:SetPoint("CENTER", 0, 0)
plusText:SetText("+")
plusText:SetTextColor(1, 0.82, 0)

local plusBg = plusBtn:CreateTexture(nil, "BACKGROUND")
plusBg:SetAllPoints()
plusBg:SetTexture("Interface\\Buttons\\WHITE8X8")
plusBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

-- Update widget display
local function UpdateWidget()
  numberText:SetText(poolSize)
  
  -- Update button states
  if poolSize <= 2 then
    minusText:SetTextColor(0.5, 0.5, 0.5)
  else
    minusText:SetTextColor(1, 0.82, 0)
  end
  
  if poolSize >= 10 then
    plusText:SetTextColor(0.5, 0.5, 0.5)
  else
    plusText:SetTextColor(1, 0.82, 0)
  end
  
  -- Adjust widget size based on button visibility
  if OGTT_Settings.showButtons then
    minusBtn:Show()
    plusBtn:Show()
    widget:SetWidth(95)
  else
    minusBtn:Hide()
    plusBtn:Hide()
    widget:SetWidth(50)
  end
  
  if OGTT_Settings.widgetLocked then
    widget:EnableMouse(false)
  else
    widget:EnableMouse(true)
  end
end

-- Make update function accessible
widget.Update = UpdateWidget
OGTT_UpdateWidgetFunc = UpdateWidget

-- Button handlers
minusBtn:SetScript("OnClick", function()
  OGTT_DecreasePoolSize()
end)

plusBtn:SetScript("OnClick", function()
  OGTT_IncreasePoolSize()
end)

-- Hover effects
minusBtn:SetScript("OnEnter", function()
  if poolSize > 2 then
    minusBg:SetVertexColor(0.3, 0.3, 0.3, 0.8)
  end
end)

minusBtn:SetScript("OnLeave", function()
  minusBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
end)

plusBtn:SetScript("OnEnter", function()
  if poolSize < 10 then
    plusBg:SetVertexColor(0.3, 0.3, 0.3, 0.8)
  end
end)

plusBtn:SetScript("OnLeave", function()
  plusBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
end)

-- Drag handlers
widget:SetScript("OnDragStart", function()
  if not OGTT_Settings.widgetLocked then
    this:StartMoving()
  end
end)

widget:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, _, x, y = this:GetPoint()
  OGTT_Settings.widgetPos.x = x
  OGTT_Settings.widgetPos.y = y
end)



-- ===== Minimap Button =====
local minimapBtn = CreateFrame("Button", "OGTT_MinimapButton", Minimap)
minimapBtn:SetWidth(32)
minimapBtn:SetHeight(32)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Background texture
local background = minimapBtn:CreateTexture(nil, "BACKGROUND")
background:SetWidth(20)
background:SetHeight(20)
background:SetPoint("CENTER", 0, 1)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

-- Border
local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetWidth(52)
border:SetHeight(52)
border:SetPoint("TOPLEFT", 0, 0)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Text label (TT)
local text = minimapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
text:SetPoint("CENTER", 0, 1)
text:SetText("TT")
text:SetTextColor(0, 0.6, 1)  -- Bright blue

-- Minimap button positioning
local function UpdateMinimapButton()
  local angle = math.rad(OGTT_Settings.minimapPos or 180)
  local x = 80 * math.cos(angle)
  local y = 80 * math.sin(angle)
  minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Minimap button dragging
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    OGTT_Settings.minimapPos = angle
    UpdateMinimapButton()
  end)
end)

minimapBtn:SetScript("OnDragStop", function()
  this:SetScript("OnUpdate", nil)
end)

-- Minimap button menu
local menuFrame = nil

local function CreateMinimapMenu()
  if menuFrame then return end
  
  menuFrame = CreateFrame("Frame", "OGTT_MinimapMenu", UIParent)
  menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  menuFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
  })
  menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  menuFrame:SetWidth(160)
  menuFrame:SetHeight(110)
  menuFrame:Hide()
  
  -- Close menu when clicking outside
  menuFrame:SetScript("OnShow", function()
    if not menuFrame.backdrop then
      local backdrop = CreateFrame("Frame", nil, UIParent)
      backdrop:SetFrameStrata("FULLSCREEN")
      backdrop:SetAllPoints()
      backdrop:EnableMouse(true)
      backdrop:SetScript("OnMouseDown", function()
        menuFrame:Hide()
      end)
      menuFrame.backdrop = backdrop
    end
    menuFrame.backdrop:Show()
  end)
  
  menuFrame:SetScript("OnHide", function()
    if menuFrame.backdrop then
      menuFrame.backdrop:Hide()
    end
  end)
  
  -- Title text
  local titleText = menuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleText:SetPoint("TOP", menuFrame, "TOP", 0, -8)
  titleText:SetText("OG-TargetTool")
  titleText:SetTextColor(0, 0.6, 1)
  
  local yOffset = -28
  local itemHeight = 16
  local itemSpacing = 2
  
  -- Helper to create menu items with checkboxes
  local function CreateMenuItem(text, isChecked, onClick)
    local item = CreateFrame("Button", nil, menuFrame)
    item:SetWidth(150)
    item:SetHeight(itemHeight)
    item:SetPoint("TOP", menuFrame, "TOP", 0, yOffset)
    
    -- Background highlight
    local bg = item:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.2, 0.2, 0.2, 0)
    
    -- Checkbox
    local checkbox = item:CreateTexture(nil, "OVERLAY")
    checkbox:SetWidth(12)
    checkbox:SetHeight(12)
    checkbox:SetPoint("LEFT", item, "LEFT", 4, 0)
    checkbox:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    
    -- Text
    local fs = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", item, "LEFT", 20, 0)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1)
    
    -- Update function
    item.Update = function()
      if isChecked() then
        checkbox:Show()
      else
        checkbox:Hide()
      end
    end
    
    item:Update()
    
    -- Highlight on hover
    item:SetScript("OnEnter", function()
      bg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    end)
    
    item:SetScript("OnLeave", function()
      bg:SetVertexColor(0.2, 0.2, 0.2, 0)
    end)
    
    item:SetScript("OnClick", function()
      onClick()
      item:Update()
    end)
    
    yOffset = yOffset - itemHeight - itemSpacing
    return item
  end
  
  -- Show Widget
  local widgetItem = CreateMenuItem("Show Widget",
    function() return OGTT_Settings.widgetVisible end,
    function()
      OGTT_Settings.widgetVisible = not OGTT_Settings.widgetVisible
      if OGTT_Settings.widgetVisible then
        if OGTT_UpdateWidgetFunc then
          OGTT_UpdateWidgetFunc()
        end
        widget:Show()
      else
        widget:Hide()
      end
    end
  )
  
  -- Show +/-
  local buttonsItem = CreateMenuItem("Show +/-",
    function() return OGTT_Settings.showButtons end,
    function()
      OGTT_Settings.showButtons = not OGTT_Settings.showButtons
      UpdateWidget()
    end
  )
  
  -- Lock Widget
  local lockItem = CreateMenuItem("Lock Widget",
    function() return OGTT_Settings.widgetLocked end,
    function()
      OGTT_Settings.widgetLocked = not OGTT_Settings.widgetLocked
      UpdateWidget()
    end
  )
end

local function ShowMinimapMenu()
  CreateMinimapMenu()
  
  if menuFrame:IsVisible() then
    menuFrame:Hide()
  else
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", GetCursorPosition())
    menuFrame:Show()
  end
end

minimapBtn:SetScript("OnClick", function()
  ShowMinimapMenu()
end)

-- ===== Slash Command =====
SLASH_OGTT1 = "/ott"
SlashCmdList["OGTT"] = function(msg)
  if msg == "widget" then
    OGTT_Settings.widgetVisible = not OGTT_Settings.widgetVisible
    if OGTT_Settings.widgetVisible then
      if OGTT_UpdateWidgetFunc then
        OGTT_UpdateWidgetFunc()
      end
      widget:Show()
      DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Widget shown")
    else
      widget:Hide()
      DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Widget hidden")
    end
    return
  end
  
  if msg == "reset" then
    widget:ClearAllPoints()
    widget:SetPoint("CENTER", 0, 0)
    OGTT_Settings.widgetPos.x = 0
    OGTT_Settings.widgetPos.y = 0
    OGTT_Settings.widgetVisible = true
    if OGTT_UpdateWidgetFunc then
      OGTT_UpdateWidgetFunc()
    end
    widget:Show()
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Widget reset to center")
    return
  end
  
  local size = tonumber(msg)
  if not size or size < 2 or size > 10 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Usage: /ott N (where N is 2-10)")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Usage: /ott widget (to toggle widget)")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Usage: /ott reset (to reset widget position)")
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Current pool size: " .. poolSize)
    return
  end
  
  poolSize = size
  OGTT_Settings.poolSize = size
  
  -- Trim pool if new size is smaller
  while getn(targetPool) > poolSize do
    table.remove(targetPool, 1)
  end
  
  UpdateWidget()
  DEFAULT_CHAT_FRAME:AddMessage("|cffff8000OG-TargetTool:|r Pool size set to " .. poolSize)
end

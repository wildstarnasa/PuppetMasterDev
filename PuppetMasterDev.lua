-----------------------------------------------------------------------------------------------
-- Client Lua Script for PuppetMasterDev
-- Originally writen by Garet Jax
-----------------------------------------------------------------------------------------------
 
require "Window"

local iAddonVersion = 1

local tDefaultSettings = {
	bIsEnabled = true,
	iPointsCount = 200,
	fMarkerDistance = 7,
	fNorthDistance = 4,
	fMarkerPercentClose = 0.5,
	fUpdateInterval = 0.01,
	bWithText = false,
	iAddonVersion = iAddonVersion
}
 
local PuppetMasterDev = {} 
 
function PuppetMasterDev:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	
	self.xXml = nil
	self.uMe = nil
	self.uTarget = nil
	self.wTargetMarker = nil
	self.wNorth = nil
	self.v3RealNorth = nil
	self.tPoints = {}
	
	self.tSettings = tDefaultSettings
		
    return o
end

function PuppetMasterDev:Init()
    Apollo.RegisterAddon(self)
end

function PuppetMasterDev:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end
	return self.tSettings
end

function PuppetMasterDev:OnRestore(eLevel, tData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end
	self.tSettings = tData
end
 
function PuppetMasterDev:OnLoad()
	self.xXml = XmlDoc.CreateFromFile("PuppetMasterDev.xml")
	
	Apollo.RegisterTimerHandler("PMD_LoadInit", "LoadInit", self)
	Apollo.CreateTimer("PMD_LoadInit", 2, false)
end

function PuppetMasterDev:ToggleOptions(sCommand, sParams)
	if sParams ~= nil and sParams ~= "" then
		local iPointsCount = tonumber(sParams)
		if iPointsCount ~= nil then
			if iPointsCount < 1 then iPointsCount = 1 elseif iPointsCount > 10000 then iPointsCount = 10000 end
			self.tSettings.iPointsCount = iPointsCount
		end
		
		RequestReloadUI()
		return
	end
	
	if self.tSettings.bWithText then
		self.tSettings.bWithText = false
	elseif self.tSettings.bIsEnabled then
		self.tSettings.bIsEnabled = false
	else
		self.tSettings.bIsEnabled = true
		self.tSettings.bWithText = true
	end

	RequestReloadUI()
end

function PuppetMasterDev:LoadInit()
	Apollo.RegisterSlashCommand("puppet", "ToggleOptions", self)
	
	if self.tSettings.bIsEnabled then
		Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
		Apollo.RegisterEventHandler("TargetUnitChanged", "TargetChange", self)
		Apollo.RegisterTimerHandler("PMD_UpdateMarkers", "UpdateMarkers", self)
		Apollo.CreateTimer("PMD_UpdateMarkers", self.tSettings.fUpdateInterval, true)
	end
end

function PuppetMasterDev:OnChangeWorld()
	self:RemovePoints(self.uTarget)
	self:RemoveTargetVector()
	self.uMe = nil
end

function PuppetMasterDev:UpdateMarkers()
	if self.uMe == nil then
		self.uMe = GameLib.GetPlayerUnit()
		if self.uMe == nil then
			return
		end
		self:AddPoints(self.uMe, false)
		self:TargetChange(GameLib.GetTargetUnit())
	end
	
	self:UpdateNorth()
	self:UpdateTargetVector()
end

function PuppetMasterDev:TargetChange(uUnit)
	self:RemovePoints(self.uTarget)
	
	if uUnit == nil then
		self:RemoveTargetVector()
		return
	end
	
	self.uTarget = uUnit
	self:AddPoints(uUnit, true)
end

function PuppetMasterDev:RemoveTargetVector()
	if self.uTarget == nil then
		return
	end
	
	self.wTargetMarker:Destroy()
	self.wTargetMarker = nil
	self.uTarget = nil
end

function PuppetMasterDev:UpdateTargetVector()
	if self.uTarget == nil then
		return
	end
	
	local v3TargetPos = Vector3.New(self.uTarget:GetAttachmentPosition().tLocation)
	local v3MyPos = Vector3.New(self.uMe:GetAttachmentPosition().tLocation)
	local v3PosDiff = v3TargetPos - v3MyPos
	local fLengthFraction = self.tSettings.fMarkerDistance / v3PosDiff:Length()
	
	if fLengthFraction >= self.tSettings.fMarkerPercentClose then
		fLengthFraction = self.tSettings.fMarkerPercentClose
	end
	
	local v3TargetMarker = v3MyPos + (v3TargetPos - v3MyPos) * fLengthFraction
	
	if self.wTargetMarker == nil then
		self.wTargetMarker = Apollo.LoadForm(self.xXml, "Target", "InWorldHudStratum", self)
	end
	self.wTargetMarker:SetWorldLocation(v3TargetMarker)
end

function PuppetMasterDev:UpdateNorth()
	if self.wNorth == nil then
		self.v3RealNorth = Vector3.New(0, 0, -self.tSettings.fNorthDistance)
		
		self.wNorth = Apollo.LoadForm(self.xXml, "WithText", "InWorldHudStratum", self)
		self.wNorth:SetText("N")
		self.wNorth:SetBGColor("red")
	end

	self.wNorth:SetWorldLocation(Vector3.New(self.uMe:GetAttachmentPosition().tLocation) + self.v3RealNorth)
end

function PuppetMasterDev:RemovePoints()
	for i, wPoint in ipairs(self.tPoints) do
		wPoint:Destroy()
		self.tPoints[i] = nil
	end
end

function PuppetMasterDev:AddPoints(uUnit, bSave)
	for i = 0,self.tSettings.iPointsCount do
		self:AddOnePoint(uUnit, i, bSave)
	end
end

function PuppetMasterDev:AddOnePoint(uUnit, iPos, bSave)
	local sPointName = "WithText"
	if not self.tSettings.bWithText then
		sPointName = "JustDot"
	end
	
	local wPoint = Apollo.LoadForm(self.xXml, sPointName, "InWorldHudStratum", self)
	wPoint:SetUnit(uUnit, iPos)
	
	if self.tSettings.bWithText then
		wPoint:SetText(iPos)
	end
		
	if bSave then
		table.insert(self.tPoints, wPoint)
	end
end

local PuppetMasterDevInst = PuppetMasterDev:new()
PuppetMasterDevInst:Init()

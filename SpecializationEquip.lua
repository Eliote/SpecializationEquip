local ADDON_NAME, _ = ...

local AddonFrame = CreateFrame('Frame', ADDON_NAME)
AddonFrame:SetScript('OnEvent', function(self, event, ...) self[event](...) end)
AddonFrame:RegisterEvent('ADDON_LOADED')
AddonFrame:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
AddonFrame:RegisterEvent('PLAYER_ENTERING_WORLD')

local CurrentSpecialization
--local SpecializationEquipDB

local LDBIcon = LibStub("LibDBIcon-1.0")

local Launcher = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
	type = "launcher",
	icon = "Interface\\Icons\\Inv_helmet_03.png",
	OnTooltipShow = function(tooltip)
		tooltip:SetText(ADDON_NAME)
		tooltip:AddLine("Click to configure", 1, 1, 1)
		tooltip:Show()
	end,
	OnClick = function(_, button)
		AddonFrame.ConfigDialog()
	end
})

function AddonFrame.PLAYER_SPECIALIZATION_CHANGED(unit)
	if unit ~= "player" then return end

	local _, specName = GetSpecializationInfo(GetSpecialization())

	if CurrentSpecialization == specName then return end
	CurrentSpecialization = specName

	local setName = SpecializationEquipDB[specName]

	if setName then UseEquipmentSet(setName) end
end

function AddonFrame.ADDON_LOADED(name)
	if name ~= ADDON_NAME then return end

	SpecializationEquipDB = SpecializationEquipDB or {}

	LDBIcon:Register(ADDON_NAME, Launcher, SpecializationEquipDB)
end

function AddonFrame.PLAYER_ENTERING_WORLD()
	if not CurrentSpecialization then
		local _, specName = GetSpecializationInfo(GetSpecialization())
		CurrentSpecialization = specName
	end
end

local function setSpecSet(specName, setName, select)
	if select then
		SpecializationEquipDB[specName] = setName
	else
		SpecializationEquipDB[specName] = nil;
	end
end

local function HideMinimap(hide)
	SpecializationEquipDB.hide = hide

	if hide then
		LDBIcon:Hide(ADDON_NAME)
	else
		LDBIcon:Show(ADDON_NAME)
	end
end

function AddonFrame.ConfigDialog()
	if InCombatLockdown() then return end

	-- Create menu frame
	local dropdown1 = CreateFrame("Frame", ADDON_NAME .. "_MenuFrame", nil, "UIDropDownMenuTemplate")

	-- Create specialization list
	local menuList = {}
	for index = 1, GetNumSpecializations() do
		local _, specName, _, specIcon = GetSpecializationInfo(index)

		-- Create list of sets for the specialization
		local equipList = {}
		for index = 1, GetNumEquipmentSets() do
			local setName, setIcon = GetEquipmentSetInfo(index)

			table.insert(equipList, {
				text = setName,
				icon = setIcon,
				func = function(self, _, _, checked) setSpecSet(specName, setName, not checked) end,
				checked = function() return (SpecializationEquipDB[specName] == setName) end
			})
		end

		table.insert(menuList, {
			text = "|T" .. specIcon .. ":0|t " .. specName,
			hasArrow = true,
			checked = function() return GetSpecialization() == index end,
			func = function() SetSpecialization(index) end,
			menuList = equipList
		})
	end

	-- separator
	table.insert(menuList, { text = "", notCheckable = true, notClickable = true })

	-- Create quick change list
	local equipList = {}
	for index = 1, GetNumEquipmentSets() do
		local setName, setIcon, setId, isEquipped = GetEquipmentSetInfo(index)

		table.insert(equipList, {
			text = setName,
			icon = setIcon,
			func = function() UseEquipmentSet(setName) end,
			checked = function() return select(4, GetEquipmentSetInfo(index)) end
		})
	end
	table.insert(menuList, { text = "Quick change", hasArrow = true, notCheckable = true, keepShownOnClick = true, menuList = equipList })

	-- Hide minimap button
	table.insert(menuList, {
		text = "Hide minimap button",
		func = function(_, _, _, checked) HideMinimap(not checked) end,
		checked = function() return SpecializationEquipDB.hide end
	})

	-- separator
	table.insert(menuList, { text = "", notCheckable = true, notClickable = true })
	-- close
	table.insert(menuList, { text = "Close", notCheckable = true, function() ToggleDropDownMenu() end })

	EasyMenu(menuList, dropdown1, "cursor", 0, 0, "MENU");
end

---------------------
--    SLASH CMD    --
---------------------
SLASH_SPECIALIZATIONEQUIP1 = '/spec'

function SlashCmdList.SPECIALIZATIONEQUIP(msg, editbox)
	local command, rest = msg:match("^(%S*)%s*(.-)$");

	if command == "minimap" then
		HideMinimap(not SpecializationEquipDB.hide)
	end
end







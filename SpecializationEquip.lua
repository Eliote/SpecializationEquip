local ADDON_NAME, _ = ...

local AddonFrame = CreateFrame('Frame', ADDON_NAME)
AddonFrame:SetScript('OnEvent', function(self, event, ...) self[event](...) end)
AddonFrame:RegisterEvent('ADDON_LOADED')
AddonFrame:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
AddonFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
AddonFrame:RegisterEvent('ACTIONBAR_SLOT_CHANGED')

local CurrentSpecialization

local LDBIcon = LibStub("LibDBIcon-1.0")

local barCache = {}
local actionBarEventState

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

local function dprint(...)
	if (SpecializationEquipDB.debug) then
		print(...)
	end
end

local function changeActionBarEvent(state)
	if (state == actionBarEventState) then return end

	if (state) then
		AddonFrame:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
	else
		AddonFrame:UnregisterEvent('ACTIONBAR_SLOT_CHANGED')
	end

	dprint("ACTIONBAR_SLOT_CHANGED: ", state)
	actionBarEventState = state
end

local function iconFromTexture(texture)
	if (texture) then
		return "|T" .. texture .. ":0|t"
	end

	return "[null]"
end

local function PickupMountById(id)
	if (id == 268435455) then C_MountJournal.Pickup(0) end

	local _, spellID = C_MountJournal.GetMountInfoByID(id)

	PickupSpell(spellID)
end

local function pickupAction(id, type, subType)
	if (type == "companion") then
		--PickupCompanion(subType or "MOUNT", id)
		PickupSpell(id)
	elseif (type == "summonmount") then
		PickupMountById(id)
	elseif (type == "equipmentset") then
		PickupItem(id)
	elseif (type == "flyout") then
		-- ???
		PickupSpell(id)
	elseif (type == "item") then
		PickupItem(id)
	elseif (type == "macro") then
		PickupMacro(id)
	elseif (type == "summonpet") then
		C_PetJournal.PickupPet(id)
	elseif (type == "spell") then
		PickupSpell(id)
	end
end

function getBarInfo(id, type, subType)
	local name
	local icon

	if (type == "companion") then
		--_, name, _, icon = GetCompanionInfo(subType or "MOUNT", id)
		name, _, icon = GetSpellInfo(id)
	elseif (type == "summonmount") then
		if (id == 268435455) then
			name, _, icon = GetSpellInfo(150544)
		else
			name, _, icon = C_MountJournal.GetMountInfoByID(id)
		end
	elseif (type == "equipmentset") then
		name, icon = GetEquipmentSetInfo(id)
	elseif (type == "flyout") then
		-- ???
		name, _, icon = GetSpellInfo(id)
	elseif (type == "item") then
		name, _, _, _, _, _, _, _, _, icon = GetItemInfo(id)
	elseif (type == "macro") then
		name, icon = GetMacroInfo(id)
	elseif (type == "summonpet") then
		_, _, _, _, _, _, _, name, icon = C_PetJournal.GetPetInfoByPetID(id)
	elseif (type == "spell") then
		name, _, icon = GetSpellInfo(id)
	end

	return name, icon
end

local function syncBars()
	ClearCursor()

	--for bar, enabled in pairs(SpecializationEquipDB.barsToSync) do
	for bar = 1, 12 do
		for i = ((bar - 1) * 12 + 1), (bar * 12) do
			local type, id, subType, spellID = GetActionInfo(i)

			if (SpecializationEquipDB.barsToSync[bar]) then
				if (barCache[i].type ~= type or barCache[i].id ~= id) then
					local fromIcon = GetActionTexture(i)
					if (barCache[i] and barCache[i].id) then
						pickupAction(barCache[i].id, barCache[i].type, barCache[i].subType)
						PlaceAction(i)
					else
						PickupAction(i)
					end

					if (SpecializationEquipDB.logSync) then
						print("Syncing action " .. i .. " from " .. iconFromTexture(fromIcon) .. " to " .. iconFromTexture(GetActionTexture(i)))
					end
				end

				ClearCursor()
			end

			type, id, subType, spellID = GetActionInfo(i)
			barCache[i] = { ["id"] = id, ["type"] = type, ["subType"] = subType, ["spellId"] = spellID }
		end
	end

	changeActionBarEvent(true)
end

local function copyBar(name, bar)
	local actionBar = SpecializationEquipGlobalDB.bars[name]

	for i = ((bar - 1) * 12 + 1), (bar * 12) do
		--local type, id, subType, spellID = GetActionInfo(i)

		local fromIcon = GetActionTexture(i)

		if (actionBar[i] and actionBar[i].id) then
			pickupAction(actionBar[i].id, actionBar[i].type, actionBar[i].subType)
			PlaceAction(i)
		else
			PickupAction(i)
		end

		if (SpecializationEquipDB.logCopy) then
			print("Changing action " .. i .. " " .. iconFromTexture(fromIcon) .. " from you to " .. iconFromTexture(GetActionTexture(i)) .. " from " .. name)
		end

		ClearCursor()
	end
end

function AddonFrame.UNIT_SPELLCAST_INTERRUPTED(unit, spell, rank, lineID, spellID)
	if unit ~= "player" then return end

	AddonFrame:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED')
	changeActionBarEvent(true)
end

function AddonFrame.ACTIONBAR_SLOT_CHANGED(slot)
	if slot > 120 then return end

	local _, specName = GetSpecializationInfo(GetSpecialization())
	-- the spec is changing
	if CurrentSpecialization ~= specName then return end

	local type, id, subType, spellID = GetActionInfo(slot)

	if (barCache[slot] == nil and type == nil) then return end
	if (barCache[slot] ~= nil and (barCache[slot].type == type and barCache[slot].id == id)) then return end

	dprint("ACTIONBAR_SLOT_CHANGED: ", slot, type, id, subType, spellID)

	-- random mount special case
	--if(id == 268435455 and type == "summonmount") then id = 0 end

	barCache[slot] = { ["id"] = id, ["type"] = type, ["subType"] = subType, ["spellId"] = spellID }
end

function AddonFrame.PLAYER_SPECIALIZATION_CHANGED(unit)
	if unit ~= "player" then return end

	local _, specName = GetSpecializationInfo(GetSpecialization())

	if CurrentSpecialization == specName then return end
	CurrentSpecialization = specName

	AddonFrame:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED')
	changeActionBarEvent(false)

	local setName = SpecializationEquipDB[specName]

	if setName then UseEquipmentSet(setName) end

	syncBars()
end

function AddonFrame.ADDON_LOADED(name)
	if name ~= ADDON_NAME then return end

	SpecializationEquipDB = SpecializationEquipDB or {}
	SpecializationEquipDB.barsToSync = SpecializationEquipDB.barsToSync or {}
	SpecializationEquipDB.logSync = SpecializationEquipDB.logSync or false
	SpecializationEquipDB.logCopy = SpecializationEquipDB.logCopy or false
	SpecializationEquipDB.debug = SpecializationEquipDB.debug or false

	SpecializationEquipGlobalDB = SpecializationEquipGlobalDB or {}
	SpecializationEquipGlobalDB.bars = SpecializationEquipGlobalDB.bars or {}

	local playerName = UnitName("player");
	SpecializationEquipGlobalDB.bars[playerName] = SpecializationEquipGlobalDB.bars[playerName] or {}

	barCache = SpecializationEquipGlobalDB.bars[playerName]

	hooksecurefunc("SetSpecialization", function(index)
		changeActionBarEvent(false)
		AddonFrame:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED')
	end)

	LDBIcon:Register(ADDON_NAME, Launcher, SpecializationEquipDB)
end

function AddonFrame.PLAYER_ENTERING_WORLD()
	if not CurrentSpecialization then
		local _, specName = GetSpecializationInfo(GetSpecialization())
		CurrentSpecialization = specName
	end

	for i = 1, (10 * 12) do
		local type, id, subType, spellID = GetActionInfo(i)
		barCache[i] = { ["id"] = id, ["type"] = type, ["subType"] = subType, ["spellId"] = spellID }
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

	-- Sync menus
	local barsList = {}
	for index = 1, 10 do
		table.insert(barsList, {
			text = "Action Bar " .. index,
			func = function(self, _, _, checked) SpecializationEquipDB.barsToSync[index] = checked end,
			checked = function() return SpecializationEquipDB.barsToSync[index] end,
			keepShownOnClick = true
		})
	end
	table.insert(barsList, { text = "", notCheckable = true, notClickable = true })
	table.insert(barsList, {
		text = "Log syncronization in chat",
		func = function(self, _, _, checked) SpecializationEquipDB.logSync = checked end,
		checked = function() return SpecializationEquipDB.logSync end,
		keepShownOnClick = true
	})
	table.insert(menuList, { text = "ActionBar Syncronization (beta)", hasArrow = true, notCheckable = true, keepShownOnClick = true, menuList = barsList })

	-- create copy bars
	local barsCopyList = {}
	for name in pairs(SpecializationEquipGlobalDB.bars) do
		if (name ~= UnitName("player")) then
			local barsIndex = {}

			for index = 1, 10 do
				local actions = {}
				for i = ((index - 1) * 12 + 1), (index * 12) do
					local b = SpecializationEquipGlobalDB.bars[name][i]
					local iname, icon = getBarInfo(b.id, b.type, b.subType)

					table.insert(actions, {
						text = iname or "--",
						icon = icon,
						notClickable = true,
						notCheckable = true
					})
				end

				table.insert(barsIndex, {
					text = "Copy bar " .. index,
					func = function(self, _, _, checked) copyBar(name, index) end,
					notCheckable = true,
					keepShownOnClick = true,
					hasArrow = true,
					menuList = actions
				})
			end

			table.insert(barsCopyList, { text = name, hasArrow = true, notCheckable = true, keepShownOnClick = true, menuList = barsIndex })
		end
	end
	table.insert(barsCopyList, { text = "", notCheckable = true, notClickable = true })
	table.insert(barsCopyList, {
		text = "Log copy in chat",
		func = function(self, _, _, checked) SpecializationEquipDB.logCopy = checked end,
		checked = function() return SpecializationEquipDB.logCopy end,
		keepShownOnClick = true
	})
	table.insert(menuList, { text = "ActionBar Copy", hasArrow = true, notCheckable = true, keepShownOnClick = true, menuList = barsCopyList })

	-- separator
	table.insert(menuList, { text = "", notCheckable = true, notClickable = true })

	-- Hide minimap button
	table.insert(menuList, {
		text = "Hide minimap button",
		func = function(_, _, _, checked) HideMinimap(not checked) end,
		checked = function() return SpecializationEquipDB.hide end
	})
	table.insert(menuList, {
		text = "Enable debug",
		-- when keepShownOnClick is true the UI is updated and then the function is called giving the new 'checked'
		-- state, but when it's false the function is called without changing the UI thus the checked returns
		-- the state it was seted when creating the menu(the return of 'checked' function)
		func = function(_, _, _, checked) SpecializationEquipDB.debug = checked end,
		checked = function() return SpecializationEquipDB.debug end,
		keepShownOnClick = true
	})

	-- separator
	table.insert(menuList, { text = "", notCheckable = true, notClickable = true })

	-- close
	table.insert(menuList, { text = "Close", notCheckable = true, function() ToggleDropDownMenu() end })

	EasyMenu(menuList, dropdown1, "cursor", 0, 0, "MENU");
end

---------------------
-- SLASH CMD    --
---------------------
SLASH_SPECIALIZATIONEQUIP1 = '/spec'

function SlashCmdList.SPECIALIZATIONEQUIP(msg, editbox)
	local command, rest = msg:match("^(%S*)%s*(.-)$");

	if command == "minimap" then
		HideMinimap(not SpecializationEquipDB.hide)
	end
end







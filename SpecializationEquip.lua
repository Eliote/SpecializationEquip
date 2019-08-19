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
local removedItem = {
	id = nil,
	slot = nil
}

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
		AddonFrame:RegisterEvent('UPDATE_MACROS')
	else
		AddonFrame:UnregisterEvent('ACTIONBAR_SLOT_CHANGED')
		AddonFrame:UnregisterEvent('UPDATE_MACROS')
	end

	dprint("ACTIONBAR_SLOT_CHANGED: ", state)
	dprint("UPDATE_MACROS: ", state)
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
		PickupEquipmentSetByName(id)
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
	local name = id
	local icon

	--dprint("BarInfo(id=" .. (id or "nil") .. ", type=" .. (type or "nil") .. ", subType=" .. (subType or "nil") .. ")")

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
		if (C_EquipmentSet.GetEquipmentSetIDs()[id]) then
			name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
		end
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

	-- Actions information are lazily loaded, so it returns nil before that
	-- TODO: find a way to update de id after it is loaded

	return name or id, icon
end

local function recreateCache()
	for slot = 1, (10 * 12) do
		local type, id, subType, spellID = GetActionInfo(slot)
		if not (barCache[slot] == nil and type == nil) then
			if not (barCache[slot] ~= nil and (barCache[slot].type == type and barCache[slot].id == id)) then
				dprint("UPDATE SYNC SLOT: ", slot, type, id, subType, spellID)
				barCache[slot] = { ["id"] = id, ["type"] = type, ["subType"] = subType, ["spellId"] = spellID }
			end
		end
	end
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

	if (removedItem.slot ~= nil and GetInventoryItemID("player", removedItem.slot) == nil) then
		C_Timer.After(0, function()
			EquipItemByName(removedItem.id, removedItem.slot)
		end)
	end

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

	if setName then C_EquipmentSet.UseEquipmentSet(C_EquipmentSet.GetEquipmentSetID(setName)) end

	-- reset removed item
	removedItem.id = nil
	removedItem.slot = nil

	C_Timer.After(0, syncBars) -- delay the update to the next frame
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

	recreateCache()

	AddonFrame:RegisterEvent('UPDATE_MACROS')
end

function AddonFrame.UPDATE_MACROS()
	C_Timer.After(0, recreateCache)
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

local TALENT_ITEMS_IDS = {
	[150936] = true, -- Soul of the Shadowblade
	[151636] = true, -- Soul of the Archdruid
	[151639] = true, -- Soul of the Slayer
	[151640] = true, -- Soul of the Deathlord
	[151641] = true, -- Soul of the Huntmaster
	[151642] = true, -- Soul of the Archmage
	[151643] = true, -- Soul of the Grandmaster
	[151644] = true, -- Soul of the Highlord
	[151646] = true, -- Soul of the High Priest
	[151647] = true, -- Soul of the Farseer
	[151649] = true, -- Soul of the Netherlord
	[151650] = true, -- Soul of the Battlelord
}
local function setSpec(index)
	local found

	-- search for Talent itens
	for i = 1, 18 do
		local id = GetInventoryItemID("player", i)

		if (TALENT_ITEMS_IDS[id]) then
			found = i
			PickupInventoryItem(i)

			for bagId = 0, 4 do
				if (GetContainerNumFreeSlots(bagId) > 0) then
					-- why you do that blizz??
					if (bagId == 0) then
						PutItemInBackpack() -- OMG
					else
						PutItemInBag(19 + bagId) -- x.x
					end
					PickupInventoryItem(i) -- pickup the equip slot again to make sure it was put in the bag
				end
				if (GetCursorInfo() == nil) then break end
			end

			removedItem.id = id
			removedItem.slot = i

			break -- there is only one per class, so we can stop look for more here.
		end
	end

	if (found and PickupInventoryItem(found) and GetCursorInfo()) then return end

	C_Timer.After(0, function()
		SetSpecialization(index)
	end)
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
		for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
			local setName, setIcon = C_EquipmentSet.GetEquipmentSetInfo(equipId)

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
			func = function() setSpec(index) end,
			menuList = equipList
		})
	end

	-- separator
	table.insert(menuList, { text = "", notCheckable = true, notClickable = true })

	-- Create quick change list
	local equipList = {}
	for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
		local setName, setIcon, setId, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(equipId)

		table.insert(equipList, {
			text = setName,
			icon = setIcon,
			func = function() C_EquipmentSet.UseEquipmentSet(setId) end,
			checked = function() return select(4, C_EquipmentSet.GetEquipmentSetInfo(setId)) end
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
					local b = SpecializationEquipGlobalDB.bars[name] and SpecializationEquipGlobalDB.bars[name][i]
					local iname, icon = (b and getBarInfo(b.id, b.type, b.subType)) or "--"

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







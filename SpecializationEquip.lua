local ADDON_NAME, SpecializationEquip = ...

local AddonFrame = CreateFrame('Frame', ADDON_NAME)
AddonFrame:SetScript('OnEvent', function(self, event, ...) self[event](...) end)
AddonFrame:RegisterEvent('ADDON_LOADED')
AddonFrame:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
AddonFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
AddonFrame:RegisterEvent('ACTIONBAR_SLOT_CHANGED')

SpecializationEquip.MAX_BARS = 15

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
	OnClick = function()
		SpecializationEquip.ConfigDialog()
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
		local setId = C_EquipmentSet.GetEquipmentSetID(id)
		if setId then
			C_EquipmentSet.PickupEquipmentSet(setId)
		end
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

function SpecializationEquip.getBarInfo(id, type, subType)
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
	return (name or id), icon
end

local function recreateCache()
	for slot = 1, (SpecializationEquip.MAX_BARS * 12) do
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
	for bar = 1, SpecializationEquip.MAX_BARS do
		for slot = ((bar - 1) * 12 + 1), (bar * 12) do
			local type, id, subType, spellID = GetActionInfo(slot)

			if (SpecializationEquipDB.barsToSync[bar]) then
				if (barCache[slot].type ~= type or barCache[slot].id ~= id) then
					local fromIcon = GetActionTexture(slot)
					if (barCache[slot] and barCache[slot].id) then
						pickupAction(barCache[slot].id, barCache[slot].type, barCache[slot].subType)
						PlaceAction(slot)
					else
						PickupAction(slot)
					end

					if (SpecializationEquipDB.logSync) then
						print("Syncing action " .. slot .. " from " .. iconFromTexture(fromIcon) .. " to " .. iconFromTexture(GetActionTexture(slot)))
					end
				end

				ClearCursor()
			end

			type, id, subType, spellID = GetActionInfo(slot)
			barCache[slot] = { ["id"] = id, ["type"] = type, ["subType"] = subType, ["spellId"] = spellID }
		end
	end

	changeActionBarEvent(true)
end

function SpecializationEquip.copyBar(name, fromBar, toBar)
	local actionBar = SpecializationEquipGlobalDB.bars[name]

	for i = 1, 12 do
		local from = ((fromBar - 1) * 12) + i
		local to = ((toBar - 1) * 12) + i

		local fromIcon = GetActionTexture(from)

		local barInfo = actionBar[from]
		if (name == UnitName("player")) then
			local actionType, id, subType = GetActionInfo(from)
			barInfo = { id = id, type = actionType, subType = subType }
		end
		if (barInfo and barInfo.id) then
			pickupAction(barInfo.id, barInfo.type, barInfo.subType)
			PlaceAction(to)
		else
			PickupAction(to)
		end

		if (SpecializationEquipDB.logCopy) then
			print("Changing action " .. from .. " " .. iconFromTexture(fromIcon) .. " into " .. iconFromTexture(GetActionTexture(to)) .. " from " .. name)
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
	if slot > (SpecializationEquip.MAX_BARS * 12) then return end

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

	--local setName = SpecializationEquipDB[specName]

	--if setName then C_EquipmentSet.UseEquipmentSet(C_EquipmentSet.GetEquipmentSetID(setName)) end

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

function SpecializationEquip.HideMinimap(hide)
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
function SpecializationEquip.setSpec(index)
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

---------------------
-- SLASH CMD    --
---------------------
SLASH_SPECIALIZATIONEQUIP1 = '/spec'

function SlashCmdList.SPECIALIZATIONEQUIP(msg, editbox)
	local command, rest = msg:match("^(%S*)%s*(.-)$");

	if command == "minimap" then
		SpecializationEquip.HideMinimap(not SpecializationEquipDB.hide)
	end
end







local ADDON_NAME, SpecializationEquip = ...

--- @type ElioteDropDownMenu
local EDDM = LibStub("ElioteDropDownMenu-1.0")
local DropDownMenu_AddButton = EDDM.UIDropDownMenu_AddButton
local DropDownMenu_CreateInfo = EDDM.UIDropDownMenu_CreateInfo
local DropDownMenu_GetOrCreate = EDDM.UIDropDownMenu_GetOrCreate
local DropDownMenu_Initialize = EDDM.UIDropDownMenu_Initialize
local ToggleDropDownMenu = EDDM.ToggleDropDownMenu

local MenuSeparator = {
	text = "", -- required!
	hasArrow = false,
	dist = 0,
	isTitle = true,
	isUninteractable = true,
	notCheckable = true,
	iconOnly = true,
	icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
	tCoordLeft = 0,
	tCoordRight = 1,
	tCoordTop = 0,
	tCoordBottom = 1,
	tSizeX = 0,
	tSizeY = 8,
	tFitDropDownSizeX = true,
	iconInfo = {
		tCoordLeft = 0,
		tCoordRight = 1,
		tCoordTop = 0,
		tCoordBottom = 1,
		tSizeX = 0,
		tSizeY = 8,
		tFitDropDownSizeX = true
	},
}

local function AddSpacer(level)
	DropDownMenu_AddButton(MenuSeparator, level)
end

local menuTable = {
	["SPEC"] = {
		[1] = function()
			for index = 1, GetNumSpecializations() do
				local _, specName, _, specIcon = GetSpecializationInfo(index)

				local info = DropDownMenu_CreateInfo()
				info.text = "|T" .. specIcon .. ":0|t " .. specName
				info.hasArrow = true
				info.checked = function()
					return GetSpecialization() == index
				end
				info.func = function()
					SpecializationEquip.setSpec(index)
				end
				info.arg1 = specName
				info.menuList = { name = "SPEC", specName = specName, specIndex = index }

				DropDownMenu_AddButton(info)
			end
			AddSpacer()
		end,
		[2] = function(menuList)
			for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
				local setName, setIcon = C_EquipmentSet.GetEquipmentSetInfo(equipId)

				local specIndex = menuList.specIndex
				local equippedId = C_EquipmentSet.GetEquipmentSetID(setName)

				local info = DropDownMenu_CreateInfo()
				info.text = setName
				info.icon = setIcon
				info.func = function(_, _, _, checked)
					if not checked then
						C_EquipmentSet.AssignSpecToEquipmentSet(equippedId, specIndex)
					else
						C_EquipmentSet.UnassignEquipmentSetSpec(equippedId)
					end
				end
				info.checked = function()
					local specSetId = C_EquipmentSet.GetEquipmentSetForSpec(specIndex)
					return equippedId == specSetId
				end

				DropDownMenu_AddButton(info, 2)
			end
		end
	},
	["QUICKCHANGE"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()
			info.text = "Quick change"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = "QUICKCHANGE"

			DropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
				local setName, setIcon, setId, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(equipId)

				local info = DropDownMenu_CreateInfo()
				info.text = setName
				info.icon = setIcon
				info.func = function()
					C_EquipmentSet.UseEquipmentSet(setId)
				end
				info.checked = function()
					return select(4, C_EquipmentSet.GetEquipmentSetInfo(setId))
				end

				DropDownMenu_AddButton(info, 2)
			end
		end
	},
	["BARSYNC"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()
			info.text = "ActionBar Synchronization"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = "BARSYNC"

			DropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for _, v in pairs(SpecializationEquip.SortedBars()) do
				local index = v.index
				local info = DropDownMenu_CreateInfo()
				info.text = "Action Bar " .. v.name
				info.func = function(_, _, _, checked)
					SpecializationEquipDB.barsToSync[index] = checked
				end
				info.checked = function()
					return SpecializationEquipDB.barsToSync[index]
				end
				info.keepShownOnClick = true
				info.hasArrow = true
				info.menuList = {
					name = "BARSYNC",
					barIndex = index
				}

				DropDownMenu_AddButton(info, 2)
			end

			AddSpacer(2)

			local info = DropDownMenu_CreateInfo()
			info.text = "Log syncronization in chat"
			info.func = function(_, _, _, checked)
				SpecializationEquipDB.logSync = checked
			end
			info.checked = function()
				return SpecializationEquipDB.logSync
			end
			info.keepShownOnClick = true

			DropDownMenu_AddButton(info, 2)
		end,
		[3] = function(menuList)
			for i = ((menuList.barIndex - 1) * 12 + 1), (menuList.barIndex * 12) do
				local actionType, id, subType = GetActionInfo(i)
				local b = { id = id, type = actionType, subType = subType }

				local iname, icon
				if b then
					iname, icon = SpecializationEquip.getBarInfo(b.id, b.type, b.subType)
				end

				local info = DropDownMenu_CreateInfo()
				info.text = iname or "--"
				info.icon = icon
				info.notClickable = true
				info.notCheckable = true

				DropDownMenu_AddButton(info, 3)
			end
		end
	},
	["COPYBAR"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()

			info.text = "ActionBar Copy"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = {
				name = "COPYBAR"
			}

			DropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for _, v in pairs(SpecializationEquip.SortedBars()) do
				local index = v.index
				local info = DropDownMenu_CreateInfo()
				info.text = "To your bar " .. v.name
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = index
				}

				DropDownMenu_AddButton(info, 2)
			end

			local info = DropDownMenu_CreateInfo()
			info.text = "All bars"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = {
				name = "COPYBAR",
				toIndex = -1
			}

			DropDownMenu_AddButton(info, 2)

			AddSpacer(2)

			info = DropDownMenu_CreateInfo()
			info.text = "Log copy in chat"
			info.func = function(_, _, _, checked)
				SpecializationEquipDB.logCopy = checked
			end
			info.checked = function()
				return SpecializationEquipDB.logCopy
			end
			info.keepShownOnClick = true

			DropDownMenu_AddButton(info, 2)
		end,
		[3] = function(menuList)
			for name in pairs(SpecializationEquipGlobalDB.bars) do
				local info = DropDownMenu_CreateInfo()
				info.text = name
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = menuList.toIndex,
					fromChar = name
				}

				DropDownMenu_AddButton(info, 3)
			end
		end,
		[4] = function(menuList)
			local db = SpecializationEquipGlobalDB.specBars[menuList.fromChar]
			local isCopyAll = (menuList.toIndex == -1)
			local add = function(spec, icon)
				local info = DropDownMenu_CreateInfo()
				info.text = spec or "Last Used"
				info.func = function()
					--SpecializationEquip.copyBar(menuList.fromChar, spec, fromIndex, menuList.toIndex)
					if (isCopyAll) then
						for fromIndex = 1, SpecializationEquip.MAX_BARS do
							SpecializationEquip.copyBar(menuList.fromChar, spec, fromIndex, fromIndex)
						end
					end
				end
				info.icon = icon
				info.hasArrow = not isCopyAll
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					spec = spec,
					toIndex = menuList.toIndex,
					fromChar = menuList.fromChar
				}
				DropDownMenu_AddButton(info, 4)
			end
			add()
			if (db ~= nil) then
				for spec, _ in pairs(db) do
					add(spec, db.specIcon)
				end
			end
		end,
		[5] = function(menuList)
			for _, v in pairs(SpecializationEquip.SortedBars()) do
				local fromIndex = v.index
				local info = DropDownMenu_CreateInfo()
				info.text = "Copy bar " .. v.name .. " from " .. menuList.fromChar .. " to your bar " .. SpecializationEquip.getBarName(menuList.toIndex)
				info.func = function()
					SpecializationEquip.copyBar(menuList.fromChar, menuList.spec, fromIndex, menuList.toIndex)
				end
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = menuList.toIndex,
					spec = menuList.spec,
					fromIndex = fromIndex,
					fromChar = menuList.fromChar
				}

				DropDownMenu_AddButton(info, 5)
			end
		end,
		[6] = function(menuList)
			local bar = SpecializationEquipGlobalDB.bars[menuList.fromChar]
			if (menuList.spec ~= nil) then
				bar = SpecializationEquipGlobalDB.specBars[menuList.fromChar][menuList.spec].bar
			end
			for i = ((menuList.fromIndex - 1) * 12 + 1), (menuList.fromIndex * 12) do
				local b = bar and bar[i]
				--[[if (menuList.fromChar == UnitName("player")) then
					local actionType, id, subType = GetActionInfo(i)
					b = { id = id, type = actionType, subType = subType }
				end]]

				local iname, icon
				if b then
					iname, icon = SpecializationEquip.getBarInfo(b.id, b.type, b.subType)
				end

				local info = DropDownMenu_CreateInfo()
				info.text = iname or "--"
				info.icon = icon
				info.notClickable = true
				info.notCheckable = true

				DropDownMenu_AddButton(info, 6)
			end
		end
	},
	["MINIMAP"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()
			info.text = "Hide minimap button"
			info.func = function(_, _, _, checked)
				SpecializationEquip.HideMinimap(not checked)
			end
			info.checked = function()
				return SpecializationEquipDB.hide
			end

			DropDownMenu_AddButton(info)
		end
	},
	["DEBUG"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()
			info.text = "Enable debug"
			info.func = function(_, _, _, checked)
				SpecializationEquipDB.debug = checked
			end
			info.checked = function()
				return SpecializationEquipDB.debug
			end
			info.keepShownOnClick = true

			DropDownMenu_AddButton(info)
			AddSpacer()
		end
	},
	["CLOSE"] = {
		[1] = function()
			local info = DropDownMenu_CreateInfo()
			info.text = "Close"
			info.notCheckable = true
			info.func = function()
			end

			DropDownMenu_AddButton(info)
		end
	}
}

local function GetMenuTarget(menuList)
	if type(menuList) == "string" then
		return menuList
	end
	if type(menuList) == "table" then
		return menuList.name
	end
end

local function AddMenu(which, level, menuList)
	local target = GetMenuTarget(menuList) or which
	level = level or 1

	if (which == target) then
		menuTable[target][level](menuList)
	end
end

local function initializeMenu(self, level, menuList)
	AddMenu("SPEC", level, menuList)
	AddMenu("QUICKCHANGE", level, menuList)
	AddMenu("BARSYNC", level, menuList)
	AddMenu("COPYBAR", level, menuList)
	AddMenu("DEBUG", level, menuList)
	AddMenu("CLOSE", level, menuList)
end

local dropdown1 = DropDownMenu_GetOrCreate(ADDON_NAME .. "_MenuFrame")
function SpecializationEquip.ConfigDialog()
	if InCombatLockdown() then
		return
	end

	DropDownMenu_Initialize(dropdown1, initializeMenu, "MENU")
	ToggleDropDownMenu(1, nil, dropdown1, "cursor", 3, -3)
end

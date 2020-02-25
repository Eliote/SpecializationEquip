local ADDON_NAME, SpecializationEquip = ...

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
	L_UIDropDownMenu_AddButton(MenuSeparator, level)
end

local menuTable = {
	["SPEC"] = {
		[1] = function()
			for index = 1, GetNumSpecializations() do
				local _, specName, _, specIcon = GetSpecializationInfo(index)

				local info = L_UIDropDownMenu_CreateInfo()
				info.text = "|T" .. specIcon .. ":0|t " .. specName
				info.hasArrow = true
				info.checked = function() return GetSpecialization() == index end
				info.func = function() SpecializationEquip.setSpec(index) end
				info.arg1 = specName
				info.menuList = { name = "SPEC", specName = specName, specIndex = index }

				L_UIDropDownMenu_AddButton(info)
			end
			AddSpacer()
		end,
		[2] = function(menuList)
			for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
				local setName, setIcon = C_EquipmentSet.GetEquipmentSetInfo(equipId)

				local specIndex = menuList.specIndex
				local equippedId = C_EquipmentSet.GetEquipmentSetID(setName)

				local info = L_UIDropDownMenu_CreateInfo()
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

				L_UIDropDownMenu_AddButton(info, 2)
			end
		end
	},
	["QUICKCHANGE"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Quick change"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = "QUICKCHANGE"

			L_UIDropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for _, equipId in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
				local setName, setIcon, setId, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(equipId)

				local info = L_UIDropDownMenu_CreateInfo()
				info.text = setName
				info.icon = setIcon
				info.func = function() C_EquipmentSet.UseEquipmentSet(setId) end
				info.checked = function() return select(4, C_EquipmentSet.GetEquipmentSetInfo(setId)) end

				L_UIDropDownMenu_AddButton(info, 2)
			end
		end
	},
	["BARSYNC"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "ActionBar Synchronization"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = "BARSYNC"

			L_UIDropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for index = 1, 10 do
				local info = L_UIDropDownMenu_CreateInfo()
				info.text = "Action Bar " .. index
				info.func = function(_, _, _, checked) SpecializationEquipDB.barsToSync[index] = checked end
				info.checked = function() return SpecializationEquipDB.barsToSync[index] end
				info.keepShownOnClick = true

				L_UIDropDownMenu_AddButton(info, 2)
			end

			AddSpacer(2)

			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Log syncronization in chat"
			info.func = function(_, _, _, checked) SpecializationEquipDB.logSync = checked end
			info.checked = function() return SpecializationEquipDB.logSync end
			info.keepShownOnClick = true

			L_UIDropDownMenu_AddButton(info, 2)
		end
	},
	["COPYBAR"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()

			info.text = "ActionBar Copy"
			info.hasArrow = true
			info.notCheckable = true
			info.keepShownOnClick = true
			info.menuList = {
				name = "COPYBAR"
			}

			L_UIDropDownMenu_AddButton(info)
			AddSpacer()
		end,
		[2] = function()
			for index = 1, 10 do
				local info = L_UIDropDownMenu_CreateInfo()
				info.text = "To your bar " .. index
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = index
				}

				L_UIDropDownMenu_AddButton(info, 2)
			end

			AddSpacer(2)

			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Log copy in chat"
			info.func = function(_, _, _, checked) SpecializationEquipDB.logCopy = checked end
			info.checked = function() return SpecializationEquipDB.logCopy end
			info.keepShownOnClick = true

			L_UIDropDownMenu_AddButton(info, 2)
		end,
		[3] = function(menuList)
			for name in pairs(SpecializationEquipGlobalDB.bars) do
				local info = L_UIDropDownMenu_CreateInfo()
				info.text = name
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = menuList.toIndex,
					fromChar = name
				}

				L_UIDropDownMenu_AddButton(info, 3)
			end
		end,
		[4] = function(menuList)
			for fromIndex = 1, 10 do
				local info = L_UIDropDownMenu_CreateInfo()
				info.text = "Copy bar " .. fromIndex .. " from " .. menuList.fromChar .. " to your bar " .. menuList.toIndex
				info.func = function() SpecializationEquip.copyBar(menuList.fromChar, fromIndex, menuList.toIndex) end
				info.hasArrow = true
				info.notCheckable = true
				info.keepShownOnClick = true
				info.menuList = {
					name = "COPYBAR",
					toIndex = menuList.toIndex,
					fromIndex = fromIndex,
					fromChar = menuList.fromChar
				}

				L_UIDropDownMenu_AddButton(info, 4)
			end
		end,
		[5] = function(menuList)
			for i = ((menuList.fromIndex - 1) * 12 + 1), (menuList.fromIndex * 12) do
				local b = SpecializationEquipGlobalDB.bars[menuList.fromChar] and SpecializationEquipGlobalDB.bars[menuList.fromChar][i]
				if (menuList.fromChar == UnitName("player")) then
					local actionType, id, subType = GetActionInfo(i)
					b = { id = id, type = actionType, subType = subType }
				end

				local iname, icon
				if b then
					iname, icon = SpecializationEquip.getBarInfo(b.id, b.type, b.subType)
				end

				local info = L_UIDropDownMenu_CreateInfo()
				info.text = iname or "--"
				info.icon = icon
				info.notClickable = true
				info.notCheckable = true

				L_UIDropDownMenu_AddButton(info, 5)
			end
		end
	},
	["MINIMAP"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Hide minimap button"
			info.func = function(_, _, _, checked) SpecializationEquip.HideMinimap(not checked) end
			info.checked = function() return SpecializationEquipDB.hide end

			L_UIDropDownMenu_AddButton(info)
		end
	},
	["DEBUG"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Enable debug"
			info.func = function(_, _, _, checked) SpecializationEquipDB.debug = checked end
			info.checked = function() return SpecializationEquipDB.debug end
			info.keepShownOnClick = true

			L_UIDropDownMenu_AddButton(info)
			AddSpacer()
		end
	},
	["CLOSE"] = {
		[1] = function()
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = "Close"
			info.notCheckable = true
			info.func = function() end

			L_UIDropDownMenu_AddButton(info)
		end
	}
}

local function GetMenuTarget(menuList)
	if type(menuList) == "string" then return menuList end
	if type(menuList) == "table" then return menuList.name end
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

function SpecializationEquip.ConfigDialog()
	if InCombatLockdown() then return end

	local dropdown1 = L_Create_UIDropDownMenu(ADDON_NAME .. "_MenuFrame", nil)
	L_UIDropDownMenu_Initialize(dropdown1, initializeMenu, "MENU")
	L_ToggleDropDownMenu(1, nil, dropdown1, "cursor", 3, -3)
end

-- Author:GtX (LS-Modcompany)
-- Name:Global Company - Create i3D Mappings
-- Description:Create XML i3dMapping and print to GE console / log. Option: Create and write to 'i3dMapping.xml' file in chosen directory.
-- Icon:
-- Hide: no 
--
--
--
-- Notes:
----------------------------------------------------------------------------------------------------------------------------------------------------
-- This version of 'Create i3D Mappings' is designed for use with Global Company 'MAP' and 'Placeable" mods only.
--
-- Visit http://ls-modcompany.com for 'VEHICLE' edition.
----------------------------------------------------------------------------------------------------------------------------------------------------
--
--
--
-- User Options:
----------------------------------------------------------------------------------------------------------------------------------------------------

-- (MAP ONLY) If 'false' then the first selcted node will be used as the 'rootNode'.
-- (MAP ONLY) If 'true' then the 'rootNode' is defined using the 'onCreate' attribute.
local onCreateRootNode = true 

-- This will replaces name spaces with _ in the i3dMapping and GE if set to true.
local correctSpaces = true

-- This will correct duplicate names in the i3dMapping and GE by adding the 'duplicateNameSuffix' to the end.
local correctDuplicateNames = true

-- This will be added to the end of any duplicate names followed by a 'number' if 'correctDuplicateNames = true'.
local duplicateNameSuffix = "fixedName"

-- This will create i3dMappings from the whole 'scenegraph' if no nodes are selected. (Placeables Only)
local allowPrintAll = true

-- If set to true this will create and XML file at the given 'directory' below and print all i3dMappings here.
-- Important: This file will be overwritten each time the script is run.
local printToXML = false

-- Example: "C:\Users\YOURNAME\Desktop"
local directory = ""

----------------------------------------------------------------------------------------------------------------------------------------------------
--
--
--
-- Script starts here. No changes needed!
----------------------------------------------------------------------------------------------------------------------------------------------------

GC_CreateI3dMappings = {}
GC_CreateI3dMappings.idToIndex = {}
GC_CreateI3dMappings.usedNames = {}
GC_CreateI3dMappings.badNodeNames = {}
GC_CreateI3dMappings.nodesToMapping = {}
GC_CreateI3dMappings.duplicateNames = {}

function GC_CreateI3dMappings.init()
	local selectedCount = getNumSelected()
	local scenegraphRoot = getChildAt(getRootNode(), 0)
	local terrain = getChild(scenegraphRoot, "terrain") or 0;

	if selectedCount > 0 then
		local rootNode
		if terrain ~= 0 then
			local onCreateFound = getUserAttribute(getSelection(0), "onCreate") ~= nil
			if selectedCount == 1 and onCreateFound then
				rootNode = getSelection(0);
				GC_CreateI3dMappings.getComponentsData(rootNode)
				GC_CreateI3dMappings.createMappings(selectedCount, rootNode, false)
			else
				if onCreateRootNode then	
					if onCreateFound then
						rootNode = GC_CreateI3dMappings.findOnCreateParent(getSelection(1), scenegraphRoot)
					else
						rootNode = GC_CreateI3dMappings.findOnCreateParent(getSelection(0), scenegraphRoot)
					end
				else
					if selectedCount > 1 then
						rootNode = getSelection(0)
					end
				end

				if rootNode ~= nil then
					GC_CreateI3dMappings.getComponentsData(rootNode)
					GC_CreateI3dMappings.createMappings(selectedCount, nil, false)
				else
					if onCreateRootNode then						
						print("Error: 'onCreate' attribute could not be found. This is required to define mod 'rootNode'! Please set and try again.")
					else
						if selectedCount > 1 then
							print("Error: Only the 'rootNode' is selected! You must also select the nodes you would like to create I3D mappings from.")
						end
					end
				end;
			end
		else
			rootNode = getChildAt(scenegraphRoot, 0)
			if selectedCount == 1 and rootNode == getSelection(0) then
				print("Error: Only the 'rootNode' is selected! You must also select the nodes you would like to create I3D mappings from.")
			else
				GC_CreateI3dMappings.getComponentsData(rootNode)
				GC_CreateI3dMappings.createMappings(selectedCount, nil, false)
			end
		end;
	else
		if terrain == 0 and allowPrintAll then
			print("Info: No nodes selected, creating complete list.")
			rootNode = getChildAt(scenegraphRoot, 0)
			GC_CreateI3dMappings.getComponentsData(rootNode)
			GC_CreateI3dMappings.createMappings(selectedCount, nil, true)
		else
			if terrain ~= 0 then
				if allowPrintAll then
					print("Error: No nodes selected. 'allowPrintAll' can not be used with map.i3d files.")
				else
					print("Error: No nodes selected. You must select the nodes you want to map first.")
				end
			else
				print("Error: No nodes selected. You must select the nodes you would like to create I3D mappings from or set 'allowPrintAll' to true at top of script.")
			end
		end
	end;
end;

function GC_CreateI3dMappings.getComponentsData(rootNode, index)
	local numChildren = getNumOfChildren(rootNode)
	if numChildren > 0 then
		for i = 0, numChildren - 1 do
			local childNode = getChildAt(rootNode, i)

			if index == nil then
				GC_CreateI3dMappings.idToIndex[childNode] = string.format("%.0f", getChildIndex(childNode))
			else
				GC_CreateI3dMappings.idToIndex[childNode] = string.format("%s|%.0f", index, getChildIndex(childNode))
			end

			GC_CreateI3dMappings.getComponentsData(childNode, GC_CreateI3dMappings.idToIndex[childNode])
		end
	end
end

function GC_CreateI3dMappings.findOnCreateParent(node, scenegraphRoot)
	local parent = getParent(node)

	if parent ~= nil and parent ~= 0 then
		if parent == scenegraphRoot then
			return
		end

		if getUserAttribute(parent, "onCreate") == nil then
			parent = findOnCreateParent(parent, scenegraphRoot)
		end;
	end;

	return parent
end;

function GC_CreateI3dMappings.getIdsFromChildren(rootNode, ids)
	local numChildren = getNumOfChildren(rootNode)
	if numChildren > 0 then
		for i = 0, numChildren - 1 do
			local childNode = getChildAt(rootNode, i)
			table.insert(ids, childNode)

			GC_CreateI3dMappings.getIdsFromChildren(childNode, ids)
		end
	end
end

function GC_CreateI3dMappings.getMappingName(node)
	local name = getName(node)
	local badName, _ = string.find(name, " ");

	if badName then
		if correctSpaces then
			name = string.gsub(name, " ", "_")
		end

		table.insert(GC_CreateI3dMappings.badNodeNames, {id = node, name = name})
	end

	if GC_CreateI3dMappings.usedNames[name] == nil then
		GC_CreateI3dMappings.usedNames[name] = 0
	else
		GC_CreateI3dMappings.usedNames[name] = GC_CreateI3dMappings.usedNames[name] + 1

		if correctDuplicateNames then
			if duplicateNameSuffix == nil then
				duplicateNameSuffix = ""
			end;
			name = string.format("%s_%s%d", name, duplicateNameSuffix, GC_CreateI3dMappings.usedNames[name])
			GC_CreateI3dMappings.usedNames[name] = 0
		end

		table.insert(GC_CreateI3dMappings.duplicateNames, {id = node, name = name})
	end

	return name
end

function GC_CreateI3dMappings.createMappings(numberSelected, rootNode, createAll)
	if printToXML then
		if directory ~= nil and directory ~= "" then
			g_file = createFile(directory .. "/i3dMapping.xml", 0)
			if g_file ~= 0 then
				fileWrite(g_file, '\n<i3dMappings>\n')

				if createAll then
					for node, index in pairs (GC_CreateI3dMappings.idToIndex) do
						if index ~= nil then
							local name = GC_CreateI3dMappings.getMappingName(node)
							local text = '    <i3dMapping id="' .. name .. '" node="' .. index .. '"/>\n'
							fileWrite(g_file, text)
						end
					end
				else
					if rootNode ~= nil then
						local ids = {}
						GC_CreateI3dMappings.getIdsFromChildren(rootNode, ids)
						for i = 1, #ids do
							local index = GC_CreateI3dMappings.idToIndex[ids[i]]
							if index ~= nil then
								local name = GC_CreateI3dMappings.getMappingName(ids[i])
								local text = '    <i3dMapping id="' .. name .. '" node="' .. index .. '" />\n'
								fileWrite(g_file, text)
							end
						end
					else
						for i = 0, numberSelected - 1 do
							local node = getSelection(i)
							local index = GC_CreateI3dMappings.idToIndex[node]

							if index ~= nil then
								local name = GC_CreateI3dMappings.getMappingName(node)
								local text = '    <i3dMapping id="' .. name .. '" node="' .. index .. '" />\n'
								fileWrite(g_file, text)
							end
						end
					end
				end;

				fileWrite(g_file, '</i3dMappings>\n')

				delete(g_file)
				g_file = 0

				print(string.format("Info: 'i3dMapping.xml' successfully created at '%s'", directory))
			else
				print(string.format("Error: Could not create 'i3dMapping.xml' at '%s' make sure this path is correct!", directory))
			end
		else
			print("Error: Cannot print mapping to XML, invalid or no 'directory' given!")
		end
	else
		print(' ', '<i3dMappings>')

		if createAll then
			for node, index in pairs (GC_CreateI3dMappings.idToIndex) do
				if index ~= nil then
					local name = GC_CreateI3dMappings.getMappingName(node)
					print('    <i3dMapping id="' .. name .. '" node="' .. index .. '"/>')
				end
			end
		else
			if rootNode ~= nil then
				local ids = {}
				GC_CreateI3dMappings.getIdsFromChildren(rootNode, ids)
				for i = 1, #ids do
					local index = GC_CreateI3dMappings.idToIndex[ids[i]]
					if index ~= nil then
						local name = GC_CreateI3dMappings.getMappingName(ids[i])
						print('    <i3dMapping id="' .. name .. '" node="' .. index .. '"/>')
					end
				end
			else
				for i = 0, numberSelected - 1 do
					local node = getSelection(i)
					local index = GC_CreateI3dMappings.idToIndex[node]

					if index ~= nil then
						local name = GC_CreateI3dMappings.getMappingName(node)
						print('    <i3dMapping id="' .. name .. '" node="' .. index .. '"/>')
					end
				end
			end
		end

		print('</i3dMappings>', ' ')
	end

	local numBadNames = #GC_CreateI3dMappings.badNodeNames
	if numBadNames > 0 then
		if correctSpaces then
			for _, node in pairs (GC_CreateI3dMappings.badNodeNames) do
				setName(node.id, node.name)
			end
			print(string.format("Info: %d names found containing spaces. Spaces replaced with _ please make sure to save i3D file!", numBadNames))
		else
			print(string.format("Error: %d names found containing spaces. These should be fixed / replaced!", numBadNames))
		end
	end

	local numDuplicateNames = #GC_CreateI3dMappings.duplicateNames
	if numDuplicateNames > 0 then
		if correctDuplicateNames then
			for _, node in pairs (GC_CreateI3dMappings.duplicateNames) do
				setName(node.id, node.name)
			end
			print(string.format("%d duplicate names found. Names have been corrected, please make sure to save i3D file!", numDuplicateNames))
		else
			print(string.format("%d duplicate names found. These should be fixed / replaced!", numDuplicateNames))
		end
	end
end

GC_CreateI3dMappings.init()




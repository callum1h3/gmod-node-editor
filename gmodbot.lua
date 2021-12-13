BPF = BPF or {}
BPF.Nodes = BPF.Nodes or {}
BPF.Index = BPF.Index or 0
BPF.EditorMode = BPF.EditorMode or false
BPF.SelectedNode = {}
BPF.Position = BPF.Position or Vector(0,0,0)
BPF.Angle = BPF.Angle or Angle(0,0,0)
BPF.EditorFrame = BPF.EditorFrame or nil
BPF.LastMousePosX = ScrW() / 2
BPF.LastMousePosY = ScrH() / 2
BPF.LastCurtime = UnPredictedCurTime()
BPF.DeltaTime = 0
BPF.HoldButtons = {}
BPF.StartEditorHoldX = 0
BPF.StartEditorHoldY = 0
BPF.SelectDistance = 3000 * 3000
BPF.InspectorNode = -1
BPF.IsUnSaved = false
BPF.NodeTypes = {}
BPF.CurrentPath = {}
BPF.LastHitPos = Vector(0,0,0)
BPF.ProcessNode = -1
BPF.Doors = BPF.Doors or {}

--------------------------------------------------------------------------------------------
------------------------------------ GENERAL STUFF HERE ------------------------------------
--------------------------------------------------------------------------------------------

function BPF:DrawLine( vec1, vec2 )
	render.DrawLine( vec1, vec2, Color( 255, 255, 255 ), false )
end

function BPF:DrawBox( pos, ang, min, max, col )
	render.DrawWireframeBox( pos, ang, min, max, col, false )
end

function BPF:DrawFullBox( pos, ang, min, max, col )
	render.SetMaterial( Material("color_ignorez") )
	render.DrawBox( pos, ang, min, max, col )
end


function BPF:NodesToJson()
	return util.TableToJSON(BPF.Nodes)
end

function BPF:SaveToFile()
	local json = BPF:NodesToJson()

	file.Write( "bpf_"..game.GetMap()..".txt", json )
end

function BPF:SaveNodes()
	cookie.Set( "bpf_index_"..game.GetMap(), BPF.Index )
	cookie.Set( "bpf_nodes_"..game.GetMap(), util.TableToJSON(BPF.Nodes))
	BPF.IsUnSaved = false
end

function BPF:LoadNodes()
	BPF.Index = cookie.GetNumber( "bpf_index_"..game.GetMap(), 1 )
	BPF.Nodes = util.JSONToTable( cookie.GetString( "bpf_nodes_"..game.GetMap(), "{ }" ) )
	BPF.IsUnSaved = false
end

function BPF:LoadDoors()
	BPF.Doors = util.JSONToTable(file.Read( "bpf-doors-"..game.GetMap()..".txt", "DATA" ))
end

function BPF:ResetNodes()
	BPF.IsUnSaved = true
	BPF.Nodes = {}
end

function BPF:GetNode(id)
	return BPF.Nodes[id]
end

function BPF:CreateDualLink(node1, node2)
	BPF.IsUnSaved = true
	BPF.Nodes[node1]["connected"][node2] = true
	BPF.Nodes[node2]["connected"][node1] = true
end

function BPF:CreateOneWayLink(node1, node2)
	BPF.IsUnSaved = true
	BPF.Nodes[node1]["connected"][node2] = true
	BPF.Nodes[node2]["connected"][node1] = false
end

function BPF:DeleteNodeLinks(nodeid)
	local tab = BPF:GetNode(nodeid)["connected"]
	for k, v in pairs( tab ) do
		BPF:GetNode(k)["connected"][nodeid] = nil
		BPF:GetNode(nodeid)["connected"][k] = nil
	end
end

function BPF:DeleteNode(nodeid)
	BPF.IsUnSaved = true

	if not BPF.Nodes[nodeid] then
		return
	end

	BPF:DeleteNodeLinks(nodeid)
	BPF.Nodes[nodeid] = nil
end

function BPF:GetNearbyNode(vec, dist)
	for k, v in pairs( BPF.Nodes ) do
		if vec:DistToSqr(v["position"] or Vector(0,0,0)) < dist then
			return k
		end
	end
	return -1
end

function BPF:CreateNode(vecpos, nodetype)
	BPF.IsUnSaved = true
	local tab = {
		["id"] = nodetype or 1,
		["position"] = vecpos,
		["connected"] = {}
	}

	local nodesize = BPF.Index
	local id = nodesize+1

	BPF.Index = BPF.Index + 1
	BPF.Nodes[id] = tab

	return id
end

function BPF:ChangeNodeID(node, id)
	BPF.IsUnSaved = true
	BPF.Nodes[node]["id"] = id
end

function BPF:DeleteSelectedNodes()
    for k, v in pairs( BPF.SelectedNode ) do
    	BPF.IsUnSaved = true
    	BPF:DeleteNode(k)
    end
    BPF.SelectedNode = {}
end

function BPF:ScreenToTraceLine(x, y)
	cam.Start3D(BPF.Position, BPF.Angle, 90)
		local aimvec = gui.ScreenToVector(gui.MousePos())
	cam.End3D()
		
	local tr = util.TraceLine( {
		start = BPF.Position,
		endpos = BPF.Position + (aimvec * 2000),
	} )

	return tr
end

function BPF:ScreenToHitPos(x, y)
	return BPF:ScreenToTraceLine(x, y).HitPos
end

function BPF:MouseToHitPos()
	return BPF:ScreenToHitPos(gui.MousePos())
end

function BPF:WorldToEditorSpace(position)
	local temp
	cam.Start3D(BPF.Position, BPF.Angle, 90)
		temp = position:ToScreen()
	cam.End3D()
	return temp
end

function BPF:TryGetNodeFunction(name, node)
	return BPF.NodeTypes[BPF.Nodes[node]["id"] or 1][name] or BPF.NodeTypes[1][name]
end

function BPF:FindSingleSelectedNode()
	local i = 0
	local selnode = -1
	for k, v in pairs( BPF.SelectedNode ) do 
		i = i + 1
		selnode = k
	end

	return {i, selnode}
end

function BPF:IsDoorOpen( string_pos )
	-- local pos = v:GetPos()
	-- local tab = BPF.Doors[tonumber(math.floor(pos.x)) .." "..tonumber(math.floor(pos.y)).." "..tonumber(math.floor(pos.z))]
	-- local angi = tonumber(math.floor(v:GetAngles()[2]))
	-- local dif = math.AngleDifference(tab[1], angi)

	-- local h = false
	-- if dif < 25 and dif > -25 then
	-- 	h = true
	-- end

	-- if tab[2] then 
	-- 	h = not h
	-- end
		
	-- return not h
end


-------------------------------------------------------------------------------------------
--------------------------------- PATHFINDING STUFF HERE ----------------------------------
-------------------------------------------------------------------------------------------

function BPF:GetClosestNode( vec )
	local first = true
	local currentNode = -1
	for k, v in pairs( BPF.Nodes ) do
		if first then
			currentNode = k
			first = false
		end

		if BPF.Nodes[currentNode]["position"]:DistToSqr( vec ) > v["position"]:DistToSqr( vec ) then
			currentNode = k
		end
	end

	return currentNode
end

function BPF:dist ( vec1, vec2 )
	return vec1:DistToSqr( vec2 )
end

function BPF:dist_between ( nodeA, nodeB )

	return BPF:dist ( BPF.Nodes[nodeA]["position"], BPF.Nodes[nodeB]["position"] )
end

function BPF:heuristic_cost_estimate ( nodeA, nodeB )
	return BPF:dist ( BPF.Nodes[nodeA]["position"], BPF.Nodes[nodeB]["position"] )
end


function BPF:lowest_f_score ( set, f_score )

	local lowest, bestNode = 99999999999, set[0]
	for _, node in ipairs ( set ) do
		local score = f_score [ node ]
		if score < lowest then
			lowest, bestNode = score, node
		end
	end
	return bestNode
end

function BPF:is_valid_node ( node, neighbor )

	return true
end

function BPF:remove_node ( set, theNode )

	for i, node in ipairs ( set ) do
		if node == theNode then 
			set [ i ] = set [ #set ]
			set [ #set ] = nil
			break
		end
	end	
end

function BPF:unwind_path ( flat_path, map, current_node )

	if map [ current_node ] then
		table.insert ( flat_path, 1, map [ current_node ] ) 
		return BPF:unwind_path ( flat_path, map, map [ current_node ] )
	else
		return flat_path
	end
end

function BPF:neighbor_nodes ( current )
	local tab = {}

	for k, v in pairs( BPF.Nodes[current]["connected"] ) do
		if v then
			local func = BPF.NodeTypes[BPF.Nodes[k]["id"] or 1]["onAStar"] or BPF.NodeTypes[1]["onAStar"]

			if func(k, current) then
				table.insert(tab, k)
			end
		end
	end

	return tab
end

function BPF:not_in ( set, theNode )

	for _, node in ipairs ( set ) do
		if node == theNode then return false end
	end
	return true
end

function BPF:FindPath( start, goal )
	local startNode = BPF:GetClosestNode( start )
	local endNode = BPF:GetClosestNode( goal )

	local closedset = {}
	local openset = { startNode }
	local came_from = {}

	if valid_node_func then is_valid_node = valid_node_func end

	local g_score, f_score = {}, {}
	g_score [ startNode ] = 0
	f_score [ startNode ] = g_score [ startNode ] + BPF:heuristic_cost_estimate ( startNode, endNode )

	while #openset > 0 do
	
		local current = BPF:lowest_f_score ( openset, f_score )
		if current == endNode then
			local path = BPF:unwind_path ( {}, came_from, endNode )
			table.insert ( path, endNode )
			return path
		end

		BPF:remove_node ( openset, current )		
		table.insert ( closedset, current )
		
		local neighbors = BPF:neighbor_nodes ( current )
		for _, neighbor in ipairs ( neighbors ) do 
			if BPF:not_in ( closedset, neighbor ) then
			
				local tentative_g_score = g_score [ current ] + BPF:dist_between ( current, neighbor )
				 
				if BPF:not_in ( openset, neighbor ) or tentative_g_score < g_score [ neighbor ] then 
					came_from 	[ neighbor ] = current
					g_score 	[ neighbor ] = tentative_g_score
					f_score 	[ neighbor ] = g_score [ neighbor ] + BPF:heuristic_cost_estimate ( neighbor, endNode )
					if BPF:not_in ( openset, neighbor ) then
						table.insert ( openset, neighbor )
					end
				end
			end
		end
	end

	return {}
end

function BPF:StartCommand(cmd)
	if #BPF.CurrentPath < 1 then
		return
	end

	if BPF.DisablePath then
		return
	end

	cmd:ClearMovement() 
	cmd:SetViewAngles(Angle(0,0,0))

	if not BPF.Nodes[BPF.CurrentPath[1]] then
		BPF.Nodes = {}
		print("Error when processing path!")
		return
	end

	local position = BPF.Nodes[BPF.CurrentPath[1]]["position"]
	local ang = ( position - LocalPlayer():GetShootPos() ):GetNormalized():Angle()
	local del = math.rad(LocalPlayer():EyeAngles().y) - math.rad(ang.y)

	cmd:SetForwardMove( math.cos(del) * 500)
	cmd:SetSideMove( math.sin(del) * 500)


	if position:DistToSqr(LocalPlayer():GetPos()) < 32 * 32 then
		if BPF:TryGetNodeFunction("onProcessNode", BPF.CurrentPath[1])(BPF.CurrentPath[1]) and not (BPF.ProcessNode == BPF.CurrentPath[1]) then
			BPF.ProcessNode = BPF.CurrentPath[1]
			BPF.DisablePath = true
			return
		end
		
		BPF.ProcessNode = -1
		table.remove(BPF.CurrentPath, 1)	
	end
end


-------------------------------------------------------------------------------------------
----------------------------------- UI STUFF BELOW HERE ----------------------------------- 
-------------------------------------------------------------------------------------------

function BPF:DrawEffects()
	if BPF.EditorMode then
		cam.Start3D()
			for k, v in pairs( BPF.Nodes ) do
				local nodetype = BPF.NodeTypes[v["id"] or 1]
				BPF:TryGetNodeFunction("onEffect", k)(k) 

				if BPF.SelectedNode[k] then
					BPF:TryGetNodeFunction("onSelectEffect", k)(k) 

					BPF:DrawFullBox( v["position"], Angle(0,0,0), Vector(-10,-10,-10), Vector(10,10,10), nodetype["color"] )
					continue
				end

				BPF:DrawBox( v["position"], Angle(0,0,0), Vector(-10,-10,-10), Vector(10,10,10), nodetype["color"] )
			end
		cam.End3D()
	end
end

function BPF:CameraMovement()
	if not BPF.EditorMode then return end

	BPF.DeltaTime = UnPredictedCurTime() - BPF.LastCurtime
	BPF.LastCurtime = UnPredictedCurTime()

	local add = Vector(0,0,0)
    if input.IsKeyDown(KEY_W) then add = add + BPF.Angle:Forward() end
    if input.IsKeyDown(KEY_S) then add = add - BPF.Angle:Forward() end
    if input.IsKeyDown(KEY_D) then add = add + BPF.Angle:Right() end
    if input.IsKeyDown(KEY_A) then add = add - BPF.Angle:Right() end

    if (input.IsKeyDown(KEY_LSHIFT)) then add = add * 8 end
    if (input.IsKeyDown(KEY_DELETE)) then 
    	BPF:DeleteSelectedNodes() 
    	BPF.InspectorNode = -1
		BPF.EditorFrame.inspectorframe:Hide()
    end

    BPF.Position = BPF.Position + (add * 400 * BPF.DeltaTime )

    local x, y = input.GetCursorPos()
    if (input.IsMouseDown(MOUSE_MIDDLE)) then
    	BPF.Angle = BPF.Angle - Angle((BPF.LastMousePosY - y) / 5, -(BPF.LastMousePosX - x) / 5, 0)
    	BPF.Angle.pitch = math.Clamp(BPF.Angle.pitch, -90, 90)

    	input.SetCursorPos( ScrW() / 2, ScrH() / 2 )
    end
end

function BPF:Camera(pos, angles, fov)
	if not BPF.EditorMode then
		return
	end

	local view = {
		origin = BPF.Position,
		angles = BPF.Angle,
		fov = 90,
		drawviewer = true
	}

	return view
end

function BPF:IsNodeInScreenSpace(node, startx, starty, endx, endy)
	local position = node["position"]

	if position:DistToSqr(BPF.Position) > BPF.SelectDistance then
		return false
	end
	
	cam.Start3D(BPF.Position, BPF.Angle, 90)
		local data2D = position:ToScreen()
	cam.End3D()

	if not data2D.visible then return false end
	if startx > data2D.x then return false end
	if endx < data2D.x then return false end
	if starty > data2D.y then return false end
	if endy < data2D.y then return false end

	return true
end


function BPF:OnEditorNormalClick(key)
	if key == MOUSE_LEFT then
		local hitpos = BPF:MouseToHitPos()
		local node = BPF:GetNearbyNode(hitpos, 24 * 24)

		if not input.IsKeyDown(KEY_LSHIFT) then BPF.SelectedNode = {} end
		if node == -1 then return end

		BPF.SelectedNode[node] = true
	elseif key == MOUSE_RIGHT then
		local tab = BPF:FindSingleSelectedNode()
		if tab[1] == 1 and not (tab[2] == -1) then
			if BPF:TryGetNodeFunction("onRightClick", tab[2])(tab[2]) then
				return
			end
		end

		local hitpos = BPF:MouseToHitPos()
		local nodenearby = BPF:GetNearbyNode(hitpos, 64 * 64)

		if not (nodenearby == -1) then
			for k, v in pairs( BPF.SelectedNode ) do BPF:CreateDualLink(k, nodenearby) end
			return
		end

		local node = BPF:CreateNode(hitpos)

		for k, v in pairs( BPF.SelectedNode ) do BPF:CreateDualLink(k, node) end

    	BPF.SelectedNode = {}
    	BPF.SelectedNode[node] = true
	end
end

function BPF:OnEditorClickAfterDrag(key)
	if key == MOUSE_LEFT then
		local endx, endy = input.GetCursorPos()

		if not input.IsKeyDown(KEY_LSHIFT) then
			BPF.SelectedNode = {}
		end

		for k, v in pairs( BPF.Nodes ) do
			if BPF:IsNodeInScreenSpace(v, BPF.StartEditorHoldX, BPF.StartEditorHoldY, endx, endy) then
				BPF.SelectedNode[k] = true
			end
		end
	elseif key == MOUSE_RIGHT then
		local x, y = input.GetCursorPos()

		for k, v in pairs( BPF.NodeTypes ) do
			local startx = (BPF.StartEditorHoldX-20)+(k * 40)
			local starty = BPF.StartEditorHoldY-20
			local endx = startx + 40
			local endy = starty + 40

			if startx < x then
				if endx > x then
					if starty < y then
						if endy > y then
							local node = BPF:CreateNode(BPF.LastHitPos, k)

							for k, v in pairs( BPF.SelectedNode ) do
								BPF:CreateDualLink(k, node)
					    	end

					    	BPF.SelectedNode = {}
					    	BPF.SelectedNode[node] = true		

							return
						end
					end
				end
			end
		end
	end
end

function BPF:OnEditorHoldingKey(key)

	if key == MOUSE_LEFT then
		local x, y = input.GetCursorPos()

		surface.SetDrawColor( 60, 60, 60, 100 )
		surface.DrawRect( BPF.StartEditorHoldX, BPF.StartEditorHoldY, x - BPF.StartEditorHoldX, y - BPF.StartEditorHoldY )		
	elseif key == MOUSE_RIGHT then
		for k, v in pairs( BPF.NodeTypes ) do
			surface.SetDrawColor( v["color"] )
			surface.DrawRect( (BPF.StartEditorHoldX-20)+(k * 40), BPF.StartEditorHoldY-20, 40, 40 )	
		end
	end
end

function BPF:CreateEditorFrame()
	if BPF.EditorFrame and IsValid(BPF.EditorFrame) then
		BPF.EditorFrame:Close()
		BPF.EditorFrame = nil
	end

	local scrW = ScrW()
	local scrH = ScrH()

	BPF.EditorFrame = vgui.Create( "DFrame" )
	BPF.EditorFrame:SetSize( ScrW(), ScrH() )
	BPF.EditorFrame:SetTitle( "" )
	BPF.EditorFrame:SetDraggable( false )
	BPF.EditorFrame:MakePopup()
	BPF.EditorFrame:ShowCloseButton( false )

	BPF.EditorFrame.Paint = function( self, w, h )
		surface.SetDrawColor( 60, 60, 60, 255 )
		surface.DrawRect( 0, 0, w, 22 )

		surface.SetDrawColor( 60, 60, 60, 255 )
		surface.DrawRect( scrW - 276, scrH - 276, 276, 280 )

		local old = DisableClipping( true ) -- Avoid issues introduced by the natural clipping of Panel rendering
		render.RenderView( {
			origin = LocalPlayer():EyePos(),
			angles = LocalPlayer():EyeAngles(),
			x = scrW - 256 - 10, y = scrH - 256 - 10,
			w = 256, h = 256,
			aspectratio  = 256/256,
			viewmodelfov = false
		} )

		DisableClipping( old )

		for k, v in pairs( BPF.NodeTypes ) do
			surface.SetFont( "DebugFixed" )
			local fw, fh = surface.GetTextSize(v["name"])
			fw = fw + 40

			surface.SetDrawColor( 60, 60, 60, 255 )
			surface.DrawRect( scrW - fw, scrH - 276 - 10 - (24 * k), fw, 20 )

			surface.SetDrawColor( v["color"] )
			surface.DrawRect( scrW - fw + 4, scrH - 276 + 2 - 10 - (24 * k), 16, 16 )

			draw.DrawText(v["name"], "DebugFixed", scrW - 10, scrH - 276 + 2 - 10 - (24 * k), Color(255,255,255,255), TEXT_ALIGN_RIGHT)	
		end

		if (BPF.IsUnSaved) then
			draw.DrawText("Remember to Save :)", "DebugFixed", 5, 30, Color(255,255,255,255), TEXT_ALIGN_LEFT)	
		end

		BPF.EditorFrame:CheckIfHolding()
	end

	function BPF.EditorFrame:OnMousePressed( keyCode )
		BPF.HoldButtons[keyCode] = CurTime()
		if keyCode == MOUSE_LEFT or keyCode == MOUSE_RIGHT then
			local x, y = input.GetCursorPos()
			BPF.StartEditorHoldX = x
			BPF.StartEditorHoldY = y

			BPF.LastHitPos = BPF:ScreenToHitPos(x, y)
		end
	end

	function BPF.EditorFrame:OnMouseReleased( keyCode )
		if not BPF.HoldButtons[keyCode] then return end

		if (CurTime() - BPF.HoldButtons[keyCode]) < 0.15 then
			BPF:OnEditorNormalClick(keyCode)
		else
			BPF:OnEditorClickAfterDrag(keyCode)
		end

		local i = 0
		for k, v in pairs( BPF.SelectedNode ) do
			if v then
				BPF.InspectorNode = k
				i = i + 1
			end
		end

		if (i == 1) then
			BPF.EditorFrame.inspectorframe:Rebuild()
			BPF.EditorFrame.inspectorframe:Show()
		else
			BPF.InspectorNode = -1
			BPF.EditorFrame.inspectorframe:Hide()
		end

		BPF.HoldButtons[keyCode] = nil
	end

	function BPF.EditorFrame:CheckIfHolding()
		for k, v in pairs( BPF.HoldButtons ) do
			if (CurTime() - v) > 0.1 then
				BPF:OnEditorHoldingKey(k)
			end
		end
	end

	BPF.EditorFrame.HeaderButtonPosition = 10
	function BPF.EditorFrame:CreateHeaderButton(text, func)
		surface.SetFont( "DebugFixed" )
		local fw, fh = surface.GetTextSize(text)

		local DermaButton = vgui.Create( "DButton", BPF.EditorFrame )
		DermaButton:SetFont("DebugFixed")
		DermaButton:SetText( text )
		DermaButton:SetPos( BPF.EditorFrame.HeaderButtonPosition, 0 )
		DermaButton:SetColor( Color(255,255,255,255) )
		DermaButton:SetSize( fw+10, 20 )
		DermaButton.DoClick = func
		DermaButton.Paint = function( self, w, h )

		end

		BPF.EditorFrame.HeaderButtonPosition = BPF.EditorFrame.HeaderButtonPosition + fw + 15
	end

	BPF.EditorFrame:CreateHeaderButton("Load Nodes", function() 
		BPF:LoadNodes()
		surface.PlaySound( "buttons/blip1.wav" )
	end)

	BPF.EditorFrame:CreateHeaderButton("Save Nodes", function() 
		BPF:SaveNodes()
		surface.PlaySound( "buttons/blip1.wav" )
	end)

	BPF.EditorFrame:CreateHeaderButton("Dump Nodes", function() 
		BPF:SaveToFile()
		surface.PlaySound( "buttons/blip1.wav" )
	end)

	BPF.EditorFrame:CreateHeaderButton("Reset Nodes", function() 
		BPF:ResetNodes()
		surface.PlaySound( "buttons/blip1.wav" )
	end)

	BPF.EditorFrame:CreateHeaderButton("Sus", function() 
		surface.PlaySound( "buttons/blip1.wav" )
	end)

	BPF.EditorFrame.inspectorframe = vgui.Create( "DFrame", BPF.EditorFrame )
	BPF.EditorFrame.inspectorframe:SetPos(0,ScrH() / 2 - 300)
	BPF.EditorFrame.inspectorframe:SetSize( 350, 600 )
	BPF.EditorFrame.inspectorframe:SetTitle( "" )
	BPF.EditorFrame.inspectorframe:SetDraggable( false )
	BPF.EditorFrame.inspectorframe:ShowCloseButton( false )
	BPF.EditorFrame.inspectorframe:Hide()
	BPF.EditorFrame.inspectorframe.positions = {}

	BPF.EditorFrame.inspectorframe.Paint = function( self, w, h )
		surface.SetDrawColor( 60, 60, 60, 255 )
		surface.DrawRect( 0, 0, w, h )
	end

	local positionnames = {"X", "Y", "Z"}

	local header = vgui.Create( "DLabel", BPF.EditorFrame.inspectorframe )
	header:SetFont( "Trebuchet24" )
	header:Dock( TOP )
	header:SetText( "Node Inspector" )

	local combotext = vgui.Create( "DLabel", BPF.EditorFrame.inspectorframe )
	combotext:Dock( TOP )
	combotext:SetText( "Node ID:" )

	local DComboBox = vgui.Create( "DComboBox", BPF.EditorFrame.inspectorframe )
	DComboBox:Dock( TOP )
	for k, v in pairs( BPF.NodeTypes ) do DComboBox:AddChoice( v["name"] ) end
	DComboBox.OnSelect = function( self, index, value )
		BPF:ChangeNodeID(BPF.InspectorNode, index) 
		BPF.EditorFrame.inspectorframe:Rebuild() 	
	end

	for i=1,3 do
		local positionxText = vgui.Create( "DLabel", BPF.EditorFrame.inspectorframe )
		positionxText:Dock( TOP )
		positionxText:SetText( "Node "..positionnames[i]..":" )

		BPF.EditorFrame.inspectorframe.positions[i] = vgui.Create( "DTextEntry", BPF.EditorFrame.inspectorframe )
		BPF.EditorFrame.inspectorframe.positions[i]:Dock( TOP )
		BPF.EditorFrame.inspectorframe.positions[i].OnEnter = function( self )
			BPF.Nodes[BPF.InspectorNode]["position"][i] = tonumber(self:GetValue())
		end
	end

	local pathButton = vgui.Create( "DButton", BPF.EditorFrame.inspectorframe )
	pathButton:SetText( "Pathfind" )
	pathButton:SetPos( 5, 576 - 5 )
	pathButton:SetSize( 64, 24 )
	pathButton.DoClick = function()
		local path = BPF:FindPath( LocalPlayer():GetPos(), BPF.Nodes[BPF.InspectorNode]["position"] )

		if #path < 1 then
			print("Failed To Find Path ;(")
			return
		end

		BPF.CurrentPath = path
	end		

	function BPF.EditorFrame.inspectorframe:Rebuild()
		local node = BPF.Nodes[BPF.InspectorNode]
		header:SetText( "Node Inspector - #"..BPF.InspectorNode )
		DComboBox:SetValue( BPF.NodeTypes[node["id"] or 1]["name"] )

		for i=1,3 do
			BPF.EditorFrame.inspectorframe.positions[i]:SetValue(node["position"][i])
		end

		if BPF.EditorFrame.inspectorframe.custom and IsValid(BPF.EditorFrame.inspectorframe.custom) then
			BPF.EditorFrame.inspectorframe.custom:Remove()
		end

		BPF.EditorFrame.inspectorframe.custom = vgui.Create( "DFrame", BPF.EditorFrame.inspectorframe )
		BPF.EditorFrame.inspectorframe.custom:DockMargin( -5, 0, -5, 30 )
		BPF.EditorFrame.inspectorframe.custom:Dock( FILL )
		BPF.EditorFrame.inspectorframe.custom:SetTitle( "" )
		BPF.EditorFrame.inspectorframe.custom:SetDraggable( false )
		BPF.EditorFrame.inspectorframe.custom:ShowCloseButton( false )

		BPF.EditorFrame.inspectorframe.custom.Paint = function( self, w, h ) end

		BPF:TryGetNodeFunction("onInspector", BPF.InspectorNode)(BPF.EditorFrame.inspectorframe.custom, BPF.InspectorNode)
	end
end

function BPF:ToggleEditor()
	BPF:LoadNodes()
	BPF.EditorMode = not BPF.EditorMode

	if BPF.EditorMode then
		BPF:CreateEditorFrame()
		RunConsoleCommand("developer", "1")
	else
		if BPF.EditorFrame and IsValid(BPF.EditorFrame) then
			BPF.EditorFrame:Close()
			BPF.EditorFrame = nil
		end
		RunConsoleCommand("developer", "0")
	end
end

hook.Add( "StartCommand", "bpf-startcommand", BPF.StartCommand)
hook.Add( "HUDPaint", "bpf-hudpaint", BPF.DrawEffects)
hook.Add( "CalcView", "bpf_camera", BPF.Camera)
hook.Add( "Think", "bpf_cameramovement", BPF.CameraMovement)

concommand.Add( "bpf_editor", function()  
	BPF:ToggleEditor()
end)

timer.Remove( "bpf-position" )
timer.Create( "bpf-position", 1, 0, function()
    net.Start( "bpf-position" )
    net.WriteVector(BPF.Position)
	net.SendToServer()
end )

--BPF:LoadNodes()

--------------------------------------------------------------------------------------------
------------------------------------------ CONFIG ------------------------------------------
--------------------------------------------------------------------------------------------

BPF.NodeTypes[1] = {
	["color"] = Color(255,255,255,255),
	["name"] = "Normal",

	["onEffect"] = function(node)
		surface.SetDrawColor( 255, 255, 255, 255 )
		for k, v in pairs( BPF.Nodes[node]["connected"] ) do
			if not v then
				continue
			end

			local targetNode = BPF.Nodes[k]

			BPF:DrawLine( targetNode["position"], BPF.Nodes[node]["position"] )
		end
	end,

	["onSelectEffect"] = function(node) end,
	["onInspector"] = function(frame, node) end,
	["onAStar"] = function(node, currentnode) return true end,
	["onRightClick"] = function(node) return false end,
	["onProcessNode"] = function(node) return false end
}

BPF.NodeTypes[2] = {
	["color"] = Color(52, 152, 235,255),
	["name"] = "One Way",

	["onInspector"] = function(frame, node)
		local text = vgui.Create( "DLabel", frame )
		text:Dock( TOP )
		text:SetText( "Block Access:" )

		for k, v in pairs( BPF.Nodes[node]["connected"] ) do
			BPF.Nodes[node]["baccess"] = BPF.Nodes[node]["baccess"] or {}
			BPF.Nodes[node]["baccess"][k] = BPF.Nodes[node]["baccess"][k] or false

			local DermaCheckbox = vgui.Create( "DCheckBoxLabel", frame )
			DermaCheckbox:Dock( TOP )
			DermaCheckbox:SetText( k )
			DermaCheckbox:SetValue( BPF.Nodes[node]["baccess"][k] )
			DermaCheckbox:SizeToContents()	

			function DermaCheckbox:OnChange( value )
				BPF.Nodes[node]["baccess"][k] = value
			end
		end
	end,

	["onEffect"] = function(node)
		surface.SetDrawColor( 3, 194, 252, 255 )
		for k, v in pairs( BPF.Nodes[node]["connected"] ) do
			if not v then
				continue
			end

			local targetNode = BPF.Nodes[k]
			BPF:DrawLine( targetNode["position"], BPF.Nodes[node]["position"] )


		end
	end,

	["onSelectEffect"] = function(node) 
		surface.SetDrawColor( 3, 194, 252, 255 )
		local currentnode = BPF.Nodes[node]
		for k, v in pairs( currentnode["connected"] ) do
			if not v then
				continue
			end

			local targetNode = BPF.Nodes[k]
			if not currentnode["baccess"] then
				return
			end

			if (currentnode["baccess"][k]) then
				BPF:DrawBox( targetNode["position"] + Vector(0,0,30), Angle(0,0,0), Vector(-5,-5,-5), Vector(5,5,5), Color( 255, 0, 0, 255 ) )
			else
				BPF:DrawBox( targetNode["position"] + Vector(0,0,30), Angle(0,0,0), Vector(-5,-5,-5), Vector(5,5,5), Color( 0, 255, 0, 255 ) )
			end
		end	
	end,

	["onAStar"] = function(node, current)	
		local nodeconnections = BPF.Nodes[node]["baccess"] or {}

		if nodeconnections[current] then 
			return false
		end

		return true
	end
}

BPF.NodeTypes[3] = {
	["color"] = Color(217, 127, 17,255),
	["name"] = "Condictional",

	["onInspector"] = function(frame, node)
		local text = vgui.Create( "DLabel", frame )
		text:Dock( TOP )
		text:SetText( "Condiction Code:" )

		local TextEntry = vgui.Create( "DTextEntry", frame ) 
		TextEntry:SetHeight( 200 )
		TextEntry:Dock( TOP )
		
		TextEntry:SetValue(BPF.Nodes[node]["ccode"] or "")
		TextEntry:SetMultiline( true )
		TextEntry.OnTextChanged = function( self )
			BPF.Nodes[node]["ccode"] = self:GetValue()
		end

		local testCodeButton = vgui.Create( "DButton", frame )
		testCodeButton:SetText( "Check Code" )
		testCodeButton:Dock( TOP )
		testCodeButton.DoClick = function()
			local nodecode = BPF.Nodes[node]["ccode"] or ""

			if #nodecode < 1 then 
				surface.PlaySound( "buttons/button10.wav" )
				print("error in code ;(")
				return	
			end

			local func = CompileString(nodecode, "TestCode")

			if func then
			   	surface.PlaySound( "buttons/blip1.wav" )
			   	print("Output: "..tostring(func()))
			   	return
			   	
			end

			surface.PlaySound( "buttons/button10.wav" )
			print("error in code ;(")
		end		
	end,

	["onAStar"] = function(node)
		local nodecode = BPF.Nodes[node]["ccode"] or ""

		if #nodecode < 1 then 
			return true
		end	

		local func = CompileString(nodecode, "TestCode")
		if func then
			return func()
		end

		return true
	end
}

BPF.NodeTypes[4] = {
	["color"] = Color(84, 33, 3,255),
	["name"] = "Door",

	["onRightClick"] = function(node) 
		local tr = BPF:ScreenToTraceLine(gui.MousePos())

		if tr.Entity and IsValid(tr.Entity) then
			local entClass = tr.Entity:GetClass()
			if entClass == "func_door_rotating" or entClass == "prop_door_rotating" then
				BPF.Nodes[node]["doors"] = BPF.Nodes[node]["doors"] or {}
				table.insert(BPF.Nodes[node]["doors"], tr.HitPos)

				return true
			end
		end

		return false 
	end,

	["onSelectEffect"] = function(node) 
		surface.SetDrawColor( 3, 194, 252, 255 )
		local currentnode = BPF.Nodes[node]
		for k, v in pairs( currentnode["doors"] or {} ) do
			if not v then
				continue
			end

			local data = v:ToScreen()

			if data.visible then
				cam.End3D()
				draw.DrawText(k, "TargetID", data.x, data.y, Color(255,255,255,255), TEXT_ALIGN_CENTER)
				cam.Start3D()

				BPF:DrawBox( v, Angle(0,0,0), Vector(-5,-5,-5), Vector(5,5,5), Color( 255, 0, 0, 255 ) )
			end
		end	
	end,

	["onInspector"] = function(frame, node)
		local text = vgui.Create( "DLabel", frame )
		text:Dock( TOP )
		text:SetText( "Doors:" )

		BPF.Nodes[node]["doorstiming"] = BPF.Nodes[node]["doorstiming"] or {}

		for k, v in pairs( BPF.Nodes[node]["doors"] or {} ) do
			BPF.Nodes[node]["doorstiming"][k] = BPF.Nodes[node]["doorstiming"][k] or 1
			local DermaNumSlider = vgui.Create( "DNumSlider", frame )
			DermaNumSlider:Dock( TOP )
			DermaNumSlider:SetText( k )
			DermaNumSlider:SetMin( 0 )
			DermaNumSlider:SetMax( 32 )
			DermaNumSlider:SetDecimals( 1 )
			DermaNumSlider:SetValue( BPF.Nodes[node]["doorstiming"][k] )

			DermaNumSlider.OnValueChanged = function( self, value )
				BPF.Nodes[node]["doorstiming"][k] = value
			end
		end		
	end,

	["onProcessNode"] = function(node)
		local itimer = 0
		local amount = #BPF.Nodes[node]["doorstiming"]
		BPF.Nodes[node]["doorstiming"] = BPF.Nodes[node]["doorstiming"] or {}
		for k, v in pairs( BPF.Nodes[node]["doors"] or {} ) do
			local timing = BPF.Nodes[node]["doorstiming"][k]
			itimer = itimer + timing

			timer.Simple( itimer + ((k-1) * 0.3), function() 
				LocalPlayer():SetEyeAngles(( v - LocalPlayer():GetShootPos() ):GetNormalized():Angle() )
				timer.Simple( 0.1, function() 
					RunConsoleCommand("+use")
					timer.Simple( 0.1, function() 
						RunConsoleCommand("-use")
					end )
				end )
			end )
		end

		timer.Simple( itimer + (amount * 0.3) + 0.5, function() 
			BPF.DisablePath = false
		end )

		return true
	end
}

BPF:LoadDoors()
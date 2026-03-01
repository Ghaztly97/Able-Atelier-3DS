local spriteTypes = {}
colors = {}

local mannequinRender = {}
local editor = {}
local toolsPanel = {}
local undoRedo = {}

local currentPatternState = {
	data1 = {},
	data2 = {},
	data3 = {},
	data4 = {},
	pallet = {}
}
local saveData_parsed = {}

local function shapeVertices(x, y)
	ox = (math.sin((x-17)/10)*32)*(0.8 + (y/48)) + 192/2
	oy = (y)*2.5 + 10 + (math.cos((x-17)/16)*16)*y/32

	return ox, oy
end

local vertices3d = {}
local x, y = 0, 0
for i = 1, 32*34 do
	x = x + 1
	if x > 32 then
		x = 1
		y = y + 1
	end

	local ox, oy = shapeVertices(x, y)
	table.insert(vertices3d, {x = ox, y = oy})
end

spriteTypes.fileTree = function(x, y, opts)
	local myself = baseSprite()
	local scripts = {}
	myself.screen = 'both'
	opts = opts or {}

	local currentDirectory = opts.directory or 'sdmc'
	local selection = 1
	
	local function setUpFileTree(t)
		local output = {}
		for i, item in ipairs(t) do
			table.insert(output, {name = item, type = love.filesystem.getInfo(currentDirectory..'/'..item).type})
		end

		table.sort(output, function(a, b)
			local aType = a.type
			local bType = b.type

			if false then
				aType = love.filesystem.getInfo(currentDirectory..'/'..a).type
				bType = love.filesystem.getInfo(currentDirectory..'/'..b).type
			elseif false then
				if string.find(a, '.') then
					aType = 'directory' else aType = 'file'
				end
				if string.find(b, '.') then
					bType = 'directory' else bType = 'file'
				end
			end

			if aType == 'file' and bType == 'directory' then
				return false
			elseif aType == 'directory' and bType == 'file' then
				return true
			end
		end)

		return output
	end

	local viewY = 0
	local fileTree = setUpFileTree(love.filesystem.getDirectoryItems(currentDirectory))

	myself.extraDraw = function(screen)
		if screen == 'left' or screen == 'top' then
			love.graphics.setColor(0, 0, 0, 0.4)
			love.graphics.rectangle('fill', 10, 10, 380, 220, 15)
			love.graphics.setColor(1,1,1)
			love.graphics.rectangle('line', 10, 10, 380, 220, 15)
			if selection ~= 0 then
				love.graphics.print('/..', 15, 15)
			else
				love.graphics.print('/..', 30, 15)
			end
			for i = 1 + viewY, #fileTree do
				local item = fileTree[i]
				if i - viewY > 14 then
					break
				end
				if item.type == 'directory' then
					love.graphics.setColor(1,1,0)
				elseif item.type == 'file' then
					love.graphics.setColor(0.5,0.5,1)
					if item.name == 'garden_plus.dat' or item.name == 'garden.dat' then
						if math.sin(love.timer.getTime()*4) > 0 then
							love.graphics.setColor(0,1,0.2)
						end
					end
				end

				if i == selection then
					love.graphics.print(item.name, 30, 15+(i - viewY)*12.5)
				else
					love.graphics.print(item.name, 15, 15+(i - viewY)*12.5)
				end
			end
			love.graphics.setColor(1,1,1)
			love.graphics.printf(currentDirectory, 15, 210, 370, 'left')
		elseif screen == 'bottom' then
			
		end
	end

	scripts.navigate = coroutine.create(function() 
		while true do
			if inputs.getAction('up') then
				if selection - viewY == 1 then
					viewY = clamp(viewY - 1, 0, #fileTree - 14)
				end
				selection = clamp(selection - 1, 0, #fileTree)
				while inputs.getAction('up') do
					coroutine.yield()
				end
			end
			if inputs.getAction('down') then
				if selection - viewY == 14 then
					viewY = clamp(viewY + 1, 0, #fileTree - 14)
				end
				selection = clamp(selection + 1, 0, #fileTree)
				while inputs.getAction('down') do
					coroutine.yield()
				end
			end

			if inputs.getAction('select') then
				if selection ~= 0 then
					if fileTree[selection].type == 'directory' then
						currentDirectory = currentDirectory..'/'..fileTree[selection].name
						fileTree = setUpFileTree(love.filesystem.getDirectoryItems(currentDirectory))
						selection = 1
						while inputs.getAction('select') do
							coroutine.yield()
						end
					elseif fileTree[selection].type == 'file' then
						if fileTree[selection].name == 'garden_plus.dat' then
							while inputs.getAction('select') do
								coroutine.yield()
							end
							broadcast('loadSave', currentDirectory..'/'..fileTree[selection].name)
							while inputs.getAction('select') do
								coroutine.yield()
							end
						end
					end
				else
					local endIndex = #currentDirectory
					for i = #currentDirectory, 1, -1 do
						if string.sub(currentDirectory, i, i) == '/' then
							endIndex = i-1
							break
						end
					end

					currentDirectory = string.sub(currentDirectory, 1, endIndex)
					fileTree = setUpFileTree(love.filesystem.getDirectoryItems(currentDirectory))
					selection = 1
					while inputs.getAction('select') do
						coroutine.yield()
					end
				end
			end

			if inputs.getAction('cancel') then
				local endIndex = #currentDirectory
				viewY = 0
				for i = #currentDirectory, 1, -1 do
					if string.sub(currentDirectory, i, i) == '/' then
						endIndex = i-1
						break
					end
				end

				currentDirectory = string.sub(currentDirectory, 1, endIndex)
				fileTree = setUpFileTree(love.filesystem.getDirectoryItems(currentDirectory))
				selection = 1
				while inputs.getAction('cancel') do
					coroutine.yield()
				end
			end
			coroutine.yield()
		end
	end)

	scripts.kill = coroutine.create(function() 
		while true do
			local received = receive('removeFiletree')
			if received then
				myself:destroy()
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

spriteTypes.patternRenderAndEditor = function()
	local myself = baseSprite()
	local scripts = {}
	local canvasView = camera.new(16, 13, 6)
	editor = myself
	keyInstances.editor = myself
	myself.screen = 'bottom'
	myself.activeTool = 'pen'
	myself.penSize = 1

	myself.activeEditor = {}

	myself.patternCanvas = love.graphics.newCanvas(32, 32)

	myself.palletCanvas = love.graphics.newCanvas(320, 35)
	myself.majorPallet = nil
	myself.selectedColor = 1

	local function updatePatternCanvas(pixelTable, pallet, isUndoRedo, oldPixelTable)
		local oldCanvas = love.graphics.getCanvas()
		local x = 1
		local y = 0
		love.graphics.setCanvas(myself.patternCanvas)
		--love.graphics.print(tostring(#pixelTable))
		for i, pixel in ipairs(pixelTable) do
			if isUndoRedo then
				if oldPixelTable[i] ~= pixel then
					love.graphics.setColor(hex(colors[pallet[pixel+1]+1]))
					love.graphics.rectangle('fill', x-1, y, 1, 1)
				end
			else
				love.graphics.setColor(hex(colors[pallet[pixel+1]+1]))
				love.graphics.rectangle('fill', x-1, y, 1, 1)
			end

			x = x + 1
			if x > 32 then
				x = 1
				y = y + 1
			end
		end
		love.graphics.setCanvas(oldCanvas)
	end

	local palletOpen = false
	myself.debounce = false
	myself.extraDraw = function(screen)
		if not myself.majorPallet then
			myself.majorPallet = love.graphics.newCanvas(320, 240)
			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(myself.majorPallet)
			love.graphics.clear()

			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.rectangle('fill', 20, 20, 320-40, 240-40, 15)
			local x, y = 1, 0
			for y=1, 16 do
				for x = 1, 9 do
					local index = (y-1)*16+x
					love.graphics.setColor(hex(colors[index]))
					love.graphics.rectangle('fill', 15+x*15, 9.5+y*12.5, 15, 10)
				end
			end
			for y=1, 15 do
				for x = 16, 16 do
					local index = (y-1)*16+x
					love.graphics.setColor(hex(colors[index]))
					love.graphics.rectangle('fill', 15+(11)*15, 9.5+y*12.5, 15, 10)
				end
			end

			love.graphics.setCanvas(oldCanvas)
		end
		local updateCanvas = receive('updateCanvas')
		if updateCanvas then
			if type(updateCanvas) == 'table' then
				updatePatternCanvas(myself.activeEditor, currentPatternState.pallet, true, updateCanvas.oldPixelTable)
			else
				updatePatternCanvas(myself.activeEditor, currentPatternState.pallet)
			end

			-- redraw the pallet:
			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(myself.palletCanvas)
			love.graphics.clear()
			love.graphics.setColor(0.7, 0.5, 0.5)
			love.graphics.rectangle('fill', 0, -15, 320, 50, 15)
			for i, color in ipairs(currentPatternState.pallet) do
				love.graphics.setColor(hex(colors[color+1]))
				love.graphics.rectangle('fill', 2.5+(i-1)*20, 10, 15, 15, 2)
				local r, g, b =  love.graphics.getColor()
				love.graphics.setColor(r*0.5, g*0.5, b*0.5)
				love.graphics.rectangle('line', 2.5+(i-1)*20, 10, 15, 15, 2)
			end
			love.graphics.setCanvas(oldCanvas)
		end

		if touch.down and not myself.debounce and touch.y > 35 then
			local oldCanvas = love.graphics.getCanvas()
			local x, y = canvasView:worldCoords(touch.x, touch.y)
			if not (x < 0 or x > 32 or y < 0 or y > 31) then
				love.graphics.setCanvas(myself.patternCanvas)
				love.graphics.setColor(hex(colors[currentPatternState.pallet[myself.selectedColor]+1]))
				if myself.penSize == 1 then
					x, y = math.floor(x), math.floor(y)
					love.graphics.rectangle('fill', x, y, 1, 1)
					myself.activeEditor[(y)*32+(x)+1] = myself.selectedColor-1
				elseif myself.penSize == 2 then
					x, y = math.floor(x + 0.5), math.floor(y + 0.5)
					love.graphics.rectangle('fill', x-1, y-1, 2, 2)
					for py = -1, 0 do
						for px = -1, 0 do
							if x + px < 32 and x + px > 0 and  y + py <= 32 and y + py >= 0 then
								myself.activeEditor[(y+py)*32+(x+px)+1] = myself.selectedColor-1
							end
						end
					end
				elseif myself.penSize == 3 then
					x, y = math.floor(x), math.floor(y)
					love.graphics.rectangle('fill', x-1, y-1, 3, 3)
					for py = -1, 1 do
						for px = -1, 1 do
							if x + px < 32 and x + px > 0 and  y + py <= 32 and y + py >= 0 then
								myself.activeEditor[(y+py)*32+(x+px)+1] = myself.selectedColor-1
							end
						end
					end
				end
				
				love.graphics.setCanvas(oldCanvas)

				-- edit mannequin aswell
				if myself.activeEditor == currentPatternState.data1 then
					love.graphics.setCanvas(mannequinRender.mannequinFront)
				elseif myself.activeEditor == currentPatternState.data2 then
					love.graphics.setCanvas(mannequinRender.mannequinBack)
				else
					love.graphics.setCanvas(mannequinRender.mannequinFront)
				end

				vertices = {}
				if myself.penSize == 1 then
					vertices[1], vertices[2] = shapeVertices(x+1, y)
					vertices[3], vertices[4] = shapeVertices(x+2, y)
					vertices[5], vertices[6] = shapeVertices(x+2, y+1)
					vertices[7], vertices[8] = shapeVertices(x+1, y+1)
				elseif myself.penSize == 2 then
					vertices[1], vertices[2] = shapeVertices(x, y-1)
					vertices[3], vertices[4] = shapeVertices(x+1, y-1)
					vertices[5], vertices[6] = shapeVertices(x+2, y-1)

					vertices[7], vertices[8] = shapeVertices(x+2, y+1)
					vertices[9], vertices[10] = shapeVertices(x+1, y+1)
					vertices[9], vertices[10] = shapeVertices(x, y+1)
				elseif myself.penSize == 3 then
					vertices[1], vertices[2] = shapeVertices(x, y-1)
					vertices[3], vertices[4] = shapeVertices(x+1, y-1)
					vertices[5], vertices[6] = shapeVertices(x+2, y-1)
					vertices[7], vertices[8] = shapeVertices(x+3, y-1)

					vertices[9], vertices[10] = shapeVertices(x+3, y+2)
					vertices[11], vertices[12] = shapeVertices(x+2, y+2)
					vertices[13], vertices[14] = shapeVertices(x+1, y+2)
					vertices[15], vertices[16] = shapeVertices(x, y+2)
				end

				love.graphics.polygon('fill', vertices)
				love.graphics.setColor(1,1,1)

				love.graphics.setCanvas(oldCanvas)
			end
		end

		canvasView:attach()
		love.graphics.draw(myself.patternCanvas, 0, 0, 0)
		love.graphics.setColor(1,1,1)
		
		canvasView:detach()

		-- draw pallet
		love.graphics.draw(myself.palletCanvas)
		love.graphics.setColor(1,1,0)
		love.graphics.rectangle('line', 2+(myself.selectedColor-1)*20, 9.5, 16, 16, 2)
		love.graphics.setColor(1,1,1)

		if palletOpen then
			love.graphics.draw(myself.majorPallet)
		end

		if myself.switchingActiveEditor then
			love.graphics.setColor(0,0,0,0.5)
			love.graphics.rectangle('fill', 0, 0, 320, 240)
			for i, part in ipairs(myself.switchOptions) do
				love.graphics.setColor(1,1,1)
				love.graphics.printf(part, 135+math.cos((i/4)*math.pi*2)*50, 120+math.sin((i/4)*math.pi*2)*50, 50, 'center')
			end
		end
	end

	myself.updateCanvas = false
	scripts.receivePatterns = coroutine.create(function() 
		while true do
			local received = receive('saveParsed')
			if not myself.updateCanvas then
				myself.updateCanvas = (received ~= nil)
			end
			if received then
				saveData_parsed = received
				
				currentPatternState.data1 = patternStringToTable(received.patternData1)
				currentPatternState.data2 = patternStringToTable(received.patternData2)
				currentPatternState.data3 = patternStringToTable(received.patternData3)
				currentPatternState.data4 = patternStringToTable(received.patternData4)
				currentPatternState.pallet = saveData_parsed.pallet

				myself.activeEditor = currentPatternState.data1
				broadcast('mannequinUpdate')
				broadcast('updateCanvas')

				myself.history[#myself.history + 1] = {
					data1 = tableToPatternString(currentPatternState.data1),
					data2 = tableToPatternString(currentPatternState.data2),
					data3 = tableToPatternString(currentPatternState.data3),
					data4 = tableToPatternString(currentPatternState.data4)
				}

				if saveData_parsed.patternType == 'LongSleeveDress' then
					
				end
			end
			coroutine.yield()
		end
	end)

	myself.switchingActiveEditor = false
	myself.switchOptions = {'Front', 'Back', 'Sleeves', 'Lower Dress'}
	scripts.switchActiveEditor = coroutine.create(function()
		while true do
			if inputs.getAction('x') then
				myself.switchingActiveEditor = true
				while inputs.getAction('x') do
					coroutine.yield()
				end
				myself.switchingActiveEditor = false
			end
			coroutine.yield()
		end
	end)

	scripts.cameraControl = coroutine.create(function() 
		while true do
			local stick = inputs.getAction('stick')
			local dx = stick.dx * math.cos(-canvasView.rot) - stick.dy * math.sin(-canvasView.rot)
			local dy = stick.dx * math.sin(-canvasView.rot) + stick.dy * math.cos(-canvasView.rot)
			if math.abs(dx) < 0.1 then
				dx = 0
			end
			if math.abs(dy) < 0.1 then
				dy = 0
			end
			canvasView:move(dx*2.5, dy*2.5)
			if inputs.getAction('left') and touch.down then
				local oldZoom = canvasView.scale
				local oldTy = touch.y
				myself.debounce = true
				while touch.down do
					canvasView:zoomTo(clamp(oldZoom + (oldTy - touch.y)*0.1, 1, 15))
					coroutine.yield()
				end
				myself.debounce = false
			elseif inputs.getAction('right') and touch.down then
				local startRot = getDirection(320/2, 240/2, touch.x, touch.y)
				local oldRot = canvasView.rot
				myself.debounce = true
				while touch.down do
					local extraRot = getDirection(320/2, 240/2, touch.x, touch.y) - startRot
					canvasView:rotateTo(oldRot + extraRot)
					coroutine.yield()
				end
				myself.debounce = false
			elseif inputs.getAction('up') and touch.down then
				local anchorx, anchory = canvasView.x, canvasView.y
				local oldTx, oldTy = touch.x, touch.y
				myself.debounce = true
				while touch.down do
					local dx = (oldTx - touch.x) * math.cos(-canvasView.rot) - (oldTy - touch.y) * math.sin(-canvasView.rot)
					local dy = (oldTx - touch.x) * math.sin(-canvasView.rot) + (oldTy - touch.y) * math.cos(-canvasView.rot)
					canvasView:lookAt(anchorx + dx/canvasView.scale, anchory + dy/canvasView.scale)
					coroutine.yield()
				end
				myself.debounce = false
			end

			coroutine.yield()
		end
	end)

	scripts.colorSelect = coroutine.create(function()
		local palletBarHitboxes = {}
		local largePalletHitboxes = {}
		for i=1, 15 do
			palletBarHitboxes[i] = HC.rectangle(2.5+(i-1)*20, 10, 15, 15)
		end
		for y=1, 16 do
			for x = 1, 9 do
				local index = (y-1)*16+x
				local hitbox = HC.rectangle(15+x*15, 9.5+y*12.5, 15, 10)
				hitbox.index = index
				table.insert(largePalletHitboxes, hitbox)
			end
		end

		for y=1, 15 do
			for x = 11, 11 do
				local index = (y-1)*16+(16)
				local hitbox = HC.rectangle(15+x*15, 9.5+y*12.5, 15, 10)
				hitbox.index = index
				table.insert(largePalletHitboxes, hitbox)
			end
		end
		while true do
			if touch.down and touch.y < 35 then
				local clicked = false
				for i, hitbox in ipairs(palletBarHitboxes) do
					if hitbox:contains(touch.x, touch.y) then
						myself.selectedColor = i
						clicked = true
					end
				end
				if clicked then
					local timer = 0
					while touch.down do
						timer = timer + love.timer.getDelta()
						if timer > 0.5 then
							palletOpen = true
							myself.debounce = true
							while touch.down do
								coroutine.yield()
							end
							while palletOpen do
								if touch.down then
									for v, largePalletHitbox in ipairs(largePalletHitboxes) do
										if largePalletHitbox:contains(touch.x, touch.y) then
											currentPatternState.pallet[myself.selectedColor] = largePalletHitbox.index - 1
											broadcast('mannequinUpdate')
											broadcast('updateCanvas')
											break
										end
									end
									while touch.down do
										coroutine.yield()
									end
									break
								end
								coroutine.yield()
							end
							palletOpen = false
							myself.debounce = false
							break
						end
						coroutine.yield()
					end
				end
			else
				while touch.down do
					coroutine.yield()
				end
			end
			coroutine.yield()
		end
	end)

	scripts.save = coroutine.create(function()
		while true do
			if inputs.getAction('start') then
				broadcast('saveEditedFile', currentPatternState)
				toolsPanel:destroy()
				mannequinRender:destroy()
				undoRedo:destroy()
				coroutine.yield()

				-- try removing references for garbagecollect
				-- fix this shit later so that canvases are just reused
				keyInstances.editor = nil
				keyInstances.mannequinRender = nil
				keyInstances.toolsPanel = nil

				editor = nil
				mannequinRender = nil
				toolsPanel = nil

				coroutine.yield()
				collectgarbage('collect')
				coroutine.yield()
				myself:destroy()
				while inputs.getAction('start') do
					coroutine.yield()
				end
			end
			coroutine.yield()
		end
	end)

	myself.undoPointer = 0
	myself.history = {}
	scripts.history = coroutine.create(function()
		while true do
			if touch.down and not myself.debounce then
				local x, y = canvasView:worldCoords(touch.x, touch.y)
				x, y = math.floor(x), math.floor(y)
				if not (x < 0 or x > 32 or y < 0 or y > 31) and not (undoRedo.hitboxes[1]:contains(touch.x, touch.y) or undoRedo.hitboxes[2]:contains(touch.x, touch.y)) then
					if myself.undoPointer ~= 0 then
						local start = #myself.history - myself.undoPointer + 1
						for i = start, #myself.history do
							table.remove(myself.history, start)
						end
						myself.undoPointer = 0
					end
					while touch.down do
						coroutine.yield()
					end
					myself.history[#myself.history + 1] = {
						data1 = tableToPatternString(currentPatternState.data1),
						data2 = tableToPatternString(currentPatternState.data2),
						data3 = tableToPatternString(currentPatternState.data3),
						data4 = tableToPatternString(currentPatternState.data4)
					}
					if #myself.history > 5 then
						table.remove(myself.history, 1)
					end
				end
			end
			coroutine.yield()
		end
	end)
	scripts.undoRedo = coroutine.create(function() 
		while true do
			if receive('undo') then
				local snapshot = myself.history[#myself.history - (myself.undoPointer + 1)]
				if snapshot then
					myself.undoPointer = myself.undoPointer + 1
					local oldPixelTable = tableToPatternString(myself.activeEditor)
					local data1 = tableToPatternString(currentPatternState.data1)
					local data2 = tableToPatternString(currentPatternState.data2)
					local packet = {
						oldPixelTable = patternStringToTable(oldPixelTable), -- for the current active bottom screen editor
						data1 = patternStringToTable(data1), -- to update mannequins
						data2 = patternStringToTable(data2),
					}

					currentPatternState.data1 = patternStringToTable(snapshot.data1)
					currentPatternState.data2 = patternStringToTable(snapshot.data2)
					currentPatternState.data3 = patternStringToTable(snapshot.data3)
					currentPatternState.data4 = patternStringToTable(snapshot.data4)
					myself.activeEditor = currentPatternState.data1

					broadcast('mannequinUpdate', packet)
					broadcast('updateCanvas', packet)
				end
			end
			if receive('redo') then
				local snapshot = myself.history[#myself.history - (myself.undoPointer - 1)]
				if snapshot then
					myself.undoPointer = myself.undoPointer - 1
					local oldPixelTable = tableToPatternString(myself.activeEditor)
					local data1 = tableToPatternString(currentPatternState.data1)
					local data2 = tableToPatternString(currentPatternState.data2)
					local packet = {
						oldPixelTable = patternStringToTable(oldPixelTable), -- for the current active bottom screen editor
						data1 = patternStringToTable(data1), -- to update mannequins
						data2 = patternStringToTable(data2),
					}

					currentPatternState.data1 = patternStringToTable(snapshot.data1)
					currentPatternState.data2 = patternStringToTable(snapshot.data2)
					currentPatternState.data3 = patternStringToTable(snapshot.data3)
					currentPatternState.data4 = patternStringToTable(snapshot.data4)
					myself.activeEditor = currentPatternState.data1

					broadcast('mannequinUpdate', packet)
					broadcast('updateCanvas', packet)
				end
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

spriteTypes.mannequinRender = function()
	local myself = baseSprite()
	local scripts = {}
	mannequinRender = myself
	keyInstances.mannequinRender = myself
	myself.finalCanvas = love.graphics.newCanvas(400, 240)

	myself.mannequinFront = love.graphics.newCanvas(192, 192)
	myself.mannequinBack = love.graphics.newCanvas(192, 192)

	local function refreshMannequin(pixelTable, pallet, canvas, isUndoRedo, oldPixelTable)
		local oldCanvas = love.graphics.getCanvas()
		local x = 1
		local y = 1
		love.graphics.setCanvas(canvas)
		love.graphics.setColor(1,1,1)
		--love.graphics.rectangle('line', 0, 0, 128+64, 128+64)
		for i, pixel in ipairs(pixelTable) do
			
			local vertices = {}

			local index = i
			vertices[1], vertices[2] = vertices3d[index].x, vertices3d[index].y

			if i % 32 ~= 0 then
				local index = i + 1
				vertices[3], vertices[4] = vertices3d[index].x, vertices3d[index].y

				local index = i + 1 + 32
				vertices[5], vertices[6] = vertices3d[index].x, vertices3d[index].y
			else
				local index = i
				vertices[3], vertices[4] = vertices3d[index].x, vertices3d[index].y

				local index = i + 32
				vertices[5], vertices[6] = vertices3d[index].x, vertices3d[index].y
			end

			local index = i + 32
			vertices[7], vertices[8] = vertices3d[index].x, vertices3d[index].y

			if isUndoRedo then
				if oldPixelTable[i] ~= pixel then
					love.graphics.setColor(hex(colors[pallet[pixel+1]+1]))
					love.graphics.polygon('fill', vertices)
				end
			else
				love.graphics.setColor(hex(colors[pallet[pixel+1]+1]))
				love.graphics.polygon('fill', vertices)
			end

			x = x + 1
			if x > 32 then
				x = 1
				y = y + 1
			end
		end
		love.graphics.setCanvas(oldCanvas)
	end

	myself.mannequinUpdate = false
	local mannequinShading = love.graphics.newCanvas(192, 192)
	local showTable = {
		'LongSleeveDress', 'ShortSleeveDress', 'SleevelessDress', 'ShortSleeveShirt', 'SleevelessShirt'
	}
	local glyphs = {
		dpright = utf8.char(0xe07c),
		dpleft = utf8.char(0xe07b),
		dpdown = utf8.char(0xe07a),
		dpup = utf8.char(0xe079),
		cpad = utf8.char(0xe077),
		a = utf8.char(0xe000),
		y = utf8.char(0xe003)
	}
	local font = love.graphics.newFont(18)
	local defaultfont = love.graphics.newFont()
	local text = glyphs.dpright..': Rotate view w/ stylus\n'..glyphs.dpleft..': Zoom w/ stylus\n'..glyphs.dpup..': Pan w/ stylus\n'..glyphs.cpad..': Pan w/ C-Pad\n'..glyphs.a..': Open tools panel\n'
	myself.extraDraw = function()
		love.graphics.setColor(1,1,1)
		local mannequinUpdate = receive('mannequinUpdate')
		if mannequinUpdate and tableContains(showTable, saveData_parsed.patternType) then
			if type(mannequinUpdate) == 'table' then
				refreshMannequin(currentPatternState.data1, currentPatternState.pallet, myself.mannequinFront, true, mannequinUpdate.data1)
				refreshMannequin(currentPatternState.data2, currentPatternState.pallet, myself.mannequinBack, true, mannequinUpdate.data2)
			else
				refreshMannequin(currentPatternState.data1, currentPatternState.pallet, myself.mannequinFront)
				refreshMannequin(currentPatternState.data2, currentPatternState.pallet, myself.mannequinBack)
			end

			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(mannequinShading)
			love.graphics.setColor(0.5,0.5,0.5)
			love.graphics.rectangle('fill', 0, 0, 192, 192)
			love.graphics.setColor(0.7,0.7,0.7)
			love.graphics.circle('fill', 192/2 + 90, 35, 120)
			love.graphics.setColor(1,1,1)
			love.graphics.circle('fill', 192/2 + 70, 25, 90)
			love.graphics.setCanvas(oldCanvas)
		end

		if saveData_parsed.patternType ~= 'Pattern' then
			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(myself.finalCanvas)
			love.graphics.clear()

			love.graphics.setColor(1,1,1)
			love.graphics.draw(myself.mannequinFront, 100, 240, 0, 1,1 , 192/2, 192)
			love.graphics.draw(myself.mannequinBack, 300, 240, 0, 1,1 , 192/2, 192)

			love.graphics.setBlendMode('multiply', 'premultiplied')
			love.graphics.draw(mannequinShading, 100, 240, 0, 1,1 , 192/2, 192)
			love.graphics.draw(mannequinShading, 300, 240, 0, 1,1 , 192/2, 192)
			love.graphics.setBlendMode('alpha')
			love.graphics.setCanvas(oldCanvas)
		else
			love.graphics.draw(editor.patternCanvas, 200, 120, 0, 6, 6, 16, 16)
		end

		love.graphics.draw(myself.finalCanvas)

		love.graphics.setFont(font)
		love.graphics.printf('Hold '..glyphs.y..' to see controls.', 0, 220, 400, 'center')
		love.graphics.setFont(defaultfont)
		if inputs.getAction('y') then
			love.graphics.setColor(0,0,0,0.5)
			love.graphics.rectangle('fill', 0, 0, 400, 240)
			love.graphics.setColor(1,1,1)
			love.graphics.setFont(font)
			love.graphics.printf(text,100, 25, 200,"center")
			love.graphics.setFont(defaultfont)
		end
	end

	myself.scripts = scripts
	return myself
end

spriteTypes.toolsPanel = function(x, y)
	local myself = baseSprite()
	local scripts = {}
	local icons = {
		long = love.graphics.newImage('assets/images/button_size1.png'),
		short = love.graphics.newImage('assets/images/button_size2.png'),
		pencil = love.graphics.newImage('assets/images/pencil.png')
	}
	myself.x, myself.y = x, y
	toolsPanel = myself
	keyInstances.toolsPanel = myself
	myself.debounce = false
	myself.visible = false
	myself.trayOpen = false

	myself.screen = 'bottom'
	local hitboxes = {
		HC.rectangle(myself.x + 5, myself.y + 10, 45*1.2, 31),
		HC.rectangle(myself.x + 60+5, myself.y + 10, 45*1.2, 31),
		HC.rectangle(myself.x + 5, myself.y + 45 + 10, 45*1.2, 31),
		HC.rectangle(myself.x + 60+5, myself.y + 45 + 10, 45*1.2, 31),
		HC.rectangle(myself.x + 10, myself.y + 45*2 + 10, 89*1.2, 31),
	}
	myself.extraDraw = function()
		if myself.visible then
			love.graphics.setLineWidth(2.5)
			love.graphics.setColor(0.8, 0.6, 0.3)
			love.graphics.rectangle('fill', myself.x, myself.y, 135, 150, 15)
			love.graphics.setColor(0.5, 0.2, 0.1)
			love.graphics.rectangle('line', myself.x, myself.y, 135, 150, 15)
			love.graphics.setLineWidth(1)

			love.graphics.setColor(0.9, 0.7, 0.4)
			love.graphics.draw(icons.short, myself.x + 5, myself.y + 10, 0, 1.2, 1.2)
			love.graphics.draw(icons.short, myself.x + 60+5, myself.y + 10, 0, 1.2, 1.2)
			love.graphics.draw(icons.short, myself.x + 5, myself.y + 45 + 10, 0, 1.2, 1.2)
			--love.graphics.draw(icons.short, myself.x + 60+5, myself.y + 45 + 10, 0, 1.2, 1.2)

			love.graphics.draw(icons.long, myself.x + 10, myself.y + 45*2 + 10, 0, 1.2, 1.2)

			love.graphics.setColor(0.5, 0.2, 0.1)
			love.graphics.draw(icons.pencil, myself.x + 5 + 12.5, myself.y + 10 + 33, (-5/4)*math.pi, 1, 1, 40, 4)
			love.graphics.print('1', myself.x + 5 + 5, myself.y + 10 + 2.5, 0)
			love.graphics.draw(icons.pencil, myself.x + 60+5 + 12.5, myself.y + 10 + 33, (-5/4)*math.pi, 1, 1, 40, 4)
			love.graphics.print('2', myself.x + 60+5 + 5, myself.y + 10 + 2.5, 0)
			love.graphics.draw(icons.pencil, myself.x + 5 + 12.5, myself.y + 45 + 10 + 33, (-5/4)*math.pi, 1, 1, 40, 4)
			love.graphics.print('3', myself.x + 5 + 5, myself.y + 45 + 10 + 2.5, 0)

			--love.graphics.setColor(1,0,0)
			--for i, hitbox in ipairs(hitboxes) do
			--	love.graphics.print(tostring(i), hitbox._polygon.centroid.x, hitbox._polygon.centroid.y)
			--	hitbox:draw()
			--end
		end
	end

	scripts.show = coroutine.create(function() 
		while true do
			if inputs.getAction('select') and not myself.debounce then
				if not myself.trayOpen then
					myself.x = 320
					local timer = 0
					local length = 0.5
					myself.visible = true
					myself.debounce = true
					editor.debounce = true
					undoRedo.debounce = true
					while timer/length < 1 do
						timer = timer + love.timer.getDelta()
						myself.x = lerp(timer/length, 320, 320-123, 'sineInOut')
						coroutine.yield()
					end
					myself.debounce = false
					myself.trayOpen = true
				else
					myself.x = 320 - 120
					local timer = 0
					local length = 0.5
					myself.debounce = true
					while timer/length < 1 do
						timer = timer + love.timer.getDelta()
						myself.x = lerp(timer/length, 320-123, 320, 'sineInOut')
						coroutine.yield()
					end
					myself.visible = false
					myself.debounce = false
					myself.trayOpen = false
					editor.debounce = false
					undoRedo.debounce = false
				end
			end
			coroutine.yield()
		end
	end)

	editor.activeTool = 'pen'
	editor.penSize = 1
	scripts.toolChange = coroutine.create(function()
		local clickedButton = 1
		while true do
			if myself.trayOpen and not myself.debounce and touch.down then
				for i, hitbox in ipairs(hitboxes) do
					if hitbox:contains(touch.x, touch.y) then
						clickedButton = i
						break
					end
				end
				if clickedButton <= 3 then
					editor.activeTool = 'pen'
					editor.penSize = clickedButton
				end
				if clickedButton == 5 then
					broadcast('quitCheck')
					editor.debounce = true
					myself.debounce = true
					while true do
						local received = receive('quitResponse')
						if received == 0 then
							break
						end
						if received == 1 then
							editor:destroy()
							mannequinRender:destroy()
							undoRedo:destroy()
							coroutine.yield()

							-- try removing references for garbagecollect
							-- fix this shit later so that canvases are just reused
							keyInstances.editor = nil
							keyInstances.mannequinRender = nil
							keyInstances.toolsPanel = nil

							editor = nil
							mannequinRender = nil
							toolsPanel = nil

							coroutine.yield()
							collectgarbage('collect')
							coroutine.yield()
							myself:destroy()
							broadcast('selectPlayer')
						end
						coroutine.yield()
					end
					editor.debounce = false
					myself.debounce = false
				end
				while touch.down do
					coroutine.yield()
				end
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

spriteTypes.undoRedo = function(x, y)
	local myself = baseSprite()
	local scripts = {}
	undoRedo = myself
	myself.screen = 'bottom'

	local arrow = love.graphics.newImage('assets/images/arrow.png')
	myself.hitboxes = {
		HC.rectangle(320-70, 205, 35, 30),
		HC.rectangle(320-35, 205, 35, 30),
	}
	myself.extraDraw = function()
		love.graphics.setColor(0.3,0.2,0.5)
		love.graphics.rectangle('fill', 320-70, 200, 70, 50, 10)
		
		love.graphics.setColor(0.3/2,0.2/2,0.5/2)
		love.graphics.draw(arrow, 320-30, 210)
		love.graphics.draw(arrow, 320-40, 210, 0, -1, 1)
		
		love.graphics.setColor(1,1,1)

		for i, hitbox in ipairs(myself.hitboxes) do
		--	hitbox:draw('line')
		end
	end

	myself.debounce = false
	scripts.undeRedo = coroutine.create(function() 
		while true do
			if touch.down and not myself.debounce then
				local clicked = false
				if myself.hitboxes[1]:contains(touch.x, touch.y) then --undo
					clicked = true
					broadcast('undo')
				elseif myself.hitboxes[2]:contains(touch.x, touch.y) then --redo
					clicked = true
					broadcast('redo')
				else
					while touch.down do
						coroutine.yield()
					end
				end
				if clicked then
					editor.debounce = true
					while touch.down do
						coroutine.yield()
					end
					editor.debounce = false
				end
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

colors = {
'ffeeff','ff99aa','ee5599','ff66aa','ff0066','bb4477','cc0055','990033','552233','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff',
'ffbbcc','ff7777','dd3311','ff5544','ff0000','cc6666','bb4444','bb0000','882222','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','eeeeee',
'ddccbb','ffcc66','dd6622','ffaa22','ff6600','bb8855','dd4400','bb4400','663311','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','dddddd',
'ffeedd','ffddcc','ffccaa','ffbb88','ffaa88','dd8866','bb6644','995533','884422','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','cccccc',
'ffccff','ee88ff','cc66dd','bb88cc','cc00ff','996699','8800aa','550077','330044','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','bbbbbb',
'ffbbff','ff99ff','dd22bb','ff55ee','ff00cc','885577','bb0099','880066','550044','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','aaaaaa',
'ddbb99','ccaa77','774433','aa7744','993300','773322','552200','331100','221100','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','999999',
'ffffcc','ffff77','dddd22','ffff00','ffdd00','ccaa00','999900','887700','555500','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','888888',
'ddbbff','bb99ee','6633cc','9955ff','6600ff','554488','440099','220066','221133','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','777777',
'bbbbff','8899ff','3333aa','3355ee','0000ff','333388','0000aa','111166','000022','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','666666',
'99eebb','66cc77','226611','44aa33','008833','557755','225500','113322','002211','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','555555',
'ddffbb','ccff88','88aa55','aadd88','88ff00','aabb99','66bb00','559900','336600','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','444444',
'bbddff','77ccff','335599','6699ff','1177ff','4477aa','224477','002277','001144','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','333333',
'aaffff','55ffff','0088bb','55bbcc','00ccff','4499aa','006688','004455','002233','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','222222',
'ccffee','aaeedd','33ccaa','55eebb','00ffcc','77aaaa','00aa99','008877','004433','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','000000',
'aaffaa','77ff77','66dd44','00ff00','22dd22','55bb55','00bb00','008800','224422','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff','ffffff'
}


return spriteTypes
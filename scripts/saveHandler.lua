local spriteTypes = {}

--[[ Pattern structure (borrowed from Thulinma http://www.thulinma.com/acnl/)
0x000 - 0x029 ( 42) = Pattern Title
0x02A - 0x02B (  2) = User ID
0x02C - 0x03D ( 18) = User Name
0x03E         (  1) = User Gender
0x03F         (  1) = ZeroFiller
0x040 - 0x041 (  2) = Town ID
0x042 - 0x055 ( 20) = Town Name
0x056 - 0x057 (  2) = Unknown (values are usually random - changing seems to have no effect)
0x058 - 0x066 ( 15) = Palette Indexes
0x067		  (  1) = Unknown (value is usually random - changing seems to have no effect)
0x068		  (  1) = Ten? (seems to always be 0x0A)
0x069		  (  1) = Pattern Type 
0x06A - 0x06B (  2) = Padding? (seems to always be 0x0000)
0x06C - 0x26B (512) = Pattern Data 1 (mandatory)
0x26C - 0x46B (512) = Pattern Data 2 (optional)
0x46C - 0x66B (512) = Pattern Data 3 (optional)
0x66C - 0x86B (512) = Pattern Data 4 (optional)
0x86C - 0x86F (  4) = Zero padding (optional)

Pattern Types:
	0x00 = LongSleeveDress
	0x01 = ShortSleeveDress
	0x02 = SleevelessDress
	0x03 = LongSleeveShirt
	0x04 = ShortSleeveShirt
	0x05 = SleevelessShirt
	0x06 = HornedHat
	0x07 = KnitHat
	0x08 = PhotoBoard
	0x09 = Pattern
]]

local patternStructure = {}

local function readBytes(startByte, endByte, optTable)
    optTable = optTable or {}
    local cutZeroes = optTable.cutZeroes or false
    local utf8_safe = optTable.utf8_safe or false

    startByte, endByte = startByte + 1, endByte + 1 -- accounts for lua indexes starting at 1
    local bytes = {}

    for i = startByte, endByte do
        local b = string.byte(globalSave, i)
        if not (cutZeroes and b == 0x00) then
            table.insert(bytes, string.char(b))
        end
    end

    local output = table.concat(bytes)

    if utf8_safe then
        -- Try to fix invalid UTF-8 sequences by removing or replacing bad bytes
        output = output:gsub("[^\x09\x0A\x0D\x20-\x7E\xC2-\xF4][\x80-\xBF]*", "?")
    end

    return output
end


spriteTypes.saveHandler = function()
	local myself = baseSprite()
	local scripts = {}
	keyInstances.saveHandler = myself
	myself.screen = 'bottom'

	local parsedTable = {}
	local drawBottomScreenUI = false
	myself.patternCanvas = love.graphics.newCanvas(32*5, 32*2)
	local canvasCamera = camera.new((32*5)/2, (32*2)/2, 2)

	local patternTypes = {
		[string.char(0x00)] = 'LongSleeveDress',
		[string.char(0x01)] = 'ShortSleeveDress',
		[string.char(0x02)] = 'SleevelessDress',
		[string.char(0x03)] = 'LongSleeveShirt',
		[string.char(0x04)] = 'ShortSleeveShirt',
		[string.char(0x05)] = 'SleevelessShirt',
		[string.char(0x06)] = 'HornedHat',
		[string.char(0x07)] = 'KnitHat',
		[string.char(0x08)] = 'PhotoBoard',
		[string.char(0x09)] = 'Pattern',
	}

	local playerBlocksBegin = 0xa0
	local playerBlockSize = 0xa480
	local patternBlockSize = 0x870
	local selectedPattern = 1
	local selectedPlayer = 1

	local function drawPatternSquare(pixelTable, pallet, xoffset, yoffset)
		local oldCanvas = love.graphics.getCanvas()
		local x = 1
		local y = 0
		for i = 1, #pixelTable do
			pixel = pixelTable[i]
			love.graphics.setColor(hex(colors[pallet[pixel+1]+1]))
			love.graphics.rectangle('fill', (x + xoffset)-1, (y + yoffset), 1, 1)

			x = x + 1
			if x > 32 then
				x = 1
				y = y + 1
			end
		end
	end

	local function parsePatterns()
		local patternStart = playerBlocksBegin + (playerBlockSize*(selectedPlayer-1)) + (patternBlockSize*(selectedPattern-1)) + 0x2c

		local parsedData = {
			patternName = readBytes(patternStart, patternStart + 0x029, {cutZeroes = true, utf8_safe = true}),
			patternCreator = readBytes(patternStart+0x2c, patternStart+0x03d, {cutZeroes = true, utf8_safe = true}),
			--0x069		  (  1) = Pattern Type 
			patternType = patternTypes[readBytes(patternStart+0x069, patternStart+0x069)],

			patternData1 = readBytes(patternStart+0x6c, patternStart+0x26b),
			patternData2 = readBytes(patternStart+0x26c, patternStart+0x46b),
			patternData3 = readBytes(patternStart+0x46c, patternStart+0x66b),
			patternData4 = readBytes(patternStart+0x66c, patternStart+0x86b),
		}
		print(parsedData.patternType)
		parsedData.pallet = {}
		for i=0, 14 do -- build pallet
			local byte = patternStart+0x58 + i
			table.insert(parsedData.pallet, string.byte(readBytes(byte, byte)))
		end
		return parsedData
	end

	local selection = 1
	local selectingPlayer = false
	local function setColor(n)
		if selection == n then
			love.graphics.setColor(1,1,0)
		else
			love.graphics.setColor(1,1,1)
		end
	end
	local memfont = love.graphics.newFont()
	local stepString = nil
	myself.extraDraw = function()
		if selectingPlayer then
			love.graphics.setColor(0,0,0,0.5)
			love.graphics.rectangle('fill', 0, 0, 320, 240)
			love.graphics.setColor(1,1,0)
			local text = 'Selected Player: '..selectedPlayer
			love.graphics.print(text, 320/2 - memfont:getWidth(text)/2, 240/2)
		end
		if stepString then
			love.graphics.setColor(0,0,0,0.5)
			love.graphics.rectangle('fill', 0, 0, 320, 240)

			love.graphics.setColor(1,1,0)
			love.graphics.printf(stepString, (320/2) - 150, 100, 300, 'center')
			love.graphics.setColor(1,1,1)
		end

		if receive('drawBottomScreenUI1') then
			drawBottomScreenUI = 1
			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(myself.patternCanvas)
			
			local x, y = 0, 0
			for i = 1, 5 do
				selectedPattern = i

				local tempPatternData = parsePatterns()
				drawPatternSquare(patternStringToTable(tempPatternData.patternData1), tempPatternData.pallet, x * 32, y*32)
				x = x + 1
				if x > 4 then
					x = 0
					y = y + 1
				end
			end
			love.graphics.setCanvas(oldCanvas)
		end
		if receive('drawBottomScreenUI2') then
			drawBottomScreenUI = 1
			local oldCanvas = love.graphics.getCanvas()
			love.graphics.setCanvas(myself.patternCanvas)
			
			local x, y = 0, 1
			for i = 6, 10 do
				selectedPattern = i

				local tempPatternData = parsePatterns()
				drawPatternSquare(patternStringToTable(tempPatternData.patternData1), tempPatternData.pallet, x * 32, y*32)
				x = x + 1
				if x > 4 then
					x = 0
					y = y + 1
				end
			end
			love.graphics.setCanvas(oldCanvas)
		end
		love.graphics.setColor(1,1,1)
		if drawBottomScreenUI then
			canvasCamera:attach()
			love.graphics.draw(myself.patternCanvas)
			canvasCamera:detach()

			local x, y = 0, 0
			for i = 1, 10 do
				dx, dy = canvasCamera:cameraCoords(x*32, y*32)
				love.graphics.rectangle('line', dx, dy, 64, 64)
				x = x + 1
				if x > 4 then
					x = 0
					y = y + 1
				end
			end
		end
	end

	local function formatTimeString(date)
		for key, unit in pairs(date) do
			formattedUnit = tostring(unit)
			if #formattedUnit < 4 then
				for i = 1, 4 - #formattedUnit do
					formattedUnit = '0'..formattedUnit
				end
			end
			date[key] = formattedUnit
		end

		return date.year..date.month..date.day..date.hour..date.min..date.sec
	end

	local directory = ''
	scripts.loadSave = coroutine.create(function() 
		while true do
			local received = receive('loadSave')
			if received then
				local date = os.date('*t', os.time())
				local saveFolderName = 'ACNL_'..formatTimeString(date)
				if not love.filesystem.getInfo('backups') then
					love.filesystem.createDirectory('backups')
				end
				love.filesystem.createDirectory('backups/'..saveFolderName)

				directory = received
				globalSave = love.filesystem.read(directory)
				love.filesystem.write('backups/'..saveFolderName..'/garden_plus.dat', globalSave)

				-- remove older copies
				if settings.cullsaves then
					local directoryContents = love.filesystem.getDirectoryItems("backups")
					printTable(directoryContents)
					if #directoryContents > 5 then
						for i = 1, #directoryContents - 5 do
							love.filesystem.remove('backups/'..directoryContents[i]..'/garden_plus.dat')
							love.filesystem.remove('backups/'..directoryContents[i])
						end
					end
				end
				
				broadcast('removeFiletree')
				stepString = 'Copy of your save file was saved to:\n'..love.filesystem.getSaveDirectory()..'backups/'..saveFolderName..'\n(press A to continue...)'
				while not inputs.getAction('select') do
					coroutine.yield()
				end
				while inputs.getAction('select') do
					coroutine.yield()
				end
				broadcast('selectPlayer')
			end
			received = receive('selectPlayer')
			if received then
				stepString = nil
				selectingPlayer = true
				while true do
					if inputs.getAction('left') then
						selectedPlayer = clamp(selectedPlayer - 1, 1, 4)
						while inputs.getAction('left') do
							coroutine.yield()
						end
					end
					if inputs.getAction('right') then
						selectedPlayer = clamp(selectedPlayer + 1, 1, 4)
						while inputs.getAction('right') do
							coroutine.yield()
						end
					end
					if inputs.getAction('select') then
						while inputs.getAction('select') do
							coroutine.yield()
						end
						broadcast('enterBottomScreenUiSelect')
						break
					end
					if inputs.getAction('cancel') then
						while inputs.getAction('cancel') do
							coroutine.yield()
						end
						selectingPlayer = false
						createInstance('fileTree', 0, 0, {directory = string.sub(directory, 1, #directory - #'/garden_plus.dat')})
						break
					end
					coroutine.yield()
				end
			end
			local received = receive('enterBottomScreenUiSelect')
			if received then
				-- select from bottom screen UI
				broadcast('drawBottomScreenUI1')
				coroutine.yield()
				broadcast('drawBottomScreenUI2')
				drawBottomScreenUI = true
				local hitboxes = {}
				local x, y = 0, 0
				for i = 1, 10 do
					selectedPattern = i
					table.insert(hitboxes, HC.rectangle(x*32, y*32, 32, 32))
					x = x + 1
					if x > 4 then
						x = 0
						y = y + 1
					end
				end
				coroutine.yield()
				local selected = false
				while true do
					if touch.down then
						for i, hitbox in ipairs(hitboxes) do
							local x, y = canvasCamera:worldCoords(touch.x, touch.y)
							if hitbox:contains(x, y) then
								selected = true
								selectedPattern = i
							end
						end
						if selected then break end
					end
					if inputs.getAction('cancel') then
						while inputs.getAction('cancel') do
							coroutine.yield()
						end
						break
					end
					coroutine.yield()
				end
				drawBottomScreenUI = false
				if selected then
					broadcast('enterLoadPhase')
				else
					broadcast('selectPlayer')
				end
			end
			received = receive('enterLoadPhase')
			if received then
				while touch.down do
					coroutine.yield()
				end
				selectingPlayer = false

				parsedTable = parsePatterns()
				
				createInstance('mannequinRender', 0, 0)
				createInstance('patternRenderAndEditor', 0, 0)
				createInstance('undoRedo', 0, 0)
				createInstance('toolsPanel', 320 - 123, 240/2 - 60)
				broadcast('saveParsed', parsedTable)
				myself:goToLayer(#gameSprites)
				coroutine.yield()	
			end
			coroutine.yield()
		end
	end)

	scripts.saveDaSave = coroutine.create(function()
		while true do
			local received = receive('saveEditedFile')
			if received then
				local patternStart = playerBlocksBegin + (playerBlockSize*(selectedPlayer-1)) + (patternBlockSize*(selectedPattern-1)) + 0x2c
				local currentPatternState = received
				-- 0x058 - 0x066 ( 15) = Palette Indexes
				local newPalletString = ''
				for i, color in ipairs(currentPatternState.pallet) do -- pallet update
					newPalletString = newPalletString..string.char(color)
				end
				if #newPalletString ~= 15 then
					error('Pallet incorrect size!')
				end
				stepString = 'Saving New Pallet...'
				coroutine.yield()
				globalSave = replaceChars(globalSave, patternStart + 0x059, patternStart + 0x067, newPalletString)

				stepString = 'Saving Pattern Data...'
				coroutine.yield()
				globalSave = replaceChars(globalSave, patternStart+0x6d, patternStart+0x26c, tableToPatternString(currentPatternState.data1))
				globalSave = replaceChars(globalSave, patternStart+0x26d, patternStart+0x46c, tableToPatternString(currentPatternState.data2))
				globalSave = replaceChars(globalSave, patternStart+0x46d, patternStart+0x66c, tableToPatternString(currentPatternState.data3))
				globalSave = replaceChars(globalSave, patternStart+0x66d, patternStart+0x86c, tableToPatternString(currentPatternState.data4))

				stepString = 'Updating Checksum...'
				coroutine.yield()
				globalSave = updateChecksum(globalSave, 0x80, 0x1c); --header
				for i = 0, 3 do --players
					globalSave = updateChecksum(globalSave, 0xa0+(playerBlockSize*i), 0x6b84);
					globalSave = updateChecksum(globalSave, 0xa0+(playerBlockSize*i)+0x6b88, 0x38f4);
				end
				globalSave = updateChecksum(globalSave, 0x0292a0, 0x022bc8); --villagers
				globalSave = updateChecksum(globalSave, 0x04be80, 0x44b8); --/buildings
				globalSave = updateChecksum(globalSave, 0x053424, 0x01e4d8); --town info (acres, grass type...)
				globalSave = updateChecksum(globalSave, 0x071900, 0x20);
				globalSave = updateChecksum(globalSave, 0x071924, 0xbe4);
				globalSave = updateChecksum(globalSave, 0x073954, 0x16188);

				if #globalSave ~= 563968 then
					error('File incorrect size! not saved!')
				end
				stepString = 'Writing file...'
				coroutine.yield()
				love.filesystem.write(directory, globalSave)
				stepString = 'Your file is saved to the source directory!\nPress A to continue to player selection!'
				while not inputs.getAction('select') do
					coroutine.yield()
				end
				while inputs.getAction('select') do
					coroutine.yield()
				end
				broadcast('selectPlayer')
			end
			coroutine.yield()
		end
	end)

	scripts.quitCheck = coroutine.create(function() 
		while true do
			local received = receive('quitCheck')
			if received then
				stepString = 'Are you sure you want to quit?\n(A to confirm, B to cancel.)'
				while true do
					if inputs.getAction('select') then
						while inputs.getAction('select') do
							coroutine.yield()
						end
						broadcast('quitResponse', 1)
						break
					elseif inputs.getAction('cancel') then
						while inputs.getAction('cancel') do
							coroutine.yield()
						end
						broadcast('quitResponse', 0)
						break
					end
					coroutine.yield()
				end
				
				stepString = nil
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

return spriteTypes
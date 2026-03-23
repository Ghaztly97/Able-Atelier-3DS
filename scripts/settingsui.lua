local spriteTypes = {}

spriteTypes.settingsui = function(x, y) 
	local myself = baseSprite()
	local scripts = {}
	local gear = love.graphics.newImage('assets/images/gear.png')
	local prettyKeys = {cullsaves = 'Delete Old Backup Saves', ti = 'Test Text', ni = 'Test Number'}
	local hitboxes = {}
	myself.screen = 'bottom'
	keyInstances.settingsui = myself

	myself.textInput = ''
	function love.textinput(text)
		if love._os ~= 'horizon' then
	    	myself.textInput = myself.textInput..text
	    else
	    	myself.textInput = text
	    end
	end

	local settingsKeys = {}
	local idx = 0
	for key, value in pairs(settings) do
		idx = idx + 1
		if key ~= 'version' then
			table.insert(settingsKeys, key)
		end
	end
	table.sort(settingsKeys, function(a, b) return a < b end)
	for i, key in ipairs(settingsKeys) do
		local hitbox = HC.rectangle(40, 45 + (i*15), 240, 14)
		hitbox.key = key
		table.insert(hitboxes, hitbox)
	end

	local buttonHitbox = HC.rectangle(5, 195, 40, 40)

	myself.settingsOpen = false
	myself.extraDraw = function() 
		love.graphics.setColor(0.6, 0.6, 1, 0.8)
		love.graphics.rectangle('fill', 5, 195, 40, 40, 8)
		love.graphics.setColor(0.3, 0.3, 0.5)
		love.graphics.rectangle('line', 5, 195, 40, 40, 8)
		love.graphics.draw(gear, 5+20, 195+20, love.timer.getTime(), 0.5, 0.5, 32, 32)

		if myself.settingsOpen then
			love.graphics.setColor(0.6, 0.6, 1, 0.8)
			love.graphics.rectangle('fill', 20, 40, 280, 150, 15)
			love.graphics.setColor(0.3, 0.3, 0.5)
			love.graphics.rectangle('line', 20, 40, 280, 150, 15)
			love.graphics.printf('SETTINGS', 40, 45, 240, 'center')

			for i, key in ipairs(settingsKeys) do
				love.graphics.printf(tostring(prettyKeys[key])..' : '..tostring(settings[key]), 40, 45 + (i*15), 240, 'center')
			end
			for i, hitbox in ipairs(hitboxes) do
				hitbox:draw('line')
			end
		end
	end

	scripts.selector = coroutine.create(function() 
		while true do
			if touch.down then
				if buttonHitbox:contains(touch.x, touch.y) then
					myself.settingsOpen = not myself.settingsOpen
					--toggleUiDebounce(myself.settingsOpen)
				end

				local clickedHitbox = nil
				if myself.settingsOpen and touch.down then
					for i, hitbox in ipairs(hitboxes) do
						if hitbox:contains(touch.x, touch.y) then
							clickedHitbox = hitbox
							break
						end
					end
				end
				if clickedHitbox then
					local key = clickedHitbox.key
					if type(settings[key]) == 'boolean' then
						settings[key] = not settings[key]
						love.filesystem.write('settings.json', json.encode(settings))
					end
					if type(settings[key]) == 'string' then
						love.keyboard.setTextInput(true)
						local oldVal = settings[key]
						myself.textInput = ''
						if love._os ~= 'horizon' then
							local t = 5
							while t > 0 do
								t = t - love.timer.getDelta()
								settings[key] = myself.textInput
								coroutine.yield()
							end
							love.filesystem.write('settings.json', json.encode(settings))
						else
							coroutine.yield()
							if #myself.textInput ~= 0 then
								settings[key] = myself.textInput
								love.filesystem.write('settings.json', json.encode(settings))
							end
						end
						love.keyboard.setTextInput(false)
					end
					if type(settings[key]) == 'number' then
						if love._os ~= 'horizon' then
							love.keyboard.setTextInput(true)
						else
							love.keyboard.setTextInput(true, {type = 'numpad'})
						end
						local oldVal = settings[key]
						myself.textInput = ''
						if love._os ~= 'horizon' then
							local t = 5
							while t > 0 do
								t = t - love.timer.getDelta()
								settings[key] = tonumber(myself.textInput)
								coroutine.yield()
							end
							love.filesystem.write('settings.json', json.encode(settings))
						else
							coroutine.yield()
							if #myself.textInput ~= 0 and type(tonumber(myself.textInput)) ~= 'nil' then
								settings[key] = tonumber(myself.textInput)
								love.filesystem.write('settings.json', json.encode(settings))
							end
						end
						love.keyboard.setTextInput(false)
					end
				end

				while touch.down do
					coroutine.yield()
				end
			end

			coroutine.yield()
		end
	end)

	scripts.layer = coroutine.create(function() 
		while true do
			if receive('saveParsed') then
				myself:goToLayer(#gameSprites)
			end
			coroutine.yield()
		end
	end)

	myself.scripts = scripts
	return myself
end

return spriteTypes
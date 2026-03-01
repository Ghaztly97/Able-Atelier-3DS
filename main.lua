nest = require('nest').init({console = '3ds'})
if love._os ~= 'horizon' then
	love.graphics.set3D(false)
else
	love.graphics.setStereoscopic(false)
end

local killTime = 0
function love.load()
	love.graphics.setDefaultFilter('nearest', 'nearest')
	love.filesystem.setIdentity("ACPatterns")
	keyInstances = {}

	require 'utils'
	require 'bit'
	utf8 = require 'utf8'
	HC = require 'libraries/HC'
	camera = require 'libraries/camera'
	inputs = require 'scripts/inputs'
	spriteTypes = require 'scripts/objects'
	hex = require('libraries/hexatonic')({error = function(i) print(i) end})
	
	if love._os == 'Windows' then 
		local success = love.filesystem.mount('sdmc', 'sd', true)
		print('Mount Status: ', success, err)
	elseif love._os == 'horizon' then
		local success = love.filesystem.mountFullPath("sdmc:/", "sdmc", "readwrite", true)
		print('Mount Status: ', success, err)
	end

	globalSave = nil
	broadcasts = {}
	broadcastQueue = {}

	--fileTree = love.filesystem.getDirectoryItems('sdmc')
	gameSprites = {}

	errorLog = {}

	createInstance('fileTree', 0, 0)
	createInstance('saveHandler', 0, 0)
	
	prettyPatterns = {
		pattern1 = love.graphics.newImage('assets/images/pattern_1.png'),
		pattern2 = love.graphics.newImage('assets/images/pattern_2.png'),
	}
end

function love.update()
	inputs.update()
	if inputs.getAction('quit') then	
		killTime = killTime + love.timer.getDelta()
	else
		killTime = 0
	end
	if killTime > 0.5 then
		love.event.quit()
	end

	local toDestroy = {}
	local toRelayer = {}
	
	broadcasts = {}
	for broadcast, data in pairs(broadcastQueue) do
		--print(broadcast, ':', type(data))
		broadcasts[broadcast] = data
	end
	broadcastQueue = {}

	for _, sprite in ipairs(gameSprites) do
		for _, script in pairs(sprite.scripts) do
			if coroutine.status(script) ~= 'dead' then
				local success, err = coroutine.resume(script)
				if err then
					print(err)
					table.insert(errorLog, 1, err)
				end
			end
		end
		if sprite.targetLayer ~= 0 then
			table.insert(toRelayer, sprite)
		end
		if sprite.destroyConfirm then
			table.insert(toDestroy, sprite)
		end
	end
	-- relayer loop
	for _, sprite in ipairs(toRelayer) do
		for i, match in ipairs(gameSprites) do
			if match == sprite then
				table.remove(gameSprites, i)
				table.insert(gameSprites, sprite.targetLayer, sprite)
				sprite.targetLayer = 0
				break
			end
		end
	end

	-- destroy loop
	for _, sprite in ipairs(toDestroy) do
		for i, match in ipairs(gameSprites) do
			if match == sprite then
				table.remove(gameSprites, i)
			end
		end
	end
end

touch = {
	down = false,
	x = 0,
	y = 0,
	dx = 0,
	dy = 0
}

function love.touchpressed(id, x, y, dx, dy, pressure)
    touch.x = x
    touch.y = y
    touch.dx = dx
    touch.dy = dy
    touch.down = true
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    touch.x = x
    touch.y = y
    touch.dx = dx
    touch.dy = dy
    touch.down = false
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    touch.x = x
    touch.y = y
    touch.dx = dx
    touch.dy = dy
    touch.down = true
end

function love.draw(screen)
	if screen == 'top' or screen == 'left' then
		love.graphics.setColor(0.8, 0.6, 0.3)
		local scrollx = math.mod(love.timer.getTime()*45, 400)
		love.graphics.draw(prettyPatterns.pattern2, scrollx, 0, 0, 400/160, 240/144)
		love.graphics.draw(prettyPatterns.pattern2, scrollx-400, 0, 0, 400/160, 240/144)
		love.graphics.setColor(1,1,1)
		for _, sprite in ipairs(gameSprites) do
			if sprite.screen =='top' or sprite.screen == 'left' or sprite.screen == 'both' then
				sprite:draw(screen)
			end
		end
		love.graphics.rectangle('line', 0, 0, 400, 240)
		for i, text in ipairs(errorLog) do
			love.graphics.setColor(1,0,0, 0.5)
			love.graphics.rectangle('fill', 0, (i-1)*15, 400, 15)
			love.graphics.setColor(1,1,1)
			love.graphics.print(text, 0, (i-1)*15)
			love.graphics.setColor(1,1,1)
		end
	end
	if screen == 'bottom' then
		love.graphics.setColor(0.3, 0.8, 0.4)
		local scrollx = math.mod(love.timer.getTime()*45, 320)
		local scrolly = math.mod(love.timer.getTime()*45, 240)

		love.graphics.draw(prettyPatterns.pattern1, scrollx, 0, 0, 320/160, 240/144)
		love.graphics.draw(prettyPatterns.pattern1, scrollx-320, 0, 0, 320/160, 240/144)
		love.graphics.setColor(1,1,1)

		for _, sprite in ipairs(gameSprites) do
			if sprite.screen == 'bottom' or sprite.screen == 'both' then
				sprite:draw(screen)
			end
		end

		love.graphics.setColor(1,1,1)
		love.graphics.rectangle('line', 0, 0, 320, 240)
		--love.graphics.print(love.timer.getFPS())

		if touch.down then
			love.graphics.setColor(1,0,0)
			love.graphics.circle('fill', touch.x, touch.y, 5)
		end
		love.graphics.setColor(1,1,1)
		love.graphics.rectangle('fill', 20, 215, 280*(killTime/0.5), 10)
	end
end
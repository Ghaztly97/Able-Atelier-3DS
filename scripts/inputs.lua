local inputs = {}
local state = {}

local joysticks = love.joystick.getJoysticks()
local gamepad = joysticks[1]

function inputs.update()
	if love._os ~= 'horizon' then
		state.quit = love.keyboard.isDown('escape')
		state.up = love.keyboard.isDown('up') or love.keyboard.isDown('t')
		state.down = love.keyboard.isDown('down') or love.keyboard.isDown('g')
		state.left = love.keyboard.isDown('left') or love.keyboard.isDown('f')
		state.right = love.keyboard.isDown('right') or love.keyboard.isDown('h')
		state.select = love.keyboard.isDown('z')
		state.cancel = love.keyboard.isDown('x')
		state.leftTrigger = love.keyboard.isDown('q')
		state.start = love.keyboard.isDown('y')

		state.y = love.keyboard.isDown('j')
		state.x = love.keyboard.isDown('i')

		state.stick = {
			dx = 0,
			dy = 0
		}
		if love.keyboard.isDown('s') then
			state.stick.dy = 1
		elseif love.keyboard.isDown('w') then
			state.stick.dy = -1
		end
		if love.keyboard.isDown('a') then
			state.stick.dx = -1
		elseif love.keyboard.isDown('d') then
			state.stick.dx = 1
		end
	else
		local leftx, lefty = 0, 0
	    if gamepad then
	        leftx, lefty = gamepad:getAxes()
	    end

		state.quit = gamepad:isGamepadDown("back")
		state.up = gamepad:isGamepadDown("dpup")
		state.down = gamepad:isGamepadDown("dpdown")
		state.left = gamepad:isGamepadDown("dpleft")
		state.right = gamepad:isGamepadDown("dpright")
		state.select = gamepad:isGamepadDown("a")
		state.cancel = gamepad:isGamepadDown("b")
		state.leftTrigger = gamepad:isGamepadDown("leftshoulder")
		state.start = gamepad:isGamepadDown("start")

		state.y = gamepad:isGamepadDown("y")
		state.x = gamepad:isGamepadDown("x")

		state.stick = {
			dx = leftx,
			dy = 0-lefty
		}
	end 
end

function inputs.getAction(input)
	return state[input] or false
end

return inputs
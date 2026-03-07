local spriteTypes = {}

function baseSprite()
	local topScreen
	if love._os ~= 'Horizon' then
		topScreen = 'left'
	else
		topScreen = 'top'
	end

	return {
		x = 0, y = 0,
		scripts = {},
		spriteSheet = nil,
		draw = function(self, screen) self.extraDraw(screen) end,
		extraDraw = function(screen) end,
		destroy = function(self) 
			self.destroyConfirm = true
		end,
		costume = nil,
		spriteSheet = nil,
		screen = topScreen,
		targetLayer = 0,
		goToLayer = function(self, layer)
			self.targetLayer = layer
		end
	}
end

function createInstance(type, x, y, opts)
	table.insert(gameSprites, spriteTypes[type](x, y, opts))
end

for _, module in ipairs{
	'scripts/uiElements',
	'scripts/saveHandler',
	'scripts/settingsui'
} do
	local partial = require(module)
	for k, v in pairs(partial) do
		spriteTypes[k] = v
	end
end

return spriteTypes
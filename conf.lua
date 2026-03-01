function love.conf(t)
	if love._os == 'horizon' then
		t.system.speedup = true
	end
end
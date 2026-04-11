local class = {}

function class:__call(...)
	local object = {}
	setmetatable(object, self)
	if self.__init then
		self.__init(object, ...)
	end
	return object
end

function class:__index(index)
	-- self is the class
	for _,super in ipairs(self.__super) do
		if super[index] then return super[index] end
	end
end

return function(...)
	local newClass = {}
	newClass.__super = {}
	for i, super in ipairs({...}) do
		if typeof(super) == "Instance" and super:IsA("ModuleScript") then
			newClass.__super[i] = require(super)
		elseif type(super) ~= "table" then
			error("Class inheritance only works with tables or ModuleScripts")
			continue
		end

		newClass.__super[i] = setmetatable(newClass.__super[i], {
			__call = function(self, ...)
				if self.__init then
					self.__init(newClass, ...)
				end
			end
		})
	end

	for _, super in ipairs(newClass.__super) do
		for key, value in pairs(super) do
			if key == "__super" then continue end
			if key == "__init" then continue end
			if string.sub(key,1,2) ~= "__" then continue end
			newClass[key] = value
		end
	end

	newClass.__index = newClass
	return setmetatable(newClass, class)
end
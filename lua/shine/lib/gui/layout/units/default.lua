--[[
	Default set of SGUI units.
]]

local Layout = Shine.GUI.Layout

local Absolute
local IsType = Shine.IsType
local setmetatable = setmetatable

local function NewType( Name )
	local Meta = {}
	Layout:RegisterUnit( Name, Meta )
	return Meta
end

-- Automatically change numbers into instances of Absolute units.
local function ToUnit( Value )
	if IsType( Value, "number" ) then
		return Absolute( Value )
	end

	return Value or Absolute( 0 )
end

local Operators = {
	__add = function( A, B ) return A + B end,
	__sub = function( A, B ) return A - B end,
	__mul = function( A, B ) return A * B end,
	__div = function( A, B ) return A / B end
}

local function BuildOperator( Meta, Operator )
	return function( A, B )
		A = ToUnit( A )
		B = ToUnit( B )

		return setmetatable( {
			GetValue = function( self, ParentSize )
				return Operator( A:GetValue( ParentSize ), B:GetValue( ParentSize ) )
			end
		}, Meta )
	end
end

local function NewUnit( Name )
	local Meta = NewType( Name )

	function Meta:Init( Value )
		self.Value = Value
		return self
	end

	for MetaKey, Operator in pairs( Operators ) do
		Meta[ MetaKey ] = BuildOperator( Meta, Operator )
	end

	function Meta:__unm()
		return setmetatable( {
			GetValue = function( _, ParentSize )
				return -self:GetValue( ParentSize )
			end
		}, Meta )
	end

	function Meta:__mod( Mod )
		return setmetatable( {
			GetValue = function( _, ParentSize )
				return self:GetValue( ParentSize ) % Mod
			end
		}, Meta )
	end

	function Meta:__pow( Power )
		return setmetatable( {
			GetValue = function( _, ParentSize )
				return self:GetValue( ParentSize ) ^ Power
			end
		}, Meta )
	end

	return Meta
end

--[[
	Spacing type, handles padding and margins.
]]
do
	local Spacing = NewType( "Spacing" )

	function Spacing:Init( L, U, R, D )
		self[ 1 ] = ToUnit( L )
		self[ 2 ] = ToUnit( U )
		self[ 3 ] = ToUnit( R )
		self[ 4 ] = ToUnit( D )

		return self
	end

	local KeyMap = {
		Left = 1,
		Up = 2,
		Right = 3,
		Down = 4
	}
	function Spacing:__index( Key )
		return Spacing[ Key ] or self[ KeyMap[ Key ] ]
	end
end

--[[
	Unit vector, handles holding a pair of units.
]]
do
	local UnitVector = NewType( "UnitVector" )

	function UnitVector:Init( X, Y )
		self[ 1 ] = ToUnit( X )
		self[ 2 ] = ToUnit( Y )

		return self
	end

	function UnitVector:Set( UnitVector )
		for i = 1, 2 do
			self[ i ] = UnitVector[ i ]
		end
	end

	local KeyMap = {
		x = 1, y = 2
	}
	function UnitVector:__index( Key )
		return UnitVector[ Key ] or self[ KeyMap[ Key ] ]
	end
end

--[[
	Dummy type, just returns the passed value.
]]
do
	Absolute = NewUnit( "Absolute" )

	function Absolute:GetValue()
		return self.Value
	end
end

--[[
	Scaled using GUIScale().
]]
do
	local GUIScaled = NewUnit( "GUIScaled" )

	function GUIScaled:GetValue()
		return GUIScale( self.Value )
	end
end

--[[
	GUIScales the value only if the resolution is > 1080p.
]]
do
	local SGUI = Shine.GUI
	local HighResScaled = NewUnit( "HighResScaled" )
	local HIGH_RES_WIDTH = 1920

	function HighResScaled:GetValue()
		return SGUI.GetScreenSize() > HIGH_RES_WIDTH and GUIScale( self.Value ) or self.Value
	end
end

--[[
	Arbitrary scale.
]]
do
	local Scaled = NewUnit( "Scaled" )
	local Round = math.Round

	function Scaled:Init( Value, Scale )
		self.Value = Value
		self.Scale = Scale

		return self
	end

	function Scaled:GetValue()
		return Round( self.Value * self.Scale )
	end
end

--[[
	Percentage units are computed based on the parent's size.
]]
do
	local Percentage = NewUnit( "Percentage" )

	function Percentage:Init( Value )
		self.Value = Value * 0.01
		return self
	end

	function Percentage:GetValue( ParentSize )
		return ParentSize * self.Value
	end
end

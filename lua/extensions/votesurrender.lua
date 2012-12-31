--[[
	Shine surrender vote plugin.
]]

local Notify = Shared.Message
local Encode, Decode = json.encode, json.decode
local StringFormat = string.format

local Ceil = math.ceil
local Floor = math.floor
local Max = math.max
local Random = math.random

local Plugin = {}
Plugin.Version = "1.0"

Plugin.HasConfig = true
Plugin.ConfigName = "VoteSurrender.json"

Plugin.Commands = {}

function Plugin:Initialise()
	self.Votes = {}
	self.Votes[ 1 ] = 0 --Marines
	self.Votes[ 2 ] = 0 --Aliens

	self.Voted = {}
	self.Voted[ 1 ] = {}
	self.Voted[ 2 ] = {}

	self.NextVote = 0

	self:CreateCommands()

	self.Enabled = true

	return true
end

function Plugin:GenerateDefaultConfig( Save )
	self.Config = {
		PercentNeeded = 0.75, --Percentage of the team needing to vote in order to surrender.
		VoteDelay = 10, --Time after round start before surrender vote is available
		MinPlayers = 6, --Min players needed for voting to be enabled.
	}

	if Save then
		local PluginConfig, Err = io.open( Shine.Config.ExtensionDir..self.ConfigName, "w+" )

		if not PluginConfig then
			Notify( "Error writing votesurrender config file: "..Err )	

			return	
		end

		PluginConfig:write( Encode( self.Config, { indent = true, level = 1 } ) )

		Notify( "Shine votesurrender config file created." )

		PluginConfig:close()
	end
end

function Plugin:SaveConfig()
	local PluginConfig, Err = io.open( Shine.Config.ExtensionDir..self.ConfigName, "w+" )

	if not PluginConfig then
		Notify( "Error writing votesurrender config file: "..Err )	

		return	
	end

	PluginConfig:write( Encode( self.Config, { indent = true, level = 1 } ) )

	Shine:Print( "Shine votesurrender config file saved." )

	PluginConfig:close()
end

function Plugin:LoadConfig()
	local PluginConfig = io.open( Shine.Config.ExtensionDir..self.ConfigName, "r" )

	if not PluginConfig then
		self:GenerateDefaultConfig( true )

		return
	end

	self.Config = Decode( PluginConfig:read( "*all" ) )

	PluginConfig:close()
end

--[[
	Runs when the game state is set.
	If a round has started, we set the next vote time to current time + delay.
]]
function Plugin:SetGameState( Gamerules, State, OldState )
	if State == kGameState.Started then
		self.NextVote = Shared.GetTime() + ( self.Config.VoteDelay * 60 )
	end
end

function Plugin:GetVotesNeeded( Team )
	return Max( 1, Ceil( #GetEntitiesForTeam( "Player", Team ) * self.Config.PercentNeeded ) )
end

--[[
	Make sure we only vote when a round has started.
]]
function Plugin:CanStartVote( Team )
	local Gamerules = GetGamerules()

	if not Gamerules then return false end

	local State = Gamerules:GetGameState()

	return State == kGameState.Started and #GetEntitiesForTeam( "Player", Team ) >= self.Config.MinPlayers and self.NextVote < Shared.GetTime()
end

function Plugin:AddVote( Client, Team )
	if not Client then return end

	if Team ~= 1 and Team ~= 2 then return false, "spectators can't surrender!" end --Would be a fun bug...
	
	if not self:CanStartVote( Team ) then return false, "can't start" end
	if self.Voted[ Team ][ Client ] then return false, "already voted" end

	self.Voted[ Team ][ Client ] = true
	self.Votes[ Team ] = self.Votes[ Team ] + 1

	if self.Votes[ Team ] >= self:GetVotesNeeded( Team ) then
		self:Surrender( Team )
	end

	return true
end

--[[
	Makes the given team surrender (moves them to the ready room).
]]
function Plugin:Surrender( Team )
	local Players = GetEntitiesForTeam( "Player", Team )

	local Gamerules = GetGamerules()

	if not Gamerules then return end

	Gamerules:EndGame( Team == 1 and Gamerules.team2 or Gamerules.team1 )

	Shine.Timer.Simple( 0.1, function()
		Shine:Notify( nil, "Vote", "Admin", "The %s team has voted to surrender.", true, Team == 1 and "marine" or "alien" )
	end )

	self.Votes[ Team ] = 0
	self.Voted[ Team ] = {}
end

function Plugin:CreateCommands()
	local Commands = self.Commands

	local function VoteSurrender( Client )
		if not Client then return end

		local Player = Client:GetControllingPlayer()
		if not Player then return end

		local Team = Player:GetTeamNumber()

		local Votes = self.Votes[ Team ]
		
		local Success, Err = self:AddVote( Client, Team )

		if Success then
			local VotesNeeded = self:GetVotesNeeded( Team )

			Shine:Notify( nil, "Vote", "Admin", "%s voted to surrender (%s more votes needed).", true, Player:GetName(), VotesNeeded - Votes - 1 )

			return
		end

		if Err == "already voted" then
			Shine:Notify( Player, "Error", "Admin", "You have already voted to surrender." )
		else
			Shine:Notify( Player, "Error", "Admin", "You cannot start a surrender vote at this time." )
		end
	end
	Commands.VoteSurrenderCommand = Shine:RegisterCommand( "sh_votesurrender", { "surrender", "votesurrender", "surrendervote" }, VoteSurrender, true )
	Commands.VoteSurrenderCommand:Help( "Votes to surrender the round." )
end

function Plugin:Cleanup()
	for _, Command in pairs( self.Commands ) do
		Shine:RemoveCommand( Command.ConCmd, Command.ChatCmd )
	end

	self.Enabled = false
end

Shine:RegisterExtension( "votesurrender", Plugin )

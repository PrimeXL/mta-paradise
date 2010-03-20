local function showLoginScreen( player )
	-- remove the player from his vehicle if any
	if isPedInVehicle( player ) then
		removePedFromVehicle( player )
	end
	
	-- hide the current view (will be faded in client-side)
	fadeCamera( player, false, 0 )
	toggleAllControls( player, false, true, false )
	
	-- spawn the player etc.
	spawnPlayer( source, 2000.6, 1577.6, 16.5 )
	setPedFrozen( source, true )
	setElementAlpha( source, 0 )
	
	setElementInterior( source, 0 )
	setCameraInterior( source, 0 )
	setElementDimension( source, 1 )
	
	setCameraMatrix( source, 1999.8, 1580.95, 17.6, 2000, 1580, 17.5 )
	
	triggerClientEvent( player, getResourceName( resource ) .. ":spawnscreen", player )
end

addEvent( getResourceName( resource ) .. ":ready", true )
addEventHandler( getResourceName( resource ) .. ":ready", root,
	function( )
		if source == client then
			showLoginScreen( source )
		end
	end
)

--

local p = { }

addEvent( getResourceName( resource ) .. ":login", true )
addEventHandler( getResourceName( resource ) .. ":login", root,
	function( username, password )
		if source == client then
			if username and password and #username > 0 and #password > 0 then
				local info = exports.sql:query_assoc_single( "SELECT userID, banned, activationCode FROM wcf1_user WHERE `username` = '%s' AND password = SHA1(CONCAT(salt, SHA1(CONCAT(salt, SHA1('%s'))))) LIMIT 1", username, password )
				
				p[ source ] = nil
				if not info then
					triggerClientEvent( source, getResourceName( resource ) .. ":loginResult", source, 1 ) -- Wrong username/password
				else
					if info.banned == 1 then
						triggerClientEvent( source, getResourceName( resource ) .. ":loginResult", source, 2 ) -- Banned
					elseif info.activationCode > 0 then
						triggerClientEvent( source, getResourceName( resource ) .. ":loginResult", source, 3 ) -- Requires activation
					else
						-- check if another user is logged in on that account
						for player, data in pairs( p ) do
							if data.userID == info.userID then
								triggerClientEvent( source, getResourceName( resource ) .. ":loginResult", source, 5 ) -- another player with that account found
								return
							end
						end
						p[ source ] = { userID = info.userID, username = username }
						
						local chars = exports.sql:query_assoc( "SELECT characterID, characterName, skin FROM characters WHERE userID = " .. info.userID )
						triggerClientEvent( source, getResourceName( resource ) .. ":characters", source, chars, true )
						-- login successful, do something!
					end
				end
			end
		end
	end
)

local function savePlayer( player )
	if not player then
		for key, value in ipairs( getElementsByType( "player" ) ) do
			savePlayer( value )
		end
	else
		if isLoggedIn( source ) then
			-- save character since it's logged in
			local x, y, z = getElementPosition( source )
			exports.sql:query_free( "UPDATE characters SET x = " .. x .. ", y = " .. y .. ", z = " .. z .. ", dimension = " .. getElementDimension( source ) .. ", interior = " .. getElementInterior( source ) .. ", rotation = " .. getPedRotation( source ) .. ", health = " .. math.ceil( getElementHealth( source ) ) .. ", armor = " .. math.ceil( getPedArmor( source ) ) .. " WHERE characterID = " .. tonumber( p[ source ].charID ) )
		end
	end
end
setTimer( savePlayer, 300000, 0 ) -- Auto-Save every five minutes
addEventHandler( "onResourceStop", resourceRoot, function( ) savePlayer( ) end )

addEvent( getResourceName( resource ) .. ":logout", true )
addEventHandler( getResourceName( resource ) .. ":logout", root,
	function( )
		if source == client then
			savePlayer( source )
			p[ source ] = nil
			showLoginScreen( source )
		end
	end
)

addEventHandler( "onPlayerQuit", root,
	function( )
		savePlayer( source )
		p[ source ] = nil
	end
)

addEvent( getResourceName( resource ) .. ":spawn", true )
addEventHandler( getResourceName( resource ) .. ":spawn", root, 
	function( charID )
		if source == client then
			local userID = p[ source ] and p[ source ].userID
			if tonumber( userID ) and tonumber( charID ) then
				-- if the player is logged in, save him
				savePlayer( source )
				p[ source ].charID = nil
				
				--
				local char = exports.sql:query_assoc_single( "SELECT characterName, x, y, z, dimension, interior, skin, rotation, health, armor FROM characters WHERE userID = " .. tonumber( userID ) .. " AND characterID = " .. tonumber( charID ) )
				if char then
					local mtaCharName = char.characterName:gsub( " ", "_" )
					local otherPlayer = getPlayerFromName( mtaCharName )
					if otherPlayer and otherPlayer ~= source then
						kickPlayer( otherPlayer )
					end
					p[ source ].charID = nil
					setPlayerName( source, mtaCharName )
					
					-- spawn the player, as it's a valid char
					spawnPlayer( source, char.x, char.y, char.z, char.rotation, char.skin, char.interior, char.dimension )
					fadeCamera( source, true )
					setCameraTarget( source, source )
					setCameraInterior( source, char.interior )
					
					toggleAllControls( source, true, true, false )
					setPedFrozen( source, false )
					setElementAlpha( source, 255 )
					
					setElementHealth( source, char.health )
					setPedArmor( source, char.armor )
					
					p[ source ].charID = tonumber( charID )
					
					triggerClientEvent( source, getResourceName( resource ) .. ":onSpawn", source )
				end
			end
		end
	end
)

addEventHandler( "onPlayerWasted", root,
	function( )
		if isLoggedIn( source ) then
			local x, y, z = getElementPosition( source )
			spawnPlayer( source, x, y, z, getPedRotation( source ), getElementModel( source ), getElementInterior( source ), getElementDimension( source ) )
			fadeCamera( source, true )
			setCameraTarget( source, source )
			setCameraInterior( source, getElementInterior( source ) )
		end
	end
)

addEventHandler( "onPlayerChangeNick", root,
	function( )
		if isLoggedIn( source ) then
			cancelEvent( )
		end
	end
)

-- exports
function isLoggedIn( player )
	return player and p[ player ] and p[ player ].charID
end
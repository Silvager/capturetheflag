ctf_teams.parties = {}
ctf_teams.invites = {}

local partiescmdbuilder = chatcmdbuilder.register("party", {
	description = "Party management commands",
	params = "invite <player> | accept <player> | leave | info"
})

partiescmdbuilder:sub("info", function (name)
    local playerPartyInfo = ctf_teams.getPlayerPartyInfo(name)
    if playerPartyInfo == nil then
        minetest.chat_send_player(name, "You are not in a party")
    else
        local partyMembersString = "Party members: "
        for index, playerName in ipairs(playerPartyInfo.player_party) do
            partyMembersString = partyMembersString..playerName.." "
        end
        minetest.chat_send_player(name, partyMembersString)
    end

    local playerInviteInfo = ctf_teams.getPlayerInviteInfo(name) -- BROKEN
    if playerInviteInfo == nil then
        minetest.chat_send_player(name, "You have no outcoming or incoming invites")
        return
    end
    if playerInviteInfo.outgoingInvites == nil then
        minetest.chat_send_player(name, "You have no outgoing invites")
    else
        local outgoingInvitesString = "You have pending outgoing invites to: "
        for key, invite in pairs(playerInviteInfo.outgoingInvites) do
            outgoingInvitesString = outgoingInvitesString..invite.invited.." "
        end
        minetest.chat_send_player(name, outgoingInvitesString)
    end

    if playerInviteInfo.incomingInvites == nil then
        minetest.chat_send_player(name, "You have no incoming invites")
    else
        local incomingInvitesString = "You have pending incoming invites from: "
        for key, invite in pairs(playerInviteInfo.incomingInvites) do
            incomingInvitesString = incomingInvitesString..invite.inviter.." "
        end
        minetest.chat_send_player(name, incomingInvitesString)
    end
end)

partiescmdbuilder:sub("invite :player:username", function (name, player)
	if minetest.get_player_by_name(player) then
        if player == name then
            minetest.chat_send_player(name, "You can't invite yourself to a party, silly!")
            return
        end
		minetest.chat_send_player(name, "Inviting "..player.." to your party. They must accept to join.")
        minetest.chat_send_player(player, name.." has invited you to their party. Type \"/party accept "..name.."\" to join.")
        table.insert(ctf_teams.invites, {inviter = name, invited = player})
	else
		minetest.chat_send_player(name, player.." is not online, or isn't a player")
	end
end)
partiescmdbuilder:sub("accept :player:username", function (name, player)
    if minetest.get_player_by_name(player) == nil then
        minetest.chat_send_player(name, player.." is not online, or isn't a player")
        return
    else if ctf_teams.getPlayerPartyInfo(name) ~= nil then
        minetest.chat_send_player(name, "You are currently in a party. You must leave using \"/party leave\" before you can accept new invitations.")
        return
    end
    for index, invite in ipairs(ctf_teams.invites) do
        if invite.inviter == player and invite.invited == name then
            -- Create a new party if the inviter is currently not in one
            local inviterPartyInfo = ctf_teams.getPlayerPartyInfo(player)
            if inviterPartyInfo == nil then
                table.insert(ctf_teams.parties, {player, name})
                minetest.chat_send_player(name, "You have joined "..player.."'s party.")
                minetest.chat_send_player(player, name.." has joined your party.")
            else
                for index, player_name in ipairs(inviterPartyInfo.player_party) do
                    minetest.chat_send_player(player_name, name.." has joined your party")
                end
                minetest.chat_send_player(name, "You have joined "..player.."'s party.")
                table.insert(inviterPartyInfo.player_party, name)
            end
            local inviteIndexToDelete = nil
            for index, invite in ipairs(ctf_teams.invites) do
                if invite.inviter == player and invite.invited == name then
                    inviteIndexToDelete = index
                    break
                end
            end
            if inviteIndexToDelete ~= nil then
                table.remove(ctf_teams.invites, inviteIndexToDelete)
            end
            return
        end
    end
    minetest.chat_send_player(name, "You currently have no party invites from "..player)
end
end)
partiescmdbuilder:sub("leave", function (name)
    local playerPartyInfo = ctf_teams.getPlayerPartyInfo(name)
    if playerPartyInfo ~= nil then
        for index, player_name in ipairs(ctf_teams.parties[playerPartyInfo.party_index]) do
            if name ~= player_name then
                minetest.chat_send_player(player_name, name.." has left your party.")
            end
        end
        ctf_teams.removeFromParty(playerPartyInfo)
        minetest.chat_send_player(name, "You have left the party")
    else
        minetest.chat_send_player(name, "You are not in a party")
    end
end)

ctf_teams.getPlayerPartyInfo = function (player)
    if minetest.get_player_by_name(player) == nil then
        return nil
    else
        for party_index, party in ipairs(ctf_teams.parties) do
            for player_index, party_player in ipairs(party) do
                if party_player == player then
                    return {
                        player_party = party,
                        player_index = player_index,
                        party_index = party_index
                    }
                end
            end
        end
        return nil
    end
end
-- Can pass either a player name or party info
ctf_teams.removeFromParty = function (arg)
    local playerPartyInfo = nil
    if type(arg) == "string" then
        playerPartyInfo = ctf_teams.getPlayerPartyInfo(arg)
    elseif type(arg) == "table" then
        playerPartyInfo = arg
    end
    if playerPartyInfo ~= nil then
        table.remove(playerPartyInfo.player_party, playerPartyInfo.player_index)
        local playerPartyLength = #playerPartyInfo.player_party
        if playerPartyLength < 2 then
            if playerPartyLength == 1 then
                for index, player_name in ipairs(playerPartyInfo.player_party) do
                    minetest.chat_send_player(player_name, "Your party has disbanded because you were the only one left")
                end
            end
            table.remove(ctf_teams.parties, playerPartyInfo.party_index)
        end
    end
end

ctf_teams.getPlayerInviteInfo = function (player)
    if minetest.get_player_by_name(player) == nil then
        return nil
    else
        local infoToReturn = {outgoingInvites = nil, incomingInvites = nil}
        for invite_index, invite in ipairs(ctf_teams.invites) do
            if invite.inviter == player then
                if infoToReturn.outgoingInvites == nil then
                    infoToReturn.outgoingInvites = {}
                end
                table.insert(infoToReturn.outgoingInvites, invite)
            end
        end
        for invite_index, invite in ipairs(ctf_teams.invites) do
            if invite.invited == player then
                if infoToReturn.incomingInvites == nil then
                    infoToReturn.incomingInvites = {}
                end
                table.insert(infoToReturn.incomingInvites, invite)
            end
        end
        if (infoToReturn.outgoingInvites ~= nil) or (infoToReturn.incomingInvites ~= nil) then
            return infoToReturn
        else
            return nil
        end
    end
end

ctf_teams.deleteAllInvitesInvolvingPlayer = function (player)
    local removedAllInvites = false
    while removedAllInvites == false do
        local hasRemovedInviteThisItteration = false
        for index, invite in ipairs(ctf_teams.invites) do
            if invite.inviter == player or invite.invited == player then
                table.remove(ctf_teams.invites, index)
                hasRemovedInviteThisItteration = true
            end
        end
        if hasRemovedInviteThisItteration == false then
            removedAllInvites = true
        end
    end
end
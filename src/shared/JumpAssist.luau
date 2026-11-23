--!strict
--[[
	JumpAssist — the pure rules behind forgiving jumps (no Roblox types; unit-tested).

	  Coyote time     you can still jump for a moment after running off an edge
	  Jump buffering  a jump pressed just before landing happens the moment you land
	  One jump        neither assist ever gives a second jump in the air

	The client feeds it ground contact and jump presses with timestamps; it answers whether to
	jump now. (Ledge forgiveness lives in client/Input/JumpAssist.luau: it's geometry.)
]]

export type Params = { CoyoteSeconds: number, BufferSeconds: number }

export type State = {
	grounded: boolean,
	leftGroundAt: number,
	jumpedSinceGround: boolean,
	bufferedAt: number?,
}

local JumpAssist = {}

function JumpAssist.new(): State
	return { grounded = true, leftGroundAt = -math.huge, jumpedSinceGround = false, bufferedAt = nil }
end

--- Feeds ground contact. Returns true when a buffered jump should fire (on landing).
function JumpAssist.setGrounded(state: State, params: Params, grounded: boolean, now: number): boolean
	if grounded == state.grounded then
		return false
	end
	state.grounded = grounded
	if not grounded then
		state.leftGroundAt = now
		return false
	end
	state.jumpedSinceGround = false
	local buffered = state.bufferedAt
	state.bufferedAt = nil
	return buffered ~= nil and now - buffered <= params.BufferSeconds
end

--- The game already jumped (Humanoid state Jumping): no coyote jump on top of it.
function JumpAssist.didJump(state: State)
	state.jumpedSinceGround = true
end

--- A jump press. Returns "Native" (on the ground: the Humanoid jumps by itself), "Coyote"
--- (just left an edge: jump now) or "Buffered" (in the air: jump on landing).
function JumpAssist.press(state: State, params: Params, now: number): "Native" | "Coyote" | "Buffered"
	if state.grounded then
		return "Native"
	end
	if not state.jumpedSinceGround and now - state.leftGroundAt <= params.CoyoteSeconds then
		state.jumpedSinceGround = true
		return "Coyote"
	end
	state.bufferedAt = now
	return "Buffered"
end

return JumpAssist

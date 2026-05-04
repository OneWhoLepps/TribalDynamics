class_name BoardState
extends RefCounted

enum Phase { PLACING, RESOLVING, ENDED }

var player_hp: Dictionary = {}               # player_id -> int
var lane_units: Dictionary = {}              # attacker_id -> { target_id -> int }
var stored_units: Dictionary = {}            # player_id -> int
var dead_player_ids: Array = []
var ended_turn_player_ids: Array = []
var alive_count: int = 0
var phase: int = Phase.PLACING
var winner_name: String = ""

static func create_from_players(players: Dictionary) -> BoardState:
	var s = BoardState.new()
	s.alive_count = players.size()
	for player_id in players:
		var p = players[player_id]
		s.player_hp[player_id] = p.health
		s.stored_units[player_id] = p.stored_units
		s.lane_units[player_id] = {}
		for other_id in players:
			if other_id != player_id:
				s.lane_units[player_id][other_id] = 0
	return s

func serialize() -> Dictionary:
	return {
		"player_hp": player_hp.duplicate(true),
		"lane_units": lane_units.duplicate(true),
		"stored_units": stored_units.duplicate(true),
		"dead_player_ids": dead_player_ids.duplicate(),
		"ended_turn_player_ids": ended_turn_player_ids.duplicate(),
		"alive_count": alive_count,
		"phase": phase,
		"winner_name": winner_name,
	}

static func deserialize(d: Dictionary) -> BoardState:
	var s = BoardState.new()
	s.player_hp = d["player_hp"].duplicate(true)
	s.lane_units = d["lane_units"].duplicate(true)
	s.stored_units = d["stored_units"].duplicate(true)
	s.dead_player_ids = d["dead_player_ids"].duplicate()
	s.ended_turn_player_ids = d["ended_turn_player_ids"].duplicate()
	s.alive_count = d["alive_count"]
	s.phase = d["phase"]
	s.winner_name = d["winner_name"]
	return s

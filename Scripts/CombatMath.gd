extends Node

func decide_victor(player1Lane, player2Lane):
	var p1_hp_change := 0
	var p2_hp_change := 0

	# If both lanes are empty, nothing happens
	if player1Lane.is_empty() and player2Lane.is_empty():
		return [
			0,
			0
		]

	var diceResults = roll_combat_dice(int(player1Lane), int(player2Lane))
	var player1rolls = diceResults.player1_rolls;
	var player2rolls = diceResults.player2_rolls;

	player1rolls.sort()
	player1rolls.reverse()
	player2rolls.sort()
	player2rolls.reverse()

	# Equalize lengths
	while player1rolls.size() != player2rolls.size():
		if player1rolls.size() < player2rolls.size():
			p1_hp_change -= 1
			player2rolls.pop_back()
		else:
			p2_hp_change -= 1
			player1rolls.pop_back()

	# Compare dice rolls one by one
	for i in range(player1rolls.size()):
		var p1_roll = player1rolls[i]
		var p2_roll = player2rolls[i]

		if p1_roll > p2_roll:
			p2_hp_change -= 1
		elif p2_roll > p1_roll:
			p1_hp_change -= 1
		# Tie does nothing

	return [
		p1_hp_change,
		p2_hp_change
	]

func roll_combat_dice(player1Count: int, player2Count: int) -> Dictionary:
	if player1Count == 0 and player2Count == 0:
		return {
			"player1_rolls": [],
			"player2_rolls": []
		}

	var player1_rolls := []
	var player2_rolls := []

	for i in player1Count:
		player1_rolls.append(randi() % 6 + 1)

	for i in player2Count:
		player2_rolls.append(randi() % 6 + 1)

	return {
		"player1_rolls": player1_rolls,
		"player2_rolls": player2_rolls
	}

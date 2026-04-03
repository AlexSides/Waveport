extends Node

var selected_card: Node = null

func select_card(card):
	if selected_card and selected_card != card:
		selected_card.deselect()
	selected_card = card

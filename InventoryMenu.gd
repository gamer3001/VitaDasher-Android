extends CanvasLayer

# Ce noeud doit avoir "Pause Mode" = "Process" (déjà fait dans _ready)
# pour continuer à recevoir les inputs même quand get_tree().paused = true.
#
# Ouverture/fermeture avec l'action "ui_inventory" (à mapper toi-même
# dans Project > Project Settings > Input Map, comme demandé).
#
# Navigation dans la grille avec ui_up / ui_down / ui_left / ui_right
# (stick ou croix, déjà mappés dessus dans ton project.godot) façon
# menu d'objets de Zelda : un curseur se déplace case par case,
# ui_accept sélectionne l'objet survolé.

signal item_selected(item)

# ---- Inventaire (façon Minecraft, à droite, navigable façon Zelda) ----
export var inventory_columns = 9
export var inventory_rows = 4

# Chaque entrée : {"name": String, "count": int, "icon": Texture (optionnel)}
# Vide par défaut, utilise add_item() pour remplir depuis le reste du jeu.
var inventory_items = []

var selected_index = 0
var slot_nodes = []

# ---- Quêtes (façon journal de Raft, à gauche) ----
# Une catégorie = un "onglet" coloré dans la marge, comme les languettes
# du carnet. Remplace ces données d'exemple par tes propres quêtes.
var quest_categories = [
	{
		"name": "Île de départ",
		"color": Color(0.55, 0.75, 0.35),
		"quests": [
			{"title": "Trouver un abri", "description": "Explore l'île et trouve un endroit sûr pour la nuit.", "completed": false},
			{"title": "Récupérer 5 débris", "description": "Ramasse des débris flottants pour commencer à construire.", "completed": false},
		]
	},
	{
		"name": "Radio Tower",
		"color": Color(0.35, 0.55, 0.85),
		"quests": [
			{"title": "Réparer l'antenne", "description": "Répare l'antenne radio pour capter un signal.", "completed": false},
		]
	}
]

var current_category = 0

onready var dim = $Dim
onready var panel_inventory = $PanelInventory
onready var panel_quests = $PanelQuests
onready var grid = $PanelInventory/VBoxContainer/GridContainer
onready var selected_name_label = $PanelInventory/VBoxContainer/SelectedName
onready var quest_tabs = $PanelQuests/HBoxContainer/Tabs
onready var quest_list = $PanelQuests/HBoxContainer/QuestList


func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	hide_menu()
	_build_inventory_grid()
	_build_quest_tabs()
	_refresh_quest_list()


func _unhandled_input(event):
	if event.is_action_pressed("ui_inventory"):
		if get_tree().paused and not visible:
			return
		toggle_menu()
		get_tree().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move_selection(1, 0)
	elif event.is_action_pressed("ui_accept"):
		_select_current_item()
	elif event.is_action_pressed("ui_cancel"):
		hide_menu()
	else:
		return

	get_tree().set_input_as_handled()


func toggle_menu():
	if visible:
		hide_menu()
	else:
		show_menu()


func show_menu():
	visible = true
	get_tree().paused = true
	_set_selected(selected_index)


func hide_menu():
	visible = false
	get_tree().paused = false


# ================= INVENTAIRE (façon Minecraft, curseur façon Zelda) =================

func _build_inventory_grid():
	for child in grid.get_children():
		child.queue_free()
	slot_nodes.clear()

	grid.columns = inventory_columns
	var total_slots = inventory_columns * inventory_rows
	for i in range(total_slots):
		var slot = _make_slot()
		grid.add_child(slot)
		slot_nodes.append(slot)
		if i < inventory_items.size():
			_fill_slot(slot, inventory_items[i])

	selected_index = clamp(selected_index, 0, total_slots - 1)
	_update_cursor()


func _make_slot():
	var slot = Panel.new()
	slot.rect_min_size = Vector2(40, 40)
	slot.set_meta("item", null)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(1)
	slot.add_stylebox_override("panel", style)
	# Godot 3.x n'a pas de getter pour relire un override, donc on garde
	# nous-mêmes la référence au StyleBoxFlat pour pouvoir le modifier
	# plus tard dans _update_cursor().
	slot.set_meta("style", style)

	var count_label = Label.new()
	count_label.name = "Count"
	count_label.align = Label.ALIGN_RIGHT
	count_label.valign = Label.VALIGN_BOTTOM
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.margin_right = -2
	count_label.margin_bottom = -2
	slot.add_child(count_label)

	return slot


func _fill_slot(slot, item):
	slot.set_meta("item", item)

	var count_label = slot.get_node("Count")
	var count = item.get("count", 1)
	count_label.text = str(count) if count > 1 else ""

	if item.has("icon") and item["icon"] != null:
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = item["icon"]
		icon.expand = true
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.margin_left = 4
		icon.margin_top = 4
		icon.margin_right = -4
		icon.margin_bottom = -4
		slot.add_child(icon)
		slot.move_child(icon, 0)


# Ajoute un item depuis n'importe quel script du jeu :
#   $InventoryMenu.add_item("Vis", 3, preload("res://Asset/vis.png"))
func add_item(item_name, count = 1, icon = null):
	for item in inventory_items:
		if item["name"] == item_name:
			item["count"] += count
			_build_inventory_grid()
			return
	inventory_items.append({"name": item_name, "count": count, "icon": icon})
	_build_inventory_grid()


# ---- Navigation façon Zelda (curseur case par case) ----

func _move_selection(dx, dy):
	if slot_nodes.empty():
		return
	var col = selected_index % inventory_columns
	var row = selected_index / inventory_columns
	col = clamp(col + dx, 0, inventory_columns - 1)
	row = clamp(row + dy, 0, inventory_rows - 1)
	_set_selected(row * inventory_columns + col)


func _set_selected(index):
	if slot_nodes.empty():
		return
	selected_index = clamp(index, 0, slot_nodes.size() - 1)
	_update_cursor()


func _update_cursor():
	for i in range(slot_nodes.size()):
		var slot = slot_nodes[i]
		var style = slot.get_meta("style")
		if style == null:
			continue
		if i == selected_index:
			style.border_color = Color(1.0, 0.9, 0.3)
			style.set_border_width_all(3)
			style.bg_color = Color(0.25, 0.22, 0.05, 0.9)
		else:
			style.border_color = Color(0.4, 0.4, 0.4)
			style.set_border_width_all(1)
			style.bg_color = Color(0.15, 0.15, 0.15, 0.85)

	if selected_name_label:
		var item = slot_nodes[selected_index].get_meta("item")
		selected_name_label.text = item["name"] if item != null else ""


func _select_current_item():
	var item = slot_nodes[selected_index].get_meta("item")
	if item != null:
		emit_signal("item_selected", item)


# ================= QUÊTES (façon journal de Raft) =================

func _build_quest_tabs():
	for child in quest_tabs.get_children():
		child.queue_free()
	for i in range(quest_categories.size()):
		var cat = quest_categories[i]
		var tab_button = Button.new()
		tab_button.text = cat["name"]
		tab_button.rect_min_size = Vector2(0, 32)

		var style = StyleBoxFlat.new()
		style.bg_color = cat.get("color", Color(0.6, 0.6, 0.6))
		tab_button.add_stylebox_override("normal", style)
		tab_button.add_stylebox_override("hover", style)
		tab_button.add_stylebox_override("pressed", style)

		tab_button.connect("pressed", self, "_on_category_selected", [i])
		quest_tabs.add_child(tab_button)


func _on_category_selected(index):
	current_category = index
	_refresh_quest_list()


func _refresh_quest_list():
	for child in quest_list.get_children():
		child.queue_free()
	if quest_categories.empty():
		return

	var cat = quest_categories[current_category]

	var title = Label.new()
	title.text = cat["name"]
	quest_list.add_child(title)
	quest_list.add_child(HSeparator.new())

	for quest in cat["quests"]:
		var entry = CheckBox.new()
		entry.text = quest["title"]
		entry.pressed = quest["completed"]
		entry.disabled = true
		quest_list.add_child(entry)

		var desc = Label.new()
		desc.text = quest["description"]
		desc.autowrap = true
		quest_list.add_child(desc)


# Marque une quête comme terminée depuis le reste du jeu :
#   $InventoryMenu.complete_quest("Radio Tower", "Réparer l'antenne")
func complete_quest(category_name, quest_title):
	for cat in quest_categories:
		if cat["name"] == category_name:
			for quest in cat["quests"]:
				if quest["title"] == quest_title:
					quest["completed"] = true
					_refresh_quest_list()
					return

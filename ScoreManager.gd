extends Node

var high_score_campaign = 0
var high_score_infinite = 0
var high_score_survival = 0

const SAVE_PATH = "user://savegame.save"

func _ready():
    load_game()

func save_game():
    var file = File.new()
    var err = file.open(SAVE_PATH, File.WRITE)
    if err == OK:
        file.store_var(high_score_campaign)
        file.store_var(high_score_infinite)
        file.store_var(high_score_survival)
        file.close()

func load_game():
    var file = File.new()
    if file.file_exists(SAVE_PATH):
        var err = file.open(SAVE_PATH, File.READ)
        if err == OK:
            # On vérifie la taille pour éviter de lire des données corrompues si le fichier est vide
            if file.get_len() > 0:
                high_score_campaign = file.get_var()
                high_score_infinite = file.get_var()
                high_score_survival = file.get_var()
            file.close()

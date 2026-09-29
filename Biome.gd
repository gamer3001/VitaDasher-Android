extends Reference
class_name Biome

# "Palier" visuel en fonction de la même progression 0..1 que SkyGradient
# (0 = herbe/jour, 1 = terre, 2 = lave, 3 = glace/espace), pour que le sol,
# le ciel et le texte changent tous ensemble au fur et à mesure qu'on monte.
const TIER_THRESHOLDS = [0.25, 0.5, 0.75]

const PLATFORM_TEXTURE = preload("res://Asset/sprites/platforms.png")
const TILESET_TEXTURE = preload("res://Asset/sprites/world_tileset.png")

const PLATFORM_TILE_W = 32
const PLATFORM_TILE_H = 16
const TILE = 16

# Hauteur de la ligne de plateforme (dessus solide) et du bloc décoratif
# posé dessous. Seule la ligne du dessus a une collision.
const SURFACE_HEIGHT = 16.0
const FILL_HEIGHT = 16.0

# Une ligne par palier dans platforms.png (herbe, terre, lave, glace),
# 2 variantes par ligne.
const PLATFORM_ROWS = [0, 1, 2, 3]

# Blocs de world_tileset.png repérés en (colonne, ligne) de tuiles 16x16.
# FILL = bloc plein posé SOUS la plateforme (effet "bloc épais").
const FILL_CELLS = [
	Vector2(0, 1), # terre brune
	Vector2(2, 1), # pierre claire
	Vector2(4, 1), # brique rouge/rose
	Vector2(6, 1), # glace cyan
]
# WALL = bloc répété sur toute la hauteur d'un mur vertical.
const WALL_CELLS = [
	Vector2(0, 1), # terre brune
	Vector2(2, 1), # pierre claire
	Vector2(4, 0), # bloc orange/lave
	Vector2(6, 1), # glace cyan
]

static func get_tier(progress: float) -> int:
	if progress < TIER_THRESHOLDS[0]:
		return 0
	elif progress < TIER_THRESHOLDS[1]:
		return 1
	elif progress < TIER_THRESHOLDS[2]:
		return 2
	else:
		return 3

# Une tuile = un Sprite qui n'affiche qu'un petit rectangle (region) de la
# feuille de textures. On n'étire JAMAIS : chaque tuile garde sa taille
# d'origine et on en pose autant qu'il en faut pour couvrir la largeur/hauteur.
# (Un TextureRect + AtlasTexture ne répète pas la texture de façon fiable
# dans Godot 3, c'est ce qui donnait des plateformes toutes fines et moches.)
static func _make_tile(texture: Texture, region: Rect2, pos: Vector2) -> Sprite:
	# Pixel art : pas de filtrage, sinon les bords des tuiles bavent.
	texture.flags = 0
	var s = Sprite.new()
	s.texture = texture
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = pos
	return s

# Plateforme horizontale centrée sur `parent` : ligne du dessus
# (platforms.png, tuiles de 32px) + bloc plein dessous (world_tileset,
# tuiles de 16px). `width` doit être un multiple de 32.
# Le dessus solide occupe y de -SURFACE_HEIGHT/2 à +SURFACE_HEIGHT/2,
# donc la collision (extents = width/2, SURFACE_HEIGHT/2) est centrée en 0.
static func add_platform_visual(parent: Node, width: float, tier: int) -> void:
	var left = -width / 2.0
	var top_y = -SURFACE_HEIGHT / 2.0

	var n_top = int(width / PLATFORM_TILE_W)
	for i in range(n_top):
		var col = randi() % 2
		var region = Rect2(col * PLATFORM_TILE_W, PLATFORM_ROWS[tier] * PLATFORM_TILE_H, PLATFORM_TILE_W, PLATFORM_TILE_H)
		parent.add_child(_make_tile(PLATFORM_TEXTURE, region, Vector2(left + i * PLATFORM_TILE_W, top_y)))

	var cell = FILL_CELLS[tier]
	var fill_region = Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)
	var n_fill = int(width / TILE)
	var fill_rows = int(FILL_HEIGHT / TILE)
	for row in range(fill_rows):
		for i in range(n_fill):
			var pos = Vector2(left + i * TILE, SURFACE_HEIGHT / 2.0 + row * TILE)
			parent.add_child(_make_tile(TILESET_TEXTURE, fill_region, pos))

# Mur vertical centré sur `parent` : une colonne de blocs 16x16 empilés.
# `height` doit être un multiple de 16, `width` = 16.
static func add_wall_visual(parent: Node, width: float, height: float, tier: int) -> void:
	var cell = WALL_CELLS[tier]
	var region = Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)
	var n_cols = int(width / TILE)
	var n_rows = int(height / TILE)
	for r in range(n_rows):
		for c in range(n_cols):
			var pos = Vector2(-width / 2.0 + c * TILE, -height / 2.0 + r * TILE)
			parent.add_child(_make_tile(TILESET_TEXTURE, region, pos))

# --- Dégradé de couleur du texte (score/timer), sur la même échelle 0..1 ---
# blanc au sol -> doré -> orange lave -> cyan glacé tout en haut.
static func build_text_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = PoolColorArray([
		Color(1.0, 1.0, 1.0, 1.0),   # blanc, lisible sur le ciel bleu du départ
		Color(1.0, 0.85, 0.4, 1.0),  # doré, palier terre
		Color(1.0, 0.55, 0.25, 1.0), # orange, palier lave
		Color(0.65, 0.95, 1.0, 1.0), # cyan glacé, palier espace
	])
	g.offsets = PoolRealArray([0.0, 0.33, 0.66, 1.0])
	return g

static func get_text_color(gradient, progress) -> Color:
	return gradient.interpolate(clamp(progress, 0.0, 1.0))

# Police pixel commune à toute l'UI de jeu (voir Asset/fonts/PixelFont.tres).
static func load_pixel_font() -> DynamicFont:
	return load("res://Asset/fonts/PixelFont.tres") as DynamicFont

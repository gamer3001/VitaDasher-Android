extends Reference
class_name Biome

# "Palier" visuel en fonction de la même progression 0..1 que SkyGradient
# (0 = herbe/jour, 1 = terre, 2 = lave, 3 = glace/espace), pour que le sol,
# le ciel et le texte changent tous ensemble au fur et à mesure qu'on monte.
const TIER_THRESHOLDS = [0.25, 0.5, 0.75]

const TILESET_TEXTURE = preload("res://Asset/sprites/world_tileset.png")
const TILE = 16.0

# Hauteur de la ligne "dessus solide" (celle qui a la collision) et du bloc
# décoratif posé dessous. Les deux viennent de world_tileset, en tuiles de
# 16x16 qui s'emboîtent proprement côte à côte (contrairement à
# platforms.png, dont les tuiles sont des mini-plateformes aux bords
# arrondis, pas faites pour être répétées : c'est ce qui donnait ce rendu
# bizarre en "touffes d'herbe" décrochées).
const SURFACE_HEIGHT = TILE
const FILL_HEIGHT = TILE

# Bloc AVEC touffe d'herbe/sommet, utilisé pour la ligne du dessus.
const SURFACE_CELLS = [
	Vector2(0, 0), # herbe verte
	Vector2(2, 0), # pierre claire, sommet rocheux
	Vector2(4, 0), # bloc orange/lave
	Vector2(6, 0), # glace cyan
]
# Bloc plein (sans sommet), utilisé pour la couche décorative en dessous et
# pour les murs verticaux.
const FILL_CELLS = [
	Vector2(0, 1), # terre brune
	Vector2(2, 1), # pierre claire
	Vector2(4, 1), # brique rouge/rose
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
# feuille de textures, jamais étiré : chaque tuile garde sa taille d'origine
# et on en pose autant qu'il en faut pour couvrir la largeur/hauteur voulue.
static func _make_tile(region: Rect2, pos: Vector2) -> Sprite:
	TILESET_TEXTURE.flags = 0 # pixel art : pas de filtrage, sinon les bords bavent
	var s = Sprite.new()
	s.texture = TILESET_TEXTURE
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = pos
	return s

# Plateforme horizontale centrée sur `parent` : une ligne de blocs "herbe"
# (avec collision) et une ligne de blocs pleins dessous (décor). `width`
# doit être un multiple de 16. La collision (extents = width/2,
# SURFACE_HEIGHT/2) doit être centrée en (0,0), pile sur la ligne du dessus.
static func add_platform_visual(parent: Node, width: float, tier: int) -> void:
	var left = -width / 2.0
	var top_y = -SURFACE_HEIGHT / 2.0
	var n = int(width / TILE)

	var surface_cell = SURFACE_CELLS[tier]
	var surface_region = Rect2(surface_cell.x * TILE, surface_cell.y * TILE, TILE, TILE)
	for i in range(n):
		parent.add_child(_make_tile(surface_region, Vector2(left + i * TILE, top_y)))

	var fill_cell = FILL_CELLS[tier]
	var fill_region = Rect2(fill_cell.x * TILE, fill_cell.y * TILE, TILE, TILE)
	for i in range(n):
		parent.add_child(_make_tile(fill_region, Vector2(left + i * TILE, SURFACE_HEIGHT / 2.0)))

# Mur vertical centré sur `parent` : une colonne de blocs 16x16 empilés.
# `height` doit être un multiple de 16, `width` = 16.
static func add_wall_visual(parent: Node, width: float, height: float, tier: int) -> void:
	var cell = FILL_CELLS[tier]
	var region = Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)
	var n_cols = int(width / TILE)
	var n_rows = int(height / TILE)
	for r in range(n_rows):
		for c in range(n_cols):
			var pos = Vector2(-width / 2.0 + c * TILE, -height / 2.0 + r * TILE)
			parent.add_child(_make_tile(region, pos))

# --- Dégradé de couleur du texte (score/timer), sur la même échelle 0..1 ---
# blanc au sol -> doré -> orange lave -> cyan glacé tout en haut.
static func build_text_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = PoolColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.85, 0.4, 1.0),
		Color(1.0, 0.55, 0.25, 1.0),
		Color(0.65, 0.95, 1.0, 1.0),
	])
	g.offsets = PoolRealArray([0.0, 0.33, 0.66, 1.0])
	return g

static func get_text_color(gradient, progress) -> Color:
	return gradient.interpolate(clamp(progress, 0.0, 1.0))

# Police pixel commune à toute l'UI de jeu (voir Asset/fonts/PixelFont.tres).
static func load_pixel_font() -> DynamicFont:
	return load("res://Asset/fonts/PixelFont.tres") as DynamicFont

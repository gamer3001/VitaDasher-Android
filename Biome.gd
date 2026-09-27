extends Reference
class_name Biome

# "Palier" visuel en fonction de la même progression 0..1 que SkyGradient
# (0 = herbe/jour, 1 = terre, 2 = lave, 3 = glace/espace), pour que le sol,
# le ciel et le texte changent tous ensemble au fur et à mesure qu'on monte.
#
# Utilisation :
#   var tier = Biome.get_tier(progress)
#   texture_rect.texture = Biome.make_platform_texture(tier)
#   texture_rect.stretch_mode = TextureRect.STRETCH_TILE   # jamais STRETCH_SCALE !
const TIER_THRESHOLDS = [0.25, 0.5, 0.75]

const PLATFORM_TEXTURE = preload("res://Asset/sprites/platforms.png")
const WALL_TEXTURE = preload("res://Asset/sprites/world_tileset.png")

const PLATFORM_TILE_W = 32
const PLATFORM_TILE_H = 16
const WALL_TILE_SIZE = 16

# Une ligne par palier dans platforms.png (herbe, terre, lave, glace), avec
# 2 variantes par ligne pour casser un peu la répétition visuelle.
const PLATFORM_ROWS = [0, 1, 2, 3]

# Bloc plein (sans touffe d'herbe) le plus proche de chaque palier dans
# world_tileset.png, repéré en (colonne, ligne) de tuiles 16x16.
const WALL_CELLS = [
	Vector2(0, 1), # terre brune (palier herbe : le mur est "sous" l'herbe)
	Vector2(2, 1), # pierre claire (palier terre)
	Vector2(4, 0), # bloc orange/lave (palier lave)
	Vector2(6, 1), # bloc de glace cyan (palier glace/espace)
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

# Texture d'une plateforme HORIZONTALE pour le palier donné. Le nœud qui
# l'utilise doit être en stretch_mode = STRETCH_TILE : la texture est alors
# répétée pour remplir la largeur, jamais étirée (c'est ça qui rendait les
# anciennes plateformes/murs moches quand on changeait leur taille).
static func make_platform_texture(tier: int) -> AtlasTexture:
	var row = PLATFORM_ROWS[tier]
	var col = 0 if randf() < 0.5 else 1
	var atlas = AtlasTexture.new()
	atlas.atlas = PLATFORM_TEXTURE
	atlas.region = Rect2(col * PLATFORM_TILE_W, row * PLATFORM_TILE_H, PLATFORM_TILE_W, PLATFORM_TILE_H)
	return atlas

# Texture d'un mur VERTICAL pour le palier donné : un bloc 16x16 destiné à
# être répété (tile) sur toute la hauteur du mur, jamais étiré non plus.
static func make_wall_texture(tier: int) -> AtlasTexture:
	var cell = WALL_CELLS[tier]
	var atlas = AtlasTexture.new()
	atlas.atlas = WALL_TEXTURE
	atlas.region = Rect2(cell.x * WALL_TILE_SIZE, cell.y * WALL_TILE_SIZE, WALL_TILE_SIZE, WALL_TILE_SIZE)
	return atlas

# --- Dégradé de couleur du texte (score/timer), sur la même échelle 0..1 ---
# Reprend l'idée du dégradé de ciel déjà existant, mais appliqué au texte :
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

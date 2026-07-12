extends Reference
class_name SkyGradient

# Dégradé de ciel : jour bleu -> coucher de soleil (orange/rose/violet)
# -> espace étoilé. Même principe qu'avant (une progression 0..1 calculée
# à partir de la hauteur du joueur), mais avec des étapes intermédiaires
# façon coucher de soleil, et l'espace repoussé beaucoup plus loin.
#
# Utilisation dans InfiniteMode.gd / SurvivalMode.gd :
#   onready var sky_gradient = SkyGradient.build_gradient()
#   ...
#   var progress = clamp(float(height) / SKY_TRANSITION_HEIGHT, 0.0, 1.0)
#   sky_color.color = SkyGradient.get_sky_color(sky_gradient, progress)
#   stars.modulate.a = SkyGradient.get_stars_alpha(progress)

static func build_gradient() -> Gradient:
	var g = Gradient.new()
	g.colors = PoolColorArray([
		Color(0.20, 0.50, 0.90), # ciel bleu de jour
		Color(0.55, 0.62, 0.80), # le bleu commence à se voiler
		Color(0.85, 0.55, 0.55), # rose du coucher de soleil
		Color(0.85, 0.40, 0.30), # orange profond, proche du soleil
		Color(0.45, 0.20, 0.45), # violet du crépuscule (comme la réf)
		Color(0.10, 0.05, 0.20), # nuit qui tombe
		Color(0.00, 0.00, 0.05), # espace / ciel étoilé
	])
	g.offsets = PoolRealArray([0.0, 0.40, 0.55, 0.65, 0.78, 0.90, 1.0])
	return g


static func get_sky_color(gradient, progress) -> Color:
	return gradient.interpolate(clamp(progress, 0.0, 1.0))


# Les étoiles ne doivent apparaître que tout à la fin, une fois qu'on
# approche vraiment de l'espace (sinon elles seraient visibles dès le
# début du dégradé, alors qu'on veut le ciel étoilé bien plus loin).
static func get_stars_alpha(progress) -> float:
	return clamp((progress - 0.85) / 0.15, 0.0, 1.0)

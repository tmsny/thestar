extends Node3D



## Testwelt: stehende Trainings-NPCs in verschiedenen Entfernungen. Der Schaden,
## den man anrichtet, wird unten im HUD angezeigt (z. B. "-72"). Rueckkehr ueber
## das Pause-Menue (ESC -> HAUPTMENU).

func _ready() -> void:
	GameConfig.ensure_loaded()
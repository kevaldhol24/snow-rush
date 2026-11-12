extends Node
## Dev tool: pull only the clips the rider uses out of the Universal Animation Library GLBs
## (Quaternius, CC0) into one small AnimationLibrary resource. Re-run after changing CLIPS:
##   godot --headless --path . res://scenes/dev/extract_rider_anims.tscn
## The UAL GLBs themselves stay out of git (tools/fetch_assets.sh puts them in assets/raw_packs/, git-ignored).
const SRC := {
	"ual1": "res://assets/raw_packs/quaternius_ual/UAL1_Standard.glb",
	"ual2": "res://assets/raw_packs/quaternius_ual/UAL2_Standard.glb",
}
const CLIPS := {
	"ual1": ["Idle", "Crouch_Idle", "Death01", "Jump_Start", "Jump", "Jump_Land", "Roll", "Hit_Chest"],
	"ual2": ["NinjaJump_Start", "NinjaJump_Idle", "NinjaJump_Land", "Hit_Knockback", "Slide"],
}
const OUT := "res://assets/models/rider_q/rider_anims.res"

func _ready() -> void:
	var lib := AnimationLibrary.new()
	for key in SRC:
		var sc: Node = load(SRC[key]).instantiate()
		var ap: AnimationPlayer = sc.find_children("*", "AnimationPlayer", true, false)[0]
		var src: AnimationLibrary = ap.get_animation_library("")
		for nm in CLIPS[key]:
			if src.has_animation(nm):
				lib.add_animation(key + "_" + nm, src.get_animation(nm).duplicate(true))
			else:
				printerr("missing clip ", key, "/", nm)
		sc.free()
	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT, " clips=", lib.get_animation_list().size(), " err=", err)
	get_tree().quit()

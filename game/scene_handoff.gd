class_name SceneHandoff
extends RefCounted

# What the maze and the left-wall secret scene tell each other across a
# scene change (change_scene_to_file() frees the old scene, so this lives in
# static vars): which diver went in, and that the maze should put the party
# back at the secret entrance rather than its normal start.

static var diver_model := ""
static var returning_from_secret_wall := false
# The maze when it's part of the open world (MazeLevel.world set): the secret
# scene is then shown over the paused world instead of replacing it, and
# hands back to this maze when it's done (see MazeLevel._enter_secret_wall()).
static var embedded_maze: Node = null

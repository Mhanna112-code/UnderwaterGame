class_name SceneHandoff
extends RefCounted

# What the maze and the left-wall secret scene tell each other across a
# scene change (change_scene_to_file() frees the old scene, so this lives in
# static vars): which diver went in, and that the maze should put the party
# back at the secret entrance rather than its normal start.

static var diver_model := ""
static var returning_from_secret_wall := false
static var checkpoint_load_error := ""
static var returning_to_world := false

# Single-use ownership transfer. The receiving scene owns this session after
# taking it; no stale static copy can contaminate a standalone maze review.
static var campaign_session: CampaignSession

static func take_campaign_session() -> CampaignSession:
	var session := campaign_session
	campaign_session = null
	return session

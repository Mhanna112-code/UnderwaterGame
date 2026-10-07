class_name SceneHandoff
extends RefCounted

# Static state across change_scene_to_file(): which diver went in and whether to return to the secret entrance.

static var diver_model := ""
static var returning_from_secret_wall := false
static var checkpoint_load_error := ""
static var returning_to_world := false

# Single-use: the receiving scene takes ownership.
static var campaign_session: CampaignSession

static func take_campaign_session() -> CampaignSession:
	var session := campaign_session
	campaign_session = null
	return session

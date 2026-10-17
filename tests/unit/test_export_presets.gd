extends GutTest
## Export presets: Android builds an AAB, both platforms ship the data files,
## and no signing secret is stored in the repository.

const PRESETS := "res://export_presets.cfg"

var _config: ConfigFile = ConfigFile.new()


func before_all() -> void:
	assert_eq(_config.load(PRESETS), OK)


func _section(platform: String) -> String:
	for section: String in _config.get_sections():
		if _config.get_value(section, "platform", "") == platform:
			return section
	return ""


func test_both_platforms_have_a_preset() -> void:
	assert_ne(_section("Android"), "")
	assert_ne(_section("iOS"), "")


func test_dev_files_and_build_output_stay_out() -> void:
	for platform: String in ["Android", "iOS", "Web"]:
		var exclude: String = _config.get_value(_section(platform), "exclude_filter")
		for folder: String in ["tests/*", "tools/*", "addons/gut/*", "build/*"]:
			assert_string_contains(exclude, folder, platform)


func test_data_and_backend_config_are_included() -> void:
	for platform: String in ["Android", "iOS"]:
		var include: String = _config.get_value(_section(platform), "include_filter")
		assert_string_contains(include, "data/*.json")
		assert_string_contains(include, "config/backend.local.json")


func test_android_builds_a_signed_aab_with_the_permissions_it_uses() -> void:
	var options := _section("Android") + ".options"
	assert_true(_config.get_value(options, "gradle_build/use_gradle_build"))
	assert_eq(_config.get_value(options, "gradle_build/export_format"), 1, "1 = Export AAB")
	assert_true(_config.get_value(options, "permissions/internet"))
	assert_true(_config.get_value(options, "permissions/vibrate"))
	assert_false(_config.get_value(options, "user_data_backup/allow"))


func test_no_secrets_are_committed() -> void:
	var options := _section("Android") + ".options"
	for key: String in ["keystore/release", "keystore/debug"]:
		assert_eq(_config.get_value(options, key, ""), "", key + " comes from env vars")
	for key: String in ["keystore/release_password", "keystore/release_user"]:
		assert_false(_config.has_section_key(options, key), key + " comes from env vars")
	var ios := _section("iOS") + ".options"
	assert_eq(_config.get_value(ios, "application/app_store_team_id", ""), "")
	assert_false(_config.get_value(ios, "privacy/tracking_enabled"))


func test_web_build_runs_without_special_server_headers() -> void:
	var options := _section("Web") + ".options"
	# GitHub Pages cannot send the headers that threaded web builds need.
	assert_false(_config.get_value(options, "variant/thread_support"))
	assert_true(_config.get_value(options, "progressive_web_app/enabled"))
	assert_string_contains(_config.get_value(_section("Web"), "include_filter"), "data/*.json")


func test_web_uses_the_compatibility_renderer() -> void:
	# Browsers only support it; phones keep the Mobile renderer.
	var project := ConfigFile.new()
	assert_eq(project.load("res://project.godot"), OK)
	assert_eq(project.get_value("rendering", "renderer/rendering_method"), "mobile")
	assert_eq(project.get_value("rendering", "renderer/rendering_method.web"), "gl_compatibility")

// To register your mod here, file an issue on https://github.com/kavika13/og_power_strip/issues/new
// Note that right now this requires a manual install of empty versions of these files to Data/PowerStrip
#include "../PowerStrip/Data/Scripts/flying_mod/flying_mod.as"
#include "../PowerStrip/Data/Scripts/bow_and_arrow/bow_and_arrow.as"
#include "../PowerStrip/Data/Scripts/first_person/first_person.as"

void PowerStripInit() {
    // clear aschar hooks
    character_update_state_before_per_state_update_mod_hooks.resize(0);
    character_update_movement_controls_before_update_air_attack_controls_mod_hooks.resize(0);
    character_handle_air_collisions_before_landing_mod_hooks.resize(0);

    // clear aircontrols hooks
    jump_info_hit_wall_on_hit_wall_detected_mod_hooks.resize(0);
    jump_info_lost_wall_contact_on_lost_wall_contact_detected_mod_hooks.resize(0);
    jump_info_update_free_air_animation_on_set_flailing_animation_mod_hooks.resize(0);
    jump_info_update_free_air_animation_on_set_jump_animation_mod_hooks.resize(0);
    jump_info_update_wall_run_on_wants_to_flip_off_wall_mod_hooks.resize(0);
    jump_info_update_air_controls_after_set_jetpack_velocity_mod_hooks.resize(0);
    jump_info_update_air_controls_before_set_jump_velocity_mod_hooks.resize(0);
    jump_info_start_jump_after_get_non_path_jump_velocity_mod_hooks.resize(0);

    FlyingModInit();
    BowAndArrowModInit();
    FirstPersonModInit();
}

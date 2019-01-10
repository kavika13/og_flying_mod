bool g_is_script_initialized = false;
bool g_flying_mod_is_enabled = true;

void Init(string _unused_level_name) {
    // Intentionally empty. Have to call functions to update config later, otherwise we run into problems with uninitialized state
}

void Update() {
    if(!g_is_script_initialized) {
        if(GetConfigValueString("flying_mod_is_enabled") != "") {
            // Config value is found
            g_flying_mod_is_enabled = GetConfigValueBool("flying_mod_is_enabled");
        }

        uint toggle_flying_key_scancode = GetCodeForKey("f");

        if(GetBindingValue("key", "flying_mod_debug_lightning_override") == "") {
            // Binding is not in config file, so set it
            // Use the "g" key if we have a conflict
            uint new_binding_key_scancode = GetCodeForKey("g");
            string existing_debug_lightning_key_binding = GetBindingValue("key", "debug_lightning");

            if(existing_debug_lightning_key_binding != "") {
                uint existing_debug_lightning_key_scancode = GetCodeForKey(existing_debug_lightning_key_binding);

                if(existing_debug_lightning_key_scancode != toggle_flying_key_scancode) {
                    // Existing binding doesn't conflict with the toggle flying "f" key, so use it instead
                    new_binding_key_scancode = existing_debug_lightning_key_scancode;
                }
            }

            SetKeyboardBindingValue("key", "flying_mod_debug_lightning_override", new_binding_key_scancode);
        }

        if(GetBindingValue("key", "flying_mod_toggle_flying") == "") {
            // Binding is not in config file, so set it
            SetKeyboardBindingValue("key", "flying_mod_toggle_flying", toggle_flying_key_scancode);
        }

        OnFlyingModIsEnabledUpdated_(false);

        g_is_script_initialized = true;
    }
}

void Menu() {
    if(ImGui_MenuItem("Enable Flying Mod", g_flying_mod_is_enabled)) {
        g_flying_mod_is_enabled = !g_flying_mod_is_enabled;
        OnFlyingModIsEnabledUpdated_();
    }
}

void OnFlyingModIsEnabledUpdated_(bool save_to_config = true) {
    const string message_to_send = g_flying_mod_is_enabled ? "flying_mod_enabled" : "flying_mod_disabled";

    for(int i = 0, char_count = GetNumCharacters(); i < char_count; ++i) {
        ReadCharacter(i).QueueScriptMessage(message_to_send);
    }

    if(save_to_config) {
        SetConfigValueBool("flying_mod_is_enabled", g_flying_mod_is_enabled);
    }
}

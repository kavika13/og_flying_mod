// Controls
string flapping = "attack";
string gliding = "grab";
string flyingToggleKey = "f";

bool flyingActive = false;
int flyingMode = 0;
float flap_counter = 1.0f;
float flap_modifier = 0.3f;
float tilt_modifier = 1.0f;
vec3 oldFlyFace = vec3(0.0f);
float roll_modifier = 0.0f;
bool is_swooped = false;
int air_dash = 0;
bool has_air_dash = true;
vec3 dash_direction = vec3(0);
bool after_wall_flip = false;
float wall_flip_time = 0.0f;
const int _TETHERED_SWOOP = -1;
float _air_control_extra = _air_control * 4.0f;

void FlyingMode() {
    if (GetInputDown(this_mo.controller_id, flapping) && this_mo.controlled) {
        // Flapping
        flyingMode = 1;
    } else if (GetInputDown(this_mo.controller_id, gliding) && this_mo.controlled) {
        // Gliding
        flyingMode = 2;
    } else {
        // Falling
        flyingMode = 0;
    }
}

void UpdateFlying(const Timestep& in ts) {
    if (flyingActive) {
        FlyingMode();
        FlyingAttacks();
        FlyingAnimations();
        AirDash();
        CheckForSwoopDrag();

        if (flyingMode == 1) {
            // Flapping
            float tempY = this_mo.velocity.y;
            this_mo.velocity = NewDirection(GetTargetVelocity(), 0.01f);
            this_mo.velocity.y = tempY;
            flap_counter += flap_modifier;

            if (!jump_info.hit_wall) {
                if (this_mo.velocity.y < 0) {
                    this_mo.velocity.y += 0.1f;
                }

                if (flap_modifier < 0 && this_mo.velocity.y < 10.0f) {
                    this_mo.velocity.y += 0.5f;
                }

                if (flap_counter > 50.0f) {
                    flap_modifier = -1.0f;
                } else if (flap_counter < 2.0f) {
                    flap_modifier = 0.5f;
                }

                if (tilt_modifier < 1.8f) {
                    tilt_modifier += 0.02f;
                } else if (tilt_modifier > 2.0f) {
                    tilt_modifier -= 0.02f;
                }
            } else if (this_mo.velocity.y < 10.0f) {
                this_mo.velocity.y+= 0.2f;
            }
        } else {
            flap_counter = 40.0f;
            flap_modifier = 0.5f;

            if (flyingMode == 2) {
                // Gliding
                this_mo.velocity = NewDirection(camera.GetFacing(), 0.03f);

                if (this_mo.velocity.y > 0) {
                    if (air_time > 2.0f) {
                        this_mo.velocity.y -= 0.3f;
                    }

                    if (tilt_modifier > 3.0f) {
                        tilt_modifier -= 0.02f;
                    }
                }

                if (tilt_modifier < 4.5f) {
                    tilt_modifier += 0.05f;
                }
            } else if (tilt_modifier > 1.0f) {
                // Falling
                tilt_modifier -= 0.02f;
            }
        }

        if (!jump_info.hit_wall) {
            // Tilt
            if (this_mo.velocity.x != 0 || this_mo.velocity.z != 0) {
                tilt = this_mo.velocity * tilt_modifier;
                float tilt_cap = 90.0f;
                tilt_cap -= this_mo.velocity.y * 2;

                if (length(tilt) > tilt_cap) {
                    tilt = normalize(tilt) * tilt_cap;
                }
            }

            // Roll
            if (air_time < 0.1f) {
                roll_modifier = 0;
            }

            vec3 flyFace = normalize(flatten(this_mo.velocity));
            vec3 cross_flyFace = cross(oldFlyFace, flyFace);

            if (roll_modifier > 1.0f) {
                roll_modifier = 1.0f;
            } else if (roll_modifier < -1.0f) {
                roll_modifier = -1.0f;
            } else {
                float old_roll = roll_modifier;
                roll_modifier += cross_flyFace.y;

                if (abs(roll_modifier) > abs(old_roll) - 0.001f) {
                    roll_modifier *= 0.97f;
                }
            }

            // Rotated 90 degrees left
            oldFlyFace = flyFace;
            float temp = oldFlyFace.x;
            oldFlyFace.x = -oldFlyFace.z;
            oldFlyFace.z = temp;

            flyFace = normalize(flyFace + oldFlyFace * roll_modifier * abs(roll_modifier) * 3.2f);
            this_mo.SetRotationFromFacing(flyFace);
            oldFlyFace = normalize(flatten(this_mo.velocity));
        }
    } else if (!jump_info.hit_wall) {
        this_mo.SetCharAnimation("jump", 20.0f, 0);
    }

    // Reduces movement control after wall flip
    if (after_wall_flip) {
        if (wall_flip_time > 0.6f) {
            after_wall_flip = false;
        } else {
            wall_flip_time += ts.step();
        }
    }

    // Ledge Jumping
    if (jump_info.ledge_delay == 0.3f && WantsToJump() && !ledge_info.on_ledge) {
        jump_info.StartWallJump(ledge_info.ledge_dir * -1.0f);
    }
}

void FlyingAttacks() {
    int air_attack_id = -1;

    if (WantsToDragBody() || air_dash > 0) {
        int closest_id = GetClosestCharacterID(3.0f, _TC_ENEMY | _TC_CONSCIOUS);
        air_attack_id = closest_id;
    }

    if (air_attack_id == -1) {
        return;
    }

    if (air_dash > 0 && length(this_mo.velocity) > 50.0f
            && distance(this_mo.position, ReadCharacterID(air_attack_id).position) <= _attack_range + range_extender) {
        // Air dash attack
        has_air_dash = true;
        target_id = air_attack_id;
        MovementObject @char = ReadCharacterID(target_id);
        vec3 start = this_mo.position;
        vec3 end = char.GetAvgIKChainPos("torso");
        PlaySound("Data/Sounds/ambient/amb_canyon_rock_1.wav", this_mo.position);
        vec3 force = normalize(char.position - this_mo.position) * 40000.0f;
        force.y += 1000.0f;
        char.Execute(
            "vec3 impulse = vec3(" + force.x + ", " + force.y + ", " + force.z + ");" +
            "HandleRagdollImpactImpulse(impulse, this_mo.GetAvgIKChainPos(\"torso\"), 5.0f);" +
            "ragdoll_limp_stun = 1.0f;" +
            "recovery_time = 2.0f;");
    } else if (WantsToGrabLedge() && !WantsToJump() && air_dash < 1 && length(this_mo.velocity) > 20.0f
            && distance(this_mo.position, ReadCharacterID(air_attack_id).position)
                <= _attack_range + range_extender + 0.5f) {
        // Swoop attack
        has_air_dash = true;
        target_id = air_attack_id;
        MovementObject @char = ReadCharacterID(target_id);
        PlaySound("Data/Sounds/ambient/amb_canyon_rock_1.wav", this_mo.position);
        tether_id = target_id;
        // MOD TEST
        // tethered = _TETHERED_DRAGBODY;
        tethered = _TETHERED_SWOOP;
        char.Execute(
            "SetTetherID(" + this_mo.getID() + ");" +
            "SetTethered(_TETHERED_DRAGGEDBODY);");
    }
}

void FlyingAnimations() {
    if (!jump_info.hit_wall) {
        if (flyingMode == 1 && air_dash < 1) {
            // Flapping
            this_mo.SetAnimation("Data/Custom/LePetitDocteur/Animations/wingflap.anm", 5.0f, 0);
            // this_mo.SetCharAnimation("jump", 20.0f, 0);
        } else if (flyingMode == 2 && air_dash < 1) {
            // Gliding
            if (this_mo.velocity.y < -24.0f) {
                this_mo.SetAnimation("Data/Custom/LePetitDocteur/Animations/diving.anm", 5.0f, 0);
            } else {
                this_mo.SetAnimation("Data/Custom/LePetitDocteur/Animations/glide.anm", 5.0f, 0);
            }
        } else {
            if (air_time > 0.5f) {
                this_mo.SetCharAnimation("jump", 5.0f, 0);
            } else {
                this_mo.SetCharAnimation("jump", 20.0f, 0);
            }
        }
    }
}

void AirDash() {
    if (jump_info.hit_wall || air_time < 0.1f) {
        has_air_dash = true;
    }

    if (!jump_info.hit_wall) {
        if (has_air_dash && this_mo.controlled && tethered == _TETHERED_FREE && WantsToFlip()
                && !flip_info.IsFlipping()) {
            has_air_dash = false;

            if (air_dash < 1) {
                air_dash = 100 ;
            }
        } else if (air_dash > 0) {
            air_dash--;
        }

        if (air_dash > 0) {
            if (length(this_mo.velocity) < 80.0f) {
                this_mo.velocity *= 1.02f;
            }

            if (!flip_info.IsFlipping()) {
                flip_info.StartFlip();
            }

            for (int i = 0; i < 3; i++) {
                SpinSpark();
            }
        }
    }
}

void FlyingStuff(const Timestep& in ts) {
    // Toggle flying
    if (this_mo.controlled && GetInputPressed(this_mo.controller_id, flyingToggleKey)) {
        if (flyingActive) {
            flyingActive = false;
            air_dash = 0;
            PlaySound("Data/Sounds/ice_foley/bf_ice_heavy_2.wav", this_mo.position);
        } else {
            flyingActive = true;
            PlaySound("Data/Sounds/ambient/amb_canyon_hawk_1.wav");
        }
    }

    // Stop being ragdoll when swoop ends
    if (is_swooped && tethered != _TETHERED_DRAGGEDBODY) {
        is_swooped = false;

        if (knocked_out == _unconscious) {
            SetKnockedOut(_awake);
            GoLimp();
        }
    }

    if (tethered == _TETHERED_SWOOP) {
        // Update ragdoll during swoop
        if (!on_ground) {
            MovementObject @char = ReadCharacterID(tether_id);
            drag_target = this_mo.position + this_mo.velocity * 0.02f;

            for (int i = 0; i < 25; i++) {
                char.MoveRagdollPart(drag_body_part, drag_target, 100);
            }
        } else if (on_ground_time < 1.0f) {
            UnTether();
        }
    }

    if (tethered == _TETHERED_DRAGBODY && on_ground_time < 1.0f) {
        UnTether();
    }

    // Go ragdoll when being swooped
    if (tethered == _TETHERED_DRAGGEDBODY && knocked_out == _awake) {
        is_swooped = true;
        GoLimp();
        SetKnockedOut(_unconscious);
    }

    if (tethered == _TETHERED_SWOOP) {
        if (!WantsToDragBody()) {
            UnTether();
            return;
        }

        MovementObject@ char = ReadCharacterID(tether_id);
        vec3 arm_pos = GetDragOffsetWorld();
        vec3 head_pos = char.GetIKChainPos(drag_body_part, drag_body_part_id);
        vec3 arm_pos_flat = vec3(arm_pos.x, 0.0f, arm_pos.z);
        vec3 head_pos_flat = vec3(head_pos.x, 0.0f, head_pos.z);
        float dist = distance(arm_pos_flat, head_pos_flat);

        if (drag_strength_mult > 0.3f) {
            drag_target = mix(arm_pos, drag_target, pow(0.95f, ts.frames()));
            char.MoveRagdollPart(drag_body_part, drag_target, drag_strength_mult);
        } else {
            drag_target = head_pos;
        }

        char.Execute("RagdollRefresh(1);");

        float old_drag_strength_mult = drag_strength_mult;
        drag_strength_mult = mix(1.0f, drag_strength_mult, pow(0.95f, ts.frames()));

        if (old_drag_strength_mult < 0.7f && drag_strength_mult >= 0.7f) {
            PlaySoundGroup("Data/Sounds/hit/grip.xml", this_mo.position);
        }

        // DebugDrawWireSphere(head_pos, 0.2f, vec3(1.0f), _delete_on_update);
        tether_rel = char.position - this_mo.position;
        tether_rel.y = 0.0f;
        tether_rel = normalize(tether_rel);
        this_mo.SetRotationFromFacing(InterpDirections(this_mo.GetFacing(), tether_rel, 1.0 - pow(0.95f, ts.frames())));
    }

    if (ledge_info.on_ledge && air_dash > 0) {
        air_dash = 0;
    }
}

void WallCrash() {
    vec3 closest_point;
    float closest_dist = -1.0f;

    for (int i = 0; i < sphere_col.NumContacts(); i++) {
        const CollisionPoint contact = sphere_col.GetContact(i);
        float dist = distance_squared(contact.position, this_mo.position);

        if (closest_dist == -1.0f || dist < closest_dist) {
            closest_dist = dist;
            closest_point = contact.position;
        }
    }

    jump_info.wall_dir = normalize(closest_point - this_mo.position);

    if (length(this_mo.velocity) * dot(normalize(flatten(this_mo.velocity)), jump_info.wall_dir) > 12.0f) {
        GoLimp();
        has_air_dash = false;
    }

    air_dash = 0;
}

void SetJumpVelocity(const Timestep& in ts) {
    vec3 target_velocity = GetTargetVelocity();

    // Reduces movement control after wall flip and reduces acceleration over velocity limit
    float velocity_size =
        this_mo.velocity.x * this_mo.velocity.x
        + this_mo.velocity.z * this_mo.velocity.z;
    float updated_velocity_size =
        (this_mo.velocity.x + target_velocity.x) * (this_mo.velocity.x + target_velocity.x)
        + (this_mo.velocity.z + target_velocity.z) * (this_mo.velocity.z + target_velocity.z);

    if (after_wall_flip) {
        this_mo.velocity += _air_control * target_velocity * ts.step();
    } else if (!(updated_velocity_size > 150)) {
        this_mo.velocity += _air_control_extra * target_velocity * ts.step();
    } else {
        // Increases sideward and backward control at high speeds
        if (updated_velocity_size < velocity_size + 22 && this_mo.controlled) {
            if (updated_velocity_size < velocity_size) {
                this_mo.velocity += _air_control_extra * target_velocity * ts.step() * 2;
            } else {
                this_mo.velocity.x *= 0.996f;
                this_mo.velocity.z *= 0.996f;
                this_mo.velocity += target_velocity * _air_control_extra * ts.step();
            }
        }

        this_mo.velocity += _air_control * target_velocity * ts.step();
    }
}

void CheckForSwoopDrag() {
    // FLYING MOD No body drag when air dashing or holding jump
    if (tethered == _TETHERED_FREE && this_mo.controlled && WantsToDragBody() && !WantsToJump() && air_dash < 1) {
        int closest_id = GetClosestCharacterID(2.0f, _TC_RAGDOLL | _TC_UNCONSCIOUS);

        if (closest_id != -1) {
            MovementObject@ char = ReadCharacterID(closest_id);
            drag_body_part = "head";
            drag_body_part_id = 0;
            tether_id = closest_id;
            tethered = _TETHERED_SWOOP;
            drag_strength_mult = 0.0f;
            char.Execute(
                "SetTetherID(" + this_mo.getID() + ");" +
                "SetTethered(_TETHERED_DRAGGEDBODY);");
        }
    }
}

// Change direction without speed loss
vec3 NewDirection(vec3 newdir, float direction_modifier) {
    vec3 old_dir = normalize(this_mo.velocity);
    float len = length(this_mo.velocity);
    vec3 new_dir = normalize(newdir);
    new_dir = normalize(new_dir * direction_modifier + old_dir);
    new_dir *= len;

    return new_dir;
}

// Print vector
void printvec(vec3 vec) {
    Print("\nx: " + vec.x + "   y: " + vec.y + "   z: " + vec.z);
}

// Sparkle effects when air dashing
void SpinSpark() {
    vec3 com = this_mo.GetCenterOfMass();

    vec3 tempaxis = flip_info.flip_axis;
    // Rotated 90 degrees left
    float temp = tempaxis.x;
    tempaxis.x = -tempaxis.z;
    tempaxis.z = temp;

    vec3 displ = normalize(
        vec3(RangedRandomFloat(-1.0f, 1.0f), RangedRandomFloat(-1.0f, 1.0f), RangedRandomFloat(-1.0f, 1.0f)));
    displ = displ - tempaxis * dot(displ, tempaxis);
    displ = normalize(displ) * 0.5f;
    displ += tempaxis * RangedRandomFloat(-0.3f, 0.3f);

    vec3 head_pos = com + displ;
    vec3 spin_vel = normalize(cross(displ, tempaxis)) * -3.0f;
    spin_vel += displ * -1.3f;
    MakeParticle("Data/Custom/NMcCoy/Particles/sparkle2.xml", head_pos, spin_vel);
    // MakeParticle("Data/Particles/metalspark.xml", head_pos, spin_vel);
}

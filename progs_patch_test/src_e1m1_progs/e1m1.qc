// load the fields that we need to exist already
// we can only access these fields by using the patch_getfield/patch_setfield functions
patch_field f_touch, f_classname, f_origin;

// load the non-builtin globals that we need to exist already
// we can only access these globals by using the patch_getglobal/patch_setglobal functions
patch_global g_other;

// load these funcs from whatever mod/gamedir we're running on
patch_func void() fn_monster_shalrath = {};
patch_func void() fn_monster_wizard = {};
patch_func void() fn_monster_army = {};
patch_func void() fn_func_button = {};
patch_func void() fn_weapon_rocketlauncher = {};
patch_func void() fn_item_health = {};
patch_func void() fn_item_rockets = {};

// new fields, we can refer to them directly
.void() old_touch;

void() patchspawn_monster_army =
{
    if (random() < 0.5)
    {
        // spawn a shalrath instead of the grunt (pretty evil I know)
        patch_setfield(self, f_classname, "monster_shalrath");
        fn_monster_shalrath();
    }
    else
    {
        fn_monster_army();
    }
    
    // 50% change of spawning a wizard right above the shalrath
    if (random() < 0.5)
    {
        local entity this = self;
        local entity wiz = spawn();
        local vector wiz_origin = patch_getfield(self, f_origin) + '0 0 40';

        patch_setfield(wiz, f_classname, "monster_wizard");
        patch_setfield(wiz, f_origin, wiz_origin);
        
        self = wiz;
        fn_monster_wizard();
        self = this;
    }
};

void() patchspawn_item_health =
{
    // 50% change of spawning a rocket launcher instead of health
    if (random() < 0.5)
    {
        if (random() < 0.2)
        {
            patch_setfield(self, f_classname, "weapon_rocketlauncher");
            fn_weapon_rocketlauncher();  
        }
        else
        {
            fn_item_rockets();
        }
    }
    else
    {
        fn_item_health();
    }
};

void() custom_touch_button =
{
    centerprint(patch_getglobal(g_other), "Thank you for using this button!\n");
    self.old_touch();
};

void() patchspawn_func_button =
{
    // call the original spawn function
    fn_func_button();
    
    self.old_touch = patch_getfield(self, f_touch);
    patch_setfield(self, f_touch, custom_touch_button);
};

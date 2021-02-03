float f_use, f_touch, f_classname, f_origin;

float g_activator;

void() fn_monster_shalrath = {};
void() fn_monster_wizard = {};
void() fn_func_door = {};

void() spawnfunc_monster_army =
{
    patch_setfield(self, f_classname, "monster_shalrath");
    fn_monster_shalrath();//patch_call0("monster_shalrath");
    
    local entity this = self;
    local entity wiz = spawn();
    local vector wiz_origin = patch_getfield(self, f_origin) + '0 0 40';

    patch_setfield(wiz, f_classname, "monster_wizard");
    patch_setfield(wiz, f_origin, wiz_origin);
    
    self = wiz;
    fn_monster_wizard();
    self = this;
};

void() custom_use_door =
{
    bprint(patch_getfield(self, f_classname));
    centerprint(patch_getglobal(g_activator), "NICE\n");
};

void() spawnfunc_func_door =
{
    fn_func_door();

    patch_setfield(self, f_use, custom_use_door);
};
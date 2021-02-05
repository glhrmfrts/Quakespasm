/*==============================================================================
SENTINEL (Originally from Quoth - Kell/Necros/Preach)
  * QC was created for AD mappers to play with in their own projects
  * Original Quoth model/sounds not included with main MOD
 
  Interesting QC traits
  * All stand/walk/run go through single function, easier setup
  * Has no front section to model, wakeup event is 360 FOV
  * Does not move when attacking so can maintain original height
  * Will move very fast when out of sight of enemy
  * No head model or body on death, just a pile of gibs
  
  QUOTH assets required to get this monster working in AD
    (model's in 'progs' and wav's in 'sound' sub directories)
  * sentinel.mdl -> mon_sentinel.mdl (rename file)
  * sentinel/widle1.wav, sentinel/widle2.wav, sentinel/wsight.wav
  * sentinel/laser.wav, sentinel/nail.wav, sentinel/wpain.wav

 ==============================================================================*/
// Writhe (move tentacles) animation
$frame idle1 idle2 idle3 idle4 idle5 idle6 idle7 idle8 idle9 idle10

// Pain (move tentacles) animation
$frame pain1 pain2 pain3 pain4 pain5 pain6

// Export frames (ignored)
$frame base1

// prefix required existing fields with 'p_'
.string p_classname;
.float p_spawnflags;
.float p_health;
.float p_frame;
.float p_nextthink;
.void() p_think;
.float p_solid;
.float p_movetype;
.vector p_velocity;
.float p_attack_finished;
.float p_pain_finished;
.float p_lip;
.entity p_enemy;
.vector p_origin;
.float p_effects;
.vector p_angles;
.vector p_view_ofs;
//.float p_inpain;
.void() p_th_run;
.void() p_th_stand;
.void() p_th_walk;
.void() p_th_pain;
.void() p_th_die;
.void() p_th_missile;

// prefix OPTIONAL existing fields with 'op_'
.float() op_th_checkattack;
.float op_invisible_finished;

// prefix required existing globals with 'p_'
float p_enemy_range;
float p_SOLID_NOT;
float p_SOLID_SLIDEBOX;
float p_MOVETYPE_FLY;
float p_MOVETYPE_STEP;
float p_MOVETYPE_NONE;
float p_EF_MUZZLEFLASH;
float p_CHAN_VOICE;
float p_CHAN_WEAPON;
float p_ATTN_NORM;
float p_RANGE_NEAR;
float p_RANGE_MID;
float p_RANGE_MELEE;
float p_RANGE_FAR;

// prefix required existing functions with 'pfn_'
void()                         pfn_ai_stand = {};
void(float f)                  pfn_ai_walk = {};
void(float f)                  pfn_ai_run = {};
void()                         pfn_flymonster_start = {};
void()                         pfn_monster_army = {};

// prefix OPTIONAL existing functions with 'opfn_'
// for vanilla
void(string gib, float health) opfn_ThrowGib = {};
void(vector org, vector dir)   opfn_LaunchLaser = {};

// for Copper
void(string gib, float health) opfn_Gib = {};
void(vector org, vector dir)   opfn_launch_laser = {};


// new globals and fields

float SENT_STAND = 0;		// Default state
float SENT_WALK = 1;		// Patrolling
float SENT_RUN = 2;			// Attacking - Sentry mode

.float sen_walkframe;
.float sen_attack_timer;
.float sen_inpain;

float(entity targ) visible_test =
{
	local vector spot1 = self.p_origin + self.p_view_ofs;
	local vector spot2 = targ.p_origin + targ.p_view_ofs;
	traceline (spot1, spot2, FALSE, self);
	return trace_ent == targ;
};

float() sent_clear_attack =
{
	vector spot1, spot2;

	if (self.p_enemy.op_invisible_finished > time) return TRUE;	// blast away

	spot1 = self.p_origin + self.p_view_ofs;
	spot2 = self.p_enemy.p_origin + self.p_enemy.p_view_ofs;

	traceline(spot1, spot2, FALSE, self);

	if (trace_inopen && trace_inwater) return FALSE;	// sight line crossed contents
	if (trace_ent != self.enemy) return FALSE;			// don't have a clear shot
	return TRUE;
}

float() sent_check_attack =
{
	if (time < self.p_attack_finished) return FALSE;
	if (p_enemy_range >= p_RANGE_FAR) return FALSE;
	if (!sent_clear_attack()) return FALSE;

	if (random() < 0.9)
	{
		self.p_th_missile ();
		self.p_attack_finished = time + 0.4;
		return TRUE;
	}

	return FALSE;
}

//======================================================================
// Update Sentinel every frame
// Its a great shame the quoth model has no idle animations
// - could have been body attachments or different tentacle movements
//======================================================================
void() sent_update = 
{	
	// If Sentinel is dead, no more updates
	if (self.p_health < 1) return;

	// Time for an idle sound?
	// if (self.idletimer < time) monster_idle_sound();

	// Update animation frame
	self.p_frame = $idle1 + self.sen_walkframe;

	// Move frame forward, check for conditions
	self.sen_walkframe = self.sen_walkframe + 1;
	if (self.sen_walkframe > 9) self.sen_walkframe = 0;

	self.p_nextthink = time + 0.1;
	self.p_think = sent_update;
	
	// Check sentinel states
	if (self.sen_attack_timer == SENT_STAND) {
		self.p_solid = p_SOLID_SLIDEBOX;
		self.p_movetype = p_MOVETYPE_FLY;

		// Change the movement type so that can easily move up/down
		// using velocity, forced origin movement is really jerky!
		if (self.p_velocity_x == 0 && self.p_velocity_y == 0) {
			if (self.p_attack_finished < time) {
				self.p_attack_finished = time + 2;

				if (self.p_lip < 1) self.p_lip = 1;
				else self.p_lip = -1;

				self.p_velocity_z = 2 * self.p_lip;
			}
		}
	
		pfn_ai_stand();
	}
	else if (self.sen_attack_timer == SENT_WALK) {
		self.p_solid = p_SOLID_SLIDEBOX;
		self.p_movetype = p_MOVETYPE_FLY;

		pfn_ai_walk(8);
	}
	else if (self.sen_attack_timer == SENT_RUN) {
		self.p_solid = p_SOLID_SLIDEBOX;
		self.p_movetype = p_MOVETYPE_FLY;

		// If can see enemy, don't move, just fire
		if (visible_test(self.p_enemy))
		{
			//self.movespeed = -1;

			if (patch_checkfunction(opfn_ThrowGib))
			{
				// if we're running on vanilla, we can't override CheckAttack routine,
				// so we must check for attacks manually here.
				if (sent_check_attack())
				{
					self.p_th_missile();
				}
			}

			pfn_ai_run(0);
		}
		// Cannot see enemy, track them down
		else {
			//self.movespeed = 1;
			pfn_ai_run(12);
		}
	}
};

//======================================================================
// All stand, walk and run functions are condensed down to one entry
// Might as well be one loop as there is only one animation set
//
void() sent_stand = { self.sen_attack_timer = SENT_STAND; sent_update(); };
void() sent_walk = { self.sen_attack_timer = SENT_WALK; sent_update(); };
void() sent_run = { self.sen_attack_timer = SENT_RUN; sent_update(); };

//===========================================================================
// RANGE ATTACK - Fires spikes or laser bolts
//===========================================================================
void() sent_attack =
{
	local vector org, dir;

	// Keep cycling the pain animation
	self.p_think = sent_run;
	self.p_nextthink = time + 0.1;

	if (self.p_enemy && self.p_health > 0)
	{		
		// Always make sure there is no monster or obstacle in the way
		// Cannot use enemy entity direct, enemytarget will be active
		// if ( !visxray(SUB_entEnemyTarget(), self.attack_offset, '0 0 12', FALSE) ) return;

		self.p_effects = self.p_effects | p_EF_MUZZLEFLASH;

		makevectors (self.p_angles);
		org = self.p_origin +  v_forward * 10 + '0 0 16';

		// Aim high to catch jumping players
		dir = self.p_enemy.p_origin + '0 0 12';

		// Use the enforcer fire function
		sound (self, p_CHAN_WEAPON, "sentinel/laser.wav", 1, p_ATTN_NORM);
		
		if (patch_checkfunction(opfn_LaunchLaser))
		{
			// vanilla
			opfn_LaunchLaser(org, dir - org);
		}
		else
		{
			// copper
			opfn_launch_laser(org, normalize(dir - org)*600);
		}
	}
};

//============================================================================
// ROBOT PAIN!?!
//============================================================================
void() sent_inpain =
{
	// Update animation frame
	self.p_frame = $pain1 + self.sen_inpain;

	// Move backwards away from damage
	//ai_backface(5-self.inpain);

	// Keep cycling the pain animation
	self.p_think = sent_inpain;
	self.p_nextthink = time + 0.1;
	
	// Start of pain cycle
	if (self.sen_inpain ==  0) {
		// Spawn a pile of sparks and dust falling down
		// particle_dust(self.origin, 10+random()*10, 16, PARTICLE_BURST_YELLOW);
		// set(f_pain_finished, time + 0.5);
	}
	// Finished, back to combat
	else if (self.sen_inpain >= 5) {
		self.p_think = self.p_th_run;
	}
	
	// Next pain animation
	self.sen_inpain = self.sen_inpain + 1;
};

//----------------------------------------------------------------------
void() sent_pain =
{
	// Stop any ai_run velocity and reset movetype
	self.p_velocity = '0 0 0';
	self.p_solid = p_SOLID_SLIDEBOX;
	self.p_movetype = p_MOVETYPE_STEP;
	sound (self, p_CHAN_VOICE, "sentinel/wpain.wav", 1, p_ATTN_NORM);
	self.sen_inpain = 0;
	
	sent_inpain();
};

//============================================================================
void() sent_die =
{
	// regular death gib
	self.p_health = -100;

	sound (self, p_CHAN_VOICE, "sentinel/explode_major.wav", 1, p_ATTN_NORM);

	local void(string, float) gib_func;
	if (patch_checkfunction(opfn_ThrowGib))
	{
		// vanilla
		gib_func = opfn_ThrowGib;
	}
	else
	{
		// copper
		gib_func = opfn_Gib;
	}

	gib_func ("progs/gib1.mdl", self.p_health);
	gib_func ("progs/gib2.mdl", self.p_health);
	
	gib_func ("progs/sentinel_gib_metal1.mdl", self.p_health);
	gib_func ("progs/sentinel_gib_metal2.mdl", self.p_health);
	gib_func ("progs/sentinel_gib_metal3.mdl", self.p_health);

	setmodel(self, "");
	self.p_solid = p_SOLID_NOT;
	self.p_movetype = p_MOVETYPE_NONE;
};

/*======================================================================
QUAKED monster_sentinel (1 0 0) (-16 -16 -24) (16 16 24) Ambush
======================================================================*/
void() monster_sentinel =
{
	if (deathmatch)
	{
		remove(self);
		return;
	}

	precache_model("progs/sentinel_monster.mdl");
	precache_model("progs/sentinel_gib_metal1.mdl");
	precache_model("progs/sentinel_gib_metal2.mdl");
	precache_model("progs/sentinel_gib_metal3.mdl");
	precache_model("progs/laser.mdl");

	precache_sound("sentinel/widle1.wav");
	precache_sound("sentinel/widle2.wav");
	precache_sound("sentinel/wpain.wav");
	precache_sound("sentinel/wsight.wav");
	precache_sound("sentinel/laser.wav");
	precache_sound("enforcer/enfire.wav");
	precache_sound("enforcer/enfstop.wav");
	precache_sound("sentinel/explode_major.wav");

	// Alternative attack - red hot nails!?!
	//if (get(f_spawnflags) & MON_SENTINEL_NAIL) {
		//self.exactskin = 1;						// Nail version
		//precache_model(MODEL_PROJ_NGRED);		// Copy of freddie nails
		//precache_sound("weapons/rocket1i.wav");
		//precache_sound("sentinel/nail.wav");	// Unique nail fire
	//}

	self.p_solid = p_SOLID_SLIDEBOX;
	self.p_movetype = p_MOVETYPE_STEP;
	if (!self.p_health) self.p_health = 75;
	
	setmodel (self, "progs/sentinel_monster.mdl");
	setsize (self, '-16 -16 -24', '16 16 40');
	
	self.p_th_stand= sent_stand;
	self.p_th_walk= sent_walk;
	self.p_th_run= sent_run;
	self.p_th_missile= sent_attack;
	self.p_th_pain = sent_pain;
	self.p_th_die= sent_die;
	if (patch_checkfield(op_th_checkattack))
	{
		self.op_th_checkattack = sent_check_attack;
	}
	
	pfn_flymonster_start();
};

void() patchspawn_monster_army =
{
	if (random()<0.5)
	{
		self.p_classname = "monster_sentinel";
		monster_sentinel();
	}
	else
	{
		pfn_monster_army();
	}
};
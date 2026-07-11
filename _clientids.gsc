#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include common_scripts\utility;

init()
{
    level thread on_player_connect();
}

on_player_connect()
{
    for(;;)
    {
        level waittill("connected", player);
        if(player isHost()) player thread on_player_spawned();
    }
}

on_player_spawned()
{
    self endon("disconnect");
    self thread monitor_coordinates(); // Coordinate Capture (D-Pad Left)
    
    wait(5.0); 
    level thread initialize_bot_system(self);
}

// ==========================================
// 1. MAP MEMORY & INITIALIZATION
// ==========================================

initialize_map_memory()
{
    level.ee_memory = [];
    map = getdvar("mapname");

    // Add your EE coordinates here using the Coordinate Capture Tool
    // Example: level.ee_memory["step_name"].bot_spots[0] = (X, Y, Z);
    
    iprintln("Map Intel: " + map + " memory loaded.");
}

initialize_bot_system(host)
{
    if(isDefined(level.bot_system_active)) return;
    level.bot_system_active = true;
    
    level initialize_map_memory();
    host thread monitor_player_pings();
    
    for(i = 0; i < 3; i++)
    {
        level thread spawn_bot(host, i);
        wait(1.0);
    }
}

spawn_bot(host, id)
{
    bot = addtestclient();
    if(!isDefined(bot)) return;
    
    bot.is_bot = true;
    bot.bot_id = id;
    bot waittill("spawned_player");
    
    bot setorigin(host.origin + (id*50, 50, 0));
    bot giveWeapon("m1911_zm");
    bot switchToWeapon("m1911_zm");
    
    bot thread bot_loop(host);
}

// ==========================================
// 2. THE BOT BRAIN
// ==========================================

bot_loop(host)
{
    self endon("disconnect");
    self thread bot_scaling_system();
    
    while(true)
    {
        if(isDefined(host.revivetrigger)) { self move_towards(host.origin); self execute_revive(host); }
        else if(isDefined(self.active_pos)) 
        {
            self.health = 99999; self.ignoreme = true; // EE Invincibility
            self move_towards(self.active_pos);
        }
        else 
        {
            self.ignoreme = false;
            self check_for_combat();
            self bot_perk_manager();
            if(distance(self.origin, host.origin) > 300) self move_towards(host.origin);
        }
        wait(0.1);
    }
}

bot_scaling_system()
{
    while(true)
    {
        level waittill("between_round_over");
        round = level.round_number;
        self.maxhealth = 100 + (round * 5);
        self.damage_multiplier = 1.0 + (round * 0.02);
    }
}

check_for_combat()
{
    zombies = getaiarray(level.zombie_team);
    foreach(z in zombies)
    {
        if(distance(self.origin, z.origin) < 1000)
        {
            self setplayerangles(vectorToAngles(z.origin - self getEye()));
            self pressattackbutton();
            return;
        }
    }
}

bot_perk_manager()
{
    perks = getentarray("zm_perk_machine", "targetname");
    foreach(m in perks)
    {
        if(distance(self.origin, m.origin) < 64 && self.score >= 2500 && !self hasperk(m.script_noteworthy))
        {
            m notify("trigger", self);
            self.score -= 2500;
        }
    }
}

// ==========================================
// 3. UTILITY (Ping, Coords, Helpers)
// ==========================================

monitor_coordinates()
{
    while(true)
    {
        if(self actionslotthreebuttonpressed()) // Left
        {
            pos = self.origin;
            self iprintlnbold("X: " + pos[0] + " Y: " + pos[1] + " Z: " + pos[2]);
            wait(2.0);
        }
        wait(0.1);
    }
}

monitor_player_pings()
{
    while(true)
    {
        if(self actionslotonebuttonpressed()) // Up
        {
            trace = bullettrace(self getEye(), anglesToForward(self getPlayerAngles()) * 5000, true, self);
            macro = false;
            keys = getArrayKeys(level.ee_memory);
            foreach(k in keys)
            {
                if(distance(trace["position"], level.ee_memory[k].ping_target_pos) < 100)
                {
                    level notify("ee_macro", k);
                    macro = true;
                }
            }
            if(!macro) level notify("single_ping", trace["position"]);
        }
        if(self actionslottwobuttonpressed()) level notify("recall"); // Down
        wait(0.1);
    }
}

move_towards(pos) { self setorigin(self.origin + vectorNormalize(pos - self.origin) * 5); }
execute_revive(h) { if(distance(self.origin, h.origin) < 64) h.revivetrigger notify("trigger", self); }

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <reapi>
#include <cstrike>
#include <fakemeta>
#include <nvault_array>
#include <fun>
#include <sockets>

new bool:g_bActivateClanWarMode = false;

new bool:g_bIsPaused = false;

new g_iPauseNum = 4;

new g_iGameStage = 0;

new g_iPauseTime = 0;

new g_msgScoreInfo = 0;
new g_msgServerName = 0;

new g_iServerPassword = 0;
new g_Round = 0;

new g_iNoUsersWarn = 0;

new g_iPauseInitializer = 0;

new g_bClanWarModeEnding = false;

new g_pcvar_mp_c4timer = 0;

new g_iVault = 0;

new g_iUserCW = 0;

enum _:cwData
{
    KILLS,
    DEATHS,
    PASSWORD,
	AUTHID[MAX_AUTHID_LENGTH]
} new g_ClanWarData[MAX_PLAYERS+1][cwData];


new bool:g_bTerroristWinners = false;

new g_iVotesTT = 0;
new g_iVotesCT = 0;

new g_iOverTimeLastRound = 0;

new bool:g_bSwappedWinners = true;

new g_iGameNum = 0;

new g_iWins_CT = 0;
new g_iWins_TT = 0;

new g_iOverTimes = 0;

new g_iWarmupMinutes = 5;

new bool:g_bNeed1000Money = false;

new bool:g_bHLTVWARN = true;


#define WARMUP_TASK 10001

// Квары

new cw_servername[256];
new cw_hltv_rcon[256];

new cw_startup_config[256];
new cw_warmup_config[256];
new cw_knife_config[256];
new cw_game_config[256];

new cw_hltv_autorecord;
new cw_pov_autorecord;
new cw_norm_rounds;
new cw_norm_winner;
new cw_over_rounds;
new cw_over_money;
new cw_over_winlimit;
new cw_rate_settings;
new cw_knife_round;
new cw_warmup_time;
new cw_dhud_enable;
new cw_pause_enable;


public plugin_init()
{
	register_plugin("UNREAL WAR MODE", "1.7", "Karaulov");

	create_cvar("unreal_war", "1.7", (FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED));

	register_clcmd("cw_mode_menu", "give_me_cw_menu")
	register_clcmd("cw_menu", "give_me_cw_menu")

	register_clcmd("say cw_menu", "give_me_cw_menu")
	register_clcmd("say /cw_menu", "give_me_cw_menu")

	register_concmd("say !pause", "cw_mode_saypause");
	register_concmd("say_team !pause", "cw_mode_saypause");

	register_concmd("say /pause", "cw_mode_saypause");
	register_concmd("say_team /pause", "cw_mode_saypause");

	g_msgScoreInfo = get_user_msgid("ScoreInfo")
	g_msgServerName = get_user_msgid("ServerName")

	RegisterHookChain(RG_RoundEnd, "CS_RoundEnd",  .post = false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn",  .post = true);
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem", .post = false);
	RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "CBasePlayer_HasRestrictItem", .post = false);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", .post = true);
	RegisterHookChain(RG_PlantBomb, "CS_PlantBomb",  .post = true)
	RegisterHookChain(RG_CGrenade_DefuseBombStart, "CGrenade_DefuseBombStart",  .post = true);

	g_pcvar_mp_c4timer = get_cvar_pointer("mp_c4timer");

	set_task_ex(3.5, "cw_mode_update_gameinfo", .flags = SetTask_Repeat);
	set_task_ex(1.0, "cw_mode_watcher", .flags = SetTask_Repeat);

	g_iVault = nvault_open("clanwar_data")

	if (g_iVault == INVALID_HANDLE)
	{
		set_fail_state( "Error opening nVault clanwar_data" );
	}
	else 
	{
		nvault_prune( g_iVault , 0 , get_systime() );
	}
	
	cw_mode_setup_cvars();
}

public cw_mode_setup_cvars()
{
	bind_pcvar_string(create_cvar("cw_servername", "SERVERNAME",
					.description = "Select server name."
	),	cw_servername, charsmax(cw_servername));

	bind_pcvar_string(create_cvar("cw_hltv_rcon", "hltv_rcon",
					.description = "Select hltv rcon password."
	),	cw_hltv_rcon, charsmax(cw_hltv_rcon));
	
	bind_pcvar_string(create_cvar("cw_startup_config", "startup.cfg",
					.description = "Select startup.cfg"
	),	cw_startup_config, charsmax(cw_startup_config));
	
	bind_pcvar_string(create_cvar("cw_warmup_config", "warmup.cfg",
					.description = "Select warmup.cfg"
	),	cw_warmup_config, charsmax(cw_warmup_config));
	
	bind_pcvar_string(create_cvar("cw_knife_config", "knife.cfg",
					.description = "Select knife.cfg"
	),	cw_knife_config, charsmax(cw_knife_config));
	
	bind_pcvar_string(create_cvar("cw_game_config", "game.cfg",
					.description = "Select game.cfg"
	),	cw_game_config, charsmax(cw_game_config));
	
	
	bind_pcvar_num(create_cvar("cw_hltv_autorecord", "1",
					.description = "HLTV auto record demos"
	),	cw_hltv_autorecord);
	
	bind_pcvar_num(create_cvar("cw_pov_autorecord", "1",
					.description = "POV auto record demos"
	),	cw_pov_autorecord);
	
	bind_pcvar_num(create_cvar("cw_norm_rounds", "15",
					.description = "Count of rounds in part game"
	),	cw_norm_rounds);
	
	bind_pcvar_num(create_cvar("cw_norm_winner", "15",
					.description = "Count of wins to end game"
	),	cw_norm_winner);
	
	bind_pcvar_num(create_cvar("cw_over_rounds", "3",
					.description = "Count of rounds in overtime game"
	),	cw_over_rounds);
	
	bind_pcvar_num(create_cvar("cw_over_money", "10000",
					.description = "Money for overtimes"
	),	cw_over_money);
	
	bind_pcvar_num(create_cvar("cw_over_winlimit", "3",
					.description = "Limit to win score in overtimes"
	),	cw_over_winlimit);
	
	bind_pcvar_num(create_cvar("cw_rate_settings", "2",
					.description = "Setup rates"
	),	cw_rate_settings);
	
	bind_pcvar_num(create_cvar("cw_knife_round", "1",
					.description = "Enable knife round"
	),	cw_knife_round);
	
	bind_pcvar_num(create_cvar("cw_warmup_time", "5",
					.description = "Warmup minutes"
	),	cw_warmup_time);
	
	bind_pcvar_num(create_cvar("cw_dhud_enable", "1",
					.description = "Use DHUD instead of HUD(ReHLTV requeired)"
	),	cw_dhud_enable);
	
	bind_pcvar_num(create_cvar("cw_pause_enable", "1",
					.description = "Allow use pauses"
	),	cw_pause_enable);
	
	new g_sConfigDirPath[256];
	get_configsdir(g_sConfigDirPath, charsmax(g_sConfigDirPath));
	server_cmd("exec %s/unreal_war/unreal_war.cfg", g_sConfigDirPath);
	
	server_cmd("exec %s/unreal_war/%s", g_sConfigDirPath,cw_startup_config);
	server_exec();
	
	cw_mode_setup_rates(cw_rate_settings);
}

public cw_mode_setup_rates(id)
{
	if (id == 2)
	{
		server_cmd("sv_minrate 75000");
		server_cmd("sv_maxrate 100000");
		server_cmd("sv_minupdaterate 100");
		server_cmd("sv_minupdaterate 102");
	}
	else if (id == 3)
	{
		server_cmd("sv_minrate 40000");
		server_cmd("sv_maxrate 100000");
		server_cmd("sv_minupdaterate 40");
		server_cmd("sv_minupdaterate 90");
	}
	else if (id == 4)
	{
		server_cmd("sv_minrate 15000");
		server_cmd("sv_maxrate 100000");
		server_cmd("sv_minupdaterate 30");
		server_cmd("sv_minupdaterate 60");
	}
	else
	{
		server_cmd("sv_minrate 25000");
		server_cmd("sv_maxrate 100000");
		server_cmd("sv_minupdaterate 30");
		server_cmd("sv_minupdaterate 102");
	}
}

public plugin_end()
{
	if (g_iVault != INVALID_HANDLE)
	{
		nvault_close(g_iVault);
	}
}

public bool:is_cw_mode_active()
{
	return  g_bActivateClanWarMode && !g_bClanWarModeEnding;
}

public bool:is_game_started()
{
	return g_iGameStage == 0 && is_cw_mode_active();
}

public bool:is_any_hltv_found()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "c");
	for(new i = 0; i < mCount;i++)
	{
		if (is_user_hltv(mPlayers[i]))
			return true;
	}
	return false;
}

public give_me_cw_menu(id)
{
	if (get_user_flags(id) & ADMIN_BAN)
	{
		new tmpmenuitem[256];
		formatex(tmpmenuitem, charsmax(tmpmenuitem), "\r[%s]=[\wCW MENU\r]",cw_servername);

		new vmenu = menu_create(tmpmenuitem, "CW_MENU_HANDLER");
		
		menu_additem(vmenu, "Запустить CW", "1");
		menu_addblank(vmenu, 0);
		menu_additem(vmenu, "Пропуск разминки", "2");
		menu_addblank(vmenu, 0);
		menu_additem(vmenu, "Рестарт текущего раунда", "17");
		menu_additem(vmenu, "Перезапуск карты", "3");
		menu_additem(vmenu, "Перезапуск сервера", "4");
		menu_addblank(vmenu, 0);
		menu_addblank(vmenu, 0);
		menu_additem(vmenu, "Выбрать de_dust2", "5");
		menu_additem(vmenu, "Выбрать de_inferno", "6");
		menu_additem(vmenu, "Выбрать de_mirage", "7");
		menu_additem(vmenu, "Выбрать de_aztec", "8");
		menu_additem(vmenu, "Выбрать de_train", "9");
		menu_additem(vmenu, "Выбрать de_nuke", "10");
		menu_additem(vmenu, "Выбрать de_tuscan", "11");
		menu_addblank(vmenu, 0);
		menu_additem(vmenu, "DE_BOX - ТЕСТОВАЯ КАРТА", "12");
		
		menu_setprop(vmenu, MPROP_EXITNAME, "\rВыйти из \w[\rCLAN WAR\w] меню");
		menu_setprop(vmenu, MPROP_EXIT, MEXIT_ALL);

		menu_display(id, vmenu, 0);
	}
}
public CW_MENU_HANDLER(id, vmenu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id) || !(get_user_flags(id) & ADMIN_BAN))
	{
		menu_destroy(vmenu);
		return PLUGIN_HANDLED;
	}

	new data[6], iName[64], acc, callback;
	menu_item_getinfo(vmenu, item, acc, data, 5, iName, 63, callback);

	new key = str_to_num(data);
	new username[33];
	get_user_name(id,username,charsmax(username));
	log_to_file("cw_mode.txt","User %s set key:%s to %d",username, data,key);
	
	switch (key)
	{
		case 1:
		{
			if (g_bHLTVWARN && !is_any_hltv_found())
			{
				g_bHLTVWARN = false;
				client_print_color(0, print_team_red, "^4[%s]^3 Вы пытаетесь запустить CW без HLTV!!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Вы пытаетесь запустить CW без HLTV!!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Вы пытаетесь запустить CW без HLTV????",cw_servername);
			}
			else 
				cw_mode_say_initialize(id);
				
		}
		case 2:
		{
			cw_mode_stop_warmup(id);
		}
		case 3:
		{
			cw_mode_map_restart(id);
		}
		case 4:
		{
			cw_mode_server_restart(id);
		}
		case 5:
		{
			server_cmd("changelevel de_dust2")
		}
		case 6:
		{
			server_cmd("changelevel de_inferno")
		}
		case 7:
		{
			server_cmd("changelevel de_mirage")
		}
		case 8:
		{
			server_cmd("changelevel de_aztec")
		}
		case 9:
		{
			server_cmd("changelevel de_train")
		}
		case 10:
		{
			server_cmd("changelevel de_nuke")
		}
		case 11:
		{
			server_cmd("changelevel de_tuscan")
		}
		case 12:
		{
			server_cmd("changelevel de_box")
		}
		case 17:
		{
			server_cmd("sv_restartround 1");
		}
	}

	menu_destroy(vmenu);
	return PLUGIN_HANDLED;
}


new Float:c4PlantTime = 0.0;

public CS_PlantBomb(const index, Float:vecStart[3], Float:vecVelocity[3])
{
	if (is_cw_mode_active())
	{
		c4PlantTime = get_gametime() + get_pcvar_num( g_pcvar_mp_c4timer );
		if (is_user_connected(index))
		{
			new usernam[33];
			get_user_name(index,usernam,charsmax(usernam));
			new message[256];
			new mPlayers[32];
			new mCount;
			get_players(mPlayers, mCount, "c");
			for(new i = 0; i < mCount;i++)
			{
				if (is_user_hltv(mPlayers[i]))
				{
					formatex(message,charsmax(message),"Игрок %s установил бомбу!",usernam);
					set_hudmessage(0, 50, 200, -1.0, 0.35, 0, 0.1, 3.5, 0.02, 0.02, 2);
					show_hudmessage(mPlayers[i], "%s",message);
				}
			}
		}
	}
}

public CGrenade_DefuseBombStart(const ent, const id)
{
	if (is_cw_mode_active())
	{
		if (is_user_connected(id))
		{
			new Float:c4DefTime = get_gametime() + (get_member(id, m_bHasDefuser) ? 5.0 : 10.0);
			if ( c4DefTime > c4PlantTime )
			{
				new usernam[33];
				get_user_name(id,usernam,charsmax(usernam));
				new message[256];
				new mPlayers[32];
				new mCount;
				get_players(mPlayers, mCount, "c");
				for(new i = 0; i < mCount;i++)
				{
					if (is_user_hltv(mPlayers[i]))
					{
						formatex(message,charsmax(message),"Игрок %s не успеет разминировать бомбу!",usernam);
						set_hudmessage(0, 50, 200, -1.0, 0.35, 0, 0.1, 3.5, 0.02, 0.02, 2);
						show_hudmessage(mPlayers[i], "%s",message);
					}
				}
			}
			else 
			{
				new usernam[33];
				get_user_name(id,usernam,charsmax(usernam));
				new message[256];
				new mPlayers[32];
				new mCount;
				get_players(mPlayers, mCount, "c");
				for(new i = 0; i < mCount;i++)
				{
					if (is_user_hltv(mPlayers[i]))
					{
						formatex(message,charsmax(message),"Игрок %s возможно сумеет разминировать бомбу!",usernam);
						set_hudmessage(0, 50, 200, -1.0, 0.35, 0, 0.1, 3.5, 0.02, 0.02, 2);
						show_hudmessage(mPlayers[i], "%s",message);
					}
				}
			}
		}
	}
}

public CBasePlayer_AddPlayerItem(id, pItem)
{
	if(!is_valid_ent(pItem) || !is_cw_mode_active())
	{
		return HC_CONTINUE;
	}
	if ( g_iGameStage == 2 && get_member(pItem, m_iId) != WEAPON_KNIFE)
	{
		SetHookChainReturn(ATYPE_INTEGER, 0);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public CBasePlayer_HasRestrictItem(const id, const ItemID:item, const ItemRestType:type)
{
    if (is_cw_mode_active() && (item == ITEM_SG550 || item == ITEM_G3SG1 || item == ITEM_SHIELDGUN))
    {
        if (type == ITEM_TYPE_BUYING) {
            client_print(id, print_center, "* This item is restricted *");
        }
        SetHookChainReturn(ATYPE_BOOL, true);
        return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

public cw_mode_update_gameinfo(id)
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "c");
	for(new i = 0; i < mCount;i++)
	{
		new message[33];
		if (g_iGameStage == 1)
		{
			formatex(message,charsmax(message),"[CW] GAME: [WARMUP %d MIN]", g_iWarmupMinutes + 1);
		}
		else if (g_iGameStage == 2)
		{
			formatex(message,charsmax(message),"[CW] GAME: [%s]","KNIFE ROUND");
		}
		else if (g_iGameStage == 3)
		{
			formatex(message,charsmax(message),"[CW] GAME: [%s]","CHOOSE TEAM");
		}
		else if (!g_bActivateClanWarMode)
		{
			formatex(message,charsmax(message),"[CW] GAME: [%s]","WAITING FOR CW");
		}
		else
		{
			formatex(message,charsmax(message),"[CW] GAME: [%d] SCORE: [%d:%d]",g_iGameNum + 1 + g_iOverTimes, g_iWins_CT, g_iWins_TT)
		}
		
		if (g_bActivateClanWarMode)
			msg_servername(mPlayers[i], message );
		
		if (is_user_hltv(mPlayers[i]))
		{
			xset_dhudmessage(255, 255, 30, 0.565, 0.935, 0, 0.0, 5.07, 0.0, 0.0);
			xshow_dhudmessage(mPlayers[i], message);
		}
	}
}

public cw_mode_game_knife_round()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 10.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Раунд на ножах! За выбор команды!!");
}

public cw_mode_game_happy()
{
	xset_dhudmessage(100, 150, 255, -1.0, 0.45, 0, 0.0, 3.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Удачной вам игры!");
}

public CBasePlayer_Spawn(const id) 
{
	if ( !is_cw_mode_active() || !is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	
	if (g_bNeed1000Money)
		rg_add_account(id, cw_over_money, AS_SET);
		
	if (g_iGameStage == 1)
		rg_add_account(id, 16000, AS_SET);
		
	UpdateScore(id, g_ClanWarData[id][KILLS], g_ClanWarData[id][DEATHS]);
	
	rg_set_user_rendering(id);
	set_entity_visibility(id,1)
	set_user_rendering(id, kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

public cw_mode_clear_all_stats()
{
	for(new i = 0; i <= MAX_PLAYERS;i++)
	{
		g_ClanWarData[i][KILLS] = 0;
		g_ClanWarData[i][DEATHS] = 0;
	}
	
	nvault_prune( g_iVault , 0 , get_systime() );
}

public cw_mode_stop_warmup(id)
{
	if (get_user_flags(id) & ADMIN_BAN)
	{
		cw_warmup_time_end(0);
		cw_mode_clear_all_stats();
		//log_to_file("cw_mode.txt","Reset all stats");
	}
}

public CBasePlayer_Killed(iVictim, iAttacker, iGib)
{
	if (is_cw_mode_active())
	{
		if (is_user_connected(iVictim) && is_user_connected(iAttacker))
		{
			g_ClanWarData[iVictim][DEATHS]++;
			if (iAttacker != iVictim)
			{
				if (get_member(iVictim, m_iTeam) == get_member(iAttacker, m_iTeam))
				{
					g_ClanWarData[iAttacker][DEATHS]++;
				}
				else 
				{
					g_ClanWarData[iAttacker][KILLS]++;
				}
			}
		}
	}
}

public swap_wins2()
{
	g_bSwappedWinners = !g_bSwappedWinners;
}

public cw_mode_show_message_no_change_team()
{
	xset_dhudmessage(255, 150, 0, -1.0, 0.25, 0, 0.0, 5.5, 0.0, 0.0);
	xshow_dhudmessage(0, "Победители не меняют команду!");
}

public cw_mode_show_message_change_team()
{
	xset_dhudmessage(255, 150, 0, -1.0, 0.25, 0, 0.0, 5.5, 0.0, 0.0);
	xshow_dhudmessage(0, "Победители сменили команду!");
}

public cw_mode_show_message_no_choose_team()
{
	xset_dhudmessage(255, 150, 0, -1.0, 0.25, 0, 0.0, 5.5, 0.0, 0.0);
	xshow_dhudmessage(0, "Победители не выбрали команду!");
}

public cw_mode_show_message_vote_end()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.35, 0, 0.0, 7.5, 0.0, 0.0);
	xshow_dhudmessage(0, "Голосование за выбор команды завершено!");
}

public cw_mode_show_message_vote_start()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.35, 0, 0.0, 22.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Запущено голосование за выбор команды!");
}

public cw_mode_show_message_start_choose_team()
{
	xset_dhudmessage(255, 150, 0, -1.0, 0.25, 0, 0.0, 20.5, 0.0, 0.0);
	xshow_dhudmessage(0, "У победителей 30 сек для выбора команды!");
}

public cw_mode_vote_post(id)
{
	if (g_iVotesTT > g_iVotesCT)
	{
		if (g_bTerroristWinners)
		{
			set_task_ex(1.5,"cw_mode_show_message_vote_end");
			set_task_ex(2.5,"cw_mode_show_message_no_change_team");
		}
		else 
		{
			server_cmd("swapteams");
			server_exec();
			swap_wins2();
			set_task_ex(1.5,"cw_mode_show_message_vote_end");
			set_task_ex(2.5,"cw_mode_show_message_change_team");
		}
	}
	else if (g_iVotesCT > g_iVotesTT)
	{
		if (!g_bTerroristWinners)
		{
			set_task_ex(1.5,"cw_mode_show_message_vote_end");
			set_task_ex(2.5,"cw_mode_show_message_no_change_team");
		}
		else 
		{
			server_cmd("swapteams");
			server_exec();
			swap_wins2();
			set_task_ex(1.5,"cw_mode_show_message_vote_end");
			set_task_ex(2.5,"cw_mode_show_message_change_team");
		}
	}
	else if (g_iVotesCT == g_iVotesTT && g_iVotesTT > 0)
	{
		set_task_ex(1.5,"cw_mode_show_message_vote_end");
		set_task_ex(2.5,"cw_mode_show_message_no_choose_team");
	}
	else 
	{
		set_task_ex(1.5,"cw_mode_show_message_vote_end");
		set_task_ex(2.5,"cw_mode_show_message_no_change_team");
	}
	
	set_task_ex(5.5,"cw_mode_game_happy");
	set_task_ex(8.0,"cw_mode_game_happy");
	set_task_ex(10.5,"cw_mode_game_happy");
	
	set_task_ex(10.0,"cw_mode_restartround");
	set_task_ex(11.0,"cw_mode_restartround");
	set_task_ex(12.0,"cw_mode_restartround");
	
	cw_mode_init_game();
}

public cw_mode_init_game()
{
	g_iGameStage = 0;
	cw_mode_clear_all_stats();
	
	new g_sConfigDirPath[256];
	get_configsdir(g_sConfigDirPath, charsmax(g_sConfigDirPath));
	server_cmd("exec %s/unreal_war/%s",g_sConfigDirPath, cw_game_config);
	server_exec();
}

public CW_TEAMMENU_HANDLER(id, vmenu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(vmenu);
		return PLUGIN_HANDLED;
	}

	new data[6], iName[64], acc, callback;
	menu_item_getinfo(vmenu, item, acc, data, 5, iName, 63, callback);

	new key = str_to_num(data)
	switch (key)
	{
		case 1:
		{
			g_iVotesCT++;
		}
		case 2:
		{
			g_iVotesTT++;
		}
	}

	menu_destroy(vmenu);
	return PLUGIN_HANDLED;
}


public cw_mode_winner_is_ct()
{
	new buffer[128];
	formatex(buffer,charsmax(buffer),"Counter-Terrorist'ы победили в игре №%d",g_iGameNum);
	xset_dhudmessage(0, 150, 240, -1.0, 0.25, 0, 0.0, 6.0, 0.0, 0.0);
	xshow_dhudmessage(0, buffer);
}

public cw_mode_winner_is_tt()
{
	new buffer[128];
	formatex(buffer,charsmax(buffer),"Terrorist'ы победили в игре №%d",g_iGameNum);
	xset_dhudmessage(240, 150, 0, -1.0, 0.25, 0, 0.0, 6.0, 0.0, 0.0);
	xshow_dhudmessage(0, buffer);
}

public cw_mode_game_over_start()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 7.5, 0.0, 0.0);
	xshow_dhudmessage(0, "Игра завершена! Поздравляем победителей!");
}

public cw_mode_game_over_end()
{
	xset_dhudmessage(255, 55, 55, -1.0, 0.65, 0, 0.0, 60.0, 0.0, 0.0);
	xshow_dhudmessage(0, "КОНЕЦ ИГРЫ!");
}

public cw_mode_game_overtime()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 5.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Командам дается три дополнительных раунда!");
}

public cw_mode_game_overtime2()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 5.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Ничья! Три дополнительных раунда!");
}

public cw_mode_game_alert()
{
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 5.0, 0.0, 0.0);
	xshow_dhudmessage(0, "ВНИМАНИЕ!");
}

public cw_mode_game_lastround()
{
	xset_dhudmessage(240, 120, 0, -1.0, 0.40, 0, 0.0, 4.0, 0.0, 0.0);
	xshow_dhudmessage(0, "РЕШАЮЩИЙ РАУНД!");
}

public cw_menu_vote_team_tt()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "ehc", "TERRORIST");
	for(new i = 0; i < mCount;i++)
	{
		new id = mPlayers[i];
		new tmpmenuitem[256];
		formatex(tmpmenuitem, charsmax(tmpmenuitem), "\r[%s]=[\wSELECT TEAM\r]",cw_servername);

		new vmenu = menu_create(tmpmenuitem, "CW_TEAMMENU_HANDLER");
		
		menu_additem(vmenu, "Выбрать CT", "1");
		menu_addblank(vmenu,0);
		menu_additem(vmenu, "Выбрать TT", "2");
		menu_addblank(vmenu,0);
		menu_additem(vmenu, "Не выбирать", "3");
		
		menu_setprop(vmenu, MPROP_EXITNAME, "\rВыйти из \w[\rSELECT TEAM\w] меню");
		menu_setprop(vmenu, MPROP_EXIT, MEXIT_ALL);

		menu_display(id, vmenu, 0);
	}
}

public cw_menu_vote_team_ct()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "ehc", "CT");
	for(new i = 0; i < mCount;i++)
	{
		new id = mPlayers[i];
		new tmpmenuitem[256];
		formatex(tmpmenuitem, charsmax(tmpmenuitem), "\r[%s]=[\wSELECT TEAM\r]",cw_servername);

		new vmenu = menu_create(tmpmenuitem, "CW_TEAMMENU_HANDLER");
		
		menu_additem(vmenu, "Выбрать CT", "1");
		menu_addblank(vmenu,0);
		menu_additem(vmenu, "Выбрать TT", "2");
		menu_addblank(vmenu,0);
		menu_additem(vmenu, "Не выбирать", "3");
		
		menu_setprop(vmenu, MPROP_EXITNAME, "\rВыйти из \w[\rSELECT TEAM\w] меню");
		menu_setprop(vmenu, MPROP_EXIT, MEXIT_ALL);

		menu_display(id, vmenu, 0);
	}
}



public CS_RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{  
	if (status == WINSTATUS_NONE || event == ROUND_GAME_COMMENCE
		|| event == ROUND_GAME_RESTART || !is_cw_mode_active())
	{
		return;
	}
	
	if (g_iGameStage == 2)
	{
		cw_mode_clear_all_stats();
		g_iGameStage = 3;
		server_cmd("mp_freezetime 300");
		if (status == WINSTATUS_TERRORISTS)
		{
			g_bTerroristWinners = true;
			set_task_ex(5.5,"cw_menu_vote_team_tt");
		}
		else if (status == WINSTATUS_CTS || status == WINSTATUS_DRAW)
		{
			set_task_ex(5.5,"cw_menu_vote_team_ct");
		}
		
		cw_mode_show_message_vote_start();
		set_task_ex(1.5,"cw_mode_show_message_start_choose_team");
		
		set_task_ex(5.5,"cw_mode_show_message_vote_start");
		set_task_ex(7.0,"cw_mode_show_message_start_choose_team");
		
		set_task_ex(30.0, "cw_mode_vote_post");
	}
	else if (is_game_started())
	{
		set_task_ex(3.0,"cw_update_teamscores");
		set_task_ex(10.0,"cw_update_teamscores");
		
		g_Round++;
		if (g_bIsPaused)
		{
			server_cmd("mp_freezetime 130");
			g_iPauseNum--;
			g_iPauseTime = 65;
			g_bIsPaused = false;
		}
		else 
		{
			server_cmd("mp_freezetime 10");
		}
		if (is_cw_mode_active())
		{
			if (status == WINSTATUS_TERRORISTS)
			{
				g_bNeed1000Money = false;
				if (g_bSwappedWinners)
					g_iWins_TT++;
				else 
					g_iWins_CT++;
			}
			else if (status == WINSTATUS_CTS || status == WINSTATUS_DRAW)
			{
				g_bNeed1000Money = false;
				if (g_bSwappedWinners)
					g_iWins_CT++;
				else 
					g_iWins_TT++;
			}
		}
		if (g_Round == cw_norm_rounds)
		{
			g_iGameNum++;
			// Часть функционала не используется
			if (g_bSwappedWinners)
			{
				if (g_iWins_CT > g_iWins_TT)
				{
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					
					set_task_ex(1.0, "cw_mode_winner_is_ct");
				}
				else
				{
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					
					set_task_ex(1.0, "cw_mode_winner_is_tt");
				}
			}
			else 
			{
				if (g_iWins_TT > g_iWins_CT)
				{
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_blue, "^4[%s]^1 В ^4%d^1 игре победили ^3Counter-Terrorist'ы",cw_servername,g_iGameNum);
					
					set_task_ex(1.0, "cw_mode_winner_is_ct");
				}
				else
				{
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					client_print_color(0, print_team_red, "^4[%s]^1 В ^4%d^1 игре победили ^3Terrorist'ы",cw_servername,g_iGameNum);
					
					set_task_ex(1.0, "cw_mode_winner_is_tt");
				}
			}
			
			server_cmd("swapteams");
			server_exec();
			cw_mode_multirestart();
			swap_wins2();
		}
		else if (g_iOverTimeLastRound > 0)
		{
			if (g_Round - g_iOverTimeLastRound >= cw_over_rounds)
			{
				// Прошли раунды за две стороны и есть разница в победах
				if (g_iOverTimes % 2 == 0 && abs(g_iWins_TT - g_iWins_CT) > 0)
				{
					client_print_color(0, print_team_red, "^4[%s]^3 Игра завершена, победитель найден!!!",cw_servername);
					client_print_color(0, print_team_red, "^4[%s]^3 Игра завершится через 60 секун!!!!",cw_servername);
					
					set_task_ex(1.0,"cw_mode_game_over_start");
					set_task_ex(5.0,"cw_mode_game_over_end");
	

					set_task_ex(60.0,"cw_kick_players_game_end")
					set_task_ex(65.0,"cw_kick_players_game_end")
					
					g_bClanWarModeEnding = true;
				}
				else 
				{
					g_iOverTimes++;
					g_iOverTimeLastRound = g_Round;
				
					server_cmd("swapteams");
					server_exec();
					swap_wins2();
					g_iGameNum++;
					
					if (cw_over_money != 0)
						g_bNeed1000Money = true;
					
					client_print_color(0, print_team_red, "^4[%s]^3 Дополнительные 3 раунда! Смена сторон!",cw_servername);
					client_print_color(0, print_team_red, "^4[%s]^3 Дополнительные 3 раунда! Смена сторон!",cw_servername);
					
					set_task_ex(1.5,"cw_mode_game_overtime");
				}
			}
			if (g_iWins_TT - g_iWins_CT > cw_over_winlimit || g_iWins_CT - g_iWins_TT > cw_over_winlimit)
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершена, победитель найден!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершится через 60 секун!!!!",cw_servername);
				
				set_task_ex(1.0,"cw_mode_game_over_start");

				set_task_ex(5.0,"cw_mode_game_over_end");


				set_task_ex(60.0,"cw_kick_players_game_end")
				set_task_ex(65.0,"cw_kick_players_game_end")
				
				g_bClanWarModeEnding = true;
			}
			else if (g_iWins_TT - g_iWins_CT > cw_over_winlimit - 1 || g_iWins_CT - g_iWins_TT > cw_over_winlimit - 1)
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				
				cw_mode_game_alert();
				set_task_ex(1.5,"cw_mode_game_lastround");
			}
			else if (g_iOverTimes % 2 == 0 && (g_iWins_TT - g_iWins_CT > 2 || g_iWins_CT - g_iWins_TT > 2) && (g_Round - g_iOverTimeLastRound > cw_over_rounds - 1))
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				
				cw_mode_game_alert();
				set_task_ex(1.5,"cw_mode_game_lastround");
			}
		}
		else if (g_Round > cw_norm_winner)
		{
			if (g_iWins_TT > cw_norm_winner && g_iWins_TT > g_iWins_CT)
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершена, победитель найден!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершится через 60 секун!!!!",cw_servername);
				
			
				set_task_ex(1.0,"cw_mode_game_over_start");

				set_task_ex(5.0,"cw_mode_game_over_end");


				g_bClanWarModeEnding = true;
				set_task_ex(60.0,"cw_kick_players_game_end")
				set_task_ex(65.0,"cw_kick_players_game_end")
			}
			else if (g_iWins_CT > cw_norm_winner && g_iWins_CT > g_iWins_TT)
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершена, победитель найден!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Игра завершится через 60 секун!!!!",cw_servername);
		
				set_task_ex(1.0,"cw_mode_game_over_start");

				set_task_ex(5.0,"cw_mode_game_over_end");


				g_bClanWarModeEnding = true;
				set_task_ex(60.0,"cw_kick_players_game_end")
				set_task_ex(65.0,"cw_kick_players_game_end")
			}
			else if (g_iWins_TT == cw_norm_winner && g_iWins_CT == cw_norm_winner)
			{		
				if (cw_over_money != 0)
					g_bNeed1000Money = true;
					
				server_cmd("sv_restart 1");
				client_print_color(0, print_team_red, "^4[%s]^3 Ничья! Дополнительные 3 раунда!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Ничья! Дополнительные 3 раунда!",cw_servername);
			
				set_task_ex(1.5,"cw_mode_game_overtime2");
				
				g_iOverTimeLastRound = g_Round;
				g_iOverTimes++;
			}
			else if (g_iWins_TT == cw_norm_winner || g_iWins_CT == cw_norm_winner)
			{
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				client_print_color(0, print_team_red, "^4[%s]^3 Решающий раунд!!!!",cw_servername);
				
				cw_mode_game_alert();
				set_task_ex(1.5,"cw_mode_game_lastround");
			}
		}
	}
	else 
	{
		
		
	}
} 

public cw_update_teamscores(id)
{
	rg_update_teamscores(g_bSwappedWinners ? g_iWins_CT : g_iWins_TT, g_bSwappedWinners ? g_iWins_TT : g_iWins_CT, false);
}

public cw_mode_saypause(id)
{
	if (g_iPauseNum == 0 || cw_pause_enable <= 0)
	{
		client_print_color(id, print_team_red, "^4[%s]^3 Нет возможности поставить паузу!",cw_servername);
		return;
	}
		
	if (g_bIsPaused || g_iPauseTime > 0)
	{
		client_print_color(id, print_team_red, "^4[%s]^3 Нет возможности поставить паузу, есть активная пауза!",cw_servername);
		return;
	}
	
	if (g_iGameStage != 0)
	{
		client_print_color(id, print_team_red, "^4[%s]^3 Нет возможности поставить паузу, идет разминка!",cw_servername);
		return;
	}
	
	if (!g_bActivateClanWarMode)
	{
		client_print_color(id, print_team_red, "^4[%s]^3 Нет возможности поставить паузу на CSDM режиме!",cw_servername);
		return;
	}
	
	new playername[33];
	get_user_name(id,playername,charsmax(playername));
	client_print_color(0, print_team_red, "^4[%s]^3 Игрок ^1%s^3 поставил на паузу. Осталось: ^1%d^3!",cw_servername,playername,g_iPauseNum / 2);
	g_bIsPaused = true;
	g_iPauseInitializer = id;
	
	set_hudmessage(0, 50, 200, -1.0, 0.13, 0, 0.1, 5.0, 0.02, 0.02, 1);
	show_hudmessage(0, "Игрок %s поставил на паузу. Осталось пауз: %d!",playername,g_iPauseNum / 2);
}

public bool:no_has_any_player()
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount, "hc");
	return mCount == 0;
}

public cw_monitor_no_users()
{
	if (no_has_any_player() && g_bActivateClanWarMode)
	{
		g_iNoUsersWarn++;
		if (g_iNoUsersWarn > 20)
		{
			server_cmd("restart");
		}
	}
	else 
	{
		g_iNoUsersWarn = 0;
	}
}

public cw_mode_watcher(id)
{
	cw_monitor_no_users();

	g_iPauseTime--;
	if (!g_bIsPaused && g_iPauseTime > 0 && g_iPauseInitializer != 0 && (g_iPauseTime % 5) == 0)
	{
		new playername[33];
		get_user_name(g_iPauseInitializer,playername,charsmax(playername));
		
		set_hudmessage(0, 50, 200, -1.0, 0.13, 0, 0.1, 5.0, 0.02, 0.02, 1);
		show_hudmessage(0, "Игрок %s поставил на паузу. Осталось пауз: %d!",playername,g_iPauseNum / 2);

		set_hudmessage(0, 50, 200, -1.0, 0.25, 0, 0.1, 10.0, 0.02, 0.02, 2);
		show_hudmessage(0, "Игрок %s поставил на паузу. Осталось пауз: %d!",playername,g_iPauseNum / 2);

		set_hudmessage(0, 50, 200, -1.0, 0.35, 0, 0.1, 5.0, 0.02, 0.02, 3);
		show_hudmessage(0, "Игрок %s поставил на паузу. Осталось пауз: %d!",playername,g_iPauseNum / 2);
	}
	
	if (g_bClanWarModeEnding)
	{
		set_hudmessage(0, 50, 200, -1.0, 0.13, 0, 0.1, 2.5, 0.02, 0.02, 1);
		show_hudmessage(0, "Игра завершена! Победила команда со счетом [%d/%d]", max(g_iWins_CT,g_iWins_TT),min(g_iWins_CT,g_iWins_TT));
		set_hudmessage(0, 50, 200, -1.0, 0.17, 0, 0.1, 2.5, 0.02, 0.02, 2);
		new winnerslist[1024];
		copy(winnerslist,charsmax(winnerslist),"Список победителей:^n")
		new winner_team[16];
		if (g_iWins_CT > g_iWins_TT)
		{
			if (g_bSwappedWinners)
			{
				copy(winner_team,charsmax(winner_team),"CT")
			}
			else 
			{
				copy(winner_team,charsmax(winner_team),"TERRORIST")
			}
		}
		else 
		{
			if (g_bSwappedWinners)
			{
				copy(winner_team,charsmax(winner_team),"TERRORIST")
			}
			else 
			{
				copy(winner_team,charsmax(winner_team),"CT")
			}
		}
		
		new mPlayers[32];
		new mCount;
		get_players(mPlayers, mCount, "ehc", winner_team);
		for(new i = 0; i < mCount;i++)
		{
			if (is_user_connected(mPlayers[i]))
			{
				new username[33];
				get_user_name(mPlayers[i],username,charsmax(username));
				add(winnerslist,charsmax(winnerslist),username)
				add(winnerslist,charsmax(winnerslist),"^n")
			}
		}
		
		show_hudmessage(0, "%s", winnerslist);
	}
}

public client_disconnected(id)
{
	if (is_user_bot(id) || is_user_hltv(id))
		return;
	nvault_set_array(g_iVault, g_ClanWarData[id][AUTHID], g_ClanWarData[id], sizeof(g_ClanWarData[]));
	g_ClanWarData[id][KILLS] = 0;
	g_ClanWarData[id][DEATHS] = 0;
	g_ClanWarData[id][PASSWORD] = 0;
	g_ClanWarData[id][AUTHID][0] = EOS;
	remove_task(id);
}

public client_putinserver(id)
{  
	new ipaddr[33];
	get_user_ip(id,ipaddr,charsmax(ipaddr));
	log_to_file("cw_mode.txt","JOINADDR:%s",ipaddr);
	if ( is_user_bot(id) )
		return;
	if (cw_pov_autorecord > 0)
	{
		set_task_ex(5.0, "cw_stop_demo", .id = id);
		set_task_ex(10.0, "cw_stop_demo", .id = id);
	}
	if ( is_user_hltv(id) )
		return;
	get_user_authid(id, g_ClanWarData[id][AUTHID], charsmax(g_ClanWarData[][AUTHID]));
	if (nvault_get_array(g_iVault, g_ClanWarData[id][AUTHID], g_ClanWarData[id], sizeof(g_ClanWarData[])) > 0)
	{
		if (g_ClanWarData[id][PASSWORD] != g_iServerPassword)
		{
			g_ClanWarData[id][PASSWORD] = g_iServerPassword;
			g_ClanWarData[id][KILLS] = 0;
			g_ClanWarData[id][DEATHS] = 0;
		}
	}
	else 
	{
		g_ClanWarData[id][PASSWORD] = g_iServerPassword;
		g_ClanWarData[id][KILLS] = 0;
		g_ClanWarData[id][DEATHS] = 0;
	}
	
	if (cw_pov_autorecord > 0)
	{
		set_task_ex(25.0, "cw_record_demo_notify", .id = id);
		set_task_ex(30.0, "cw_record_demo", .flags = SetTask_Repeat ,.id = id);
	}
}

public cw_stop_demo(id)
{
	client_cmd(id,"stop");
}

public cw_record_demo_notify(id)
{
	client_print_color(id, print_team_red,"^4[%s]^3[CW MODE]^1 Идёт запись демо!",cw_servername)
}

public cw_record_demo(id)
{
	new mapname[33];
	get_mapname(mapname,charsmax(mapname));
	client_cmd(id,"record ^"cw_%s^"",mapname);
}

public cw_mode_say_initialize(id)	
{
	if (get_user_flags(id) & ADMIN_BAN)
	{
		if (g_bActivateClanWarMode)
		{
			client_print_color(id, print_team_red, "^4[%s]^3 CW уже запущен. Перезапустите карту!",cw_servername);
			return;
		}
		g_bActivateClanWarMode = true;
		
		cw_stop_preinstalled_plugins(id);
		cw_init_password(id);
		
		g_iUserCW = id;
		
		cw_kick_players_game_start(0);
		set_task_ex(3.0,"cw_kick_players_game_start");
		set_task_ex(5.0,"cw_kick_players_game_start");
		
		new g_sConfigDirPath[256];
		get_configsdir(g_sConfigDirPath, charsmax(g_sConfigDirPath));
		server_cmd("exec %s/unreal_war/%s",g_sConfigDirPath, cw_warmup_config);
		server_exec();
		
		cw_init_hostname_and_pwd(id);
		
		g_iGameStage = 1;
		
		g_iWarmupMinutes = cw_warmup_time;
		
		cw_warmup_time_start(0);
		set_task_ex(60.0, "cw_warmup_time_start", .id = WARMUP_TASK, .flags = SetTask_Repeat);		
		
		g_ClanWarData[id][PASSWORD] = g_iServerPassword;
		g_ClanWarData[id][KILLS] = 0;
		g_ClanWarData[id][DEATHS] = 0;
	}
}

public cw_mode_map_restart(id)	
{
	if (get_user_flags(id) & ADMIN_BAN)
	{
		server_cmd("restart");
	}
}

public cw_mode_server_restart(id)	
{
	if (get_user_flags(id) & ADMIN_BAN)
	{
		server_cmd("exit");
	}
}

public cw_warmup_time_start( id )
{
	if (g_iWarmupMinutes <= 0)
	{
		cw_warmup_time_end(id);
		return;
	}
	
	client_print_color(0, print_team_red, "^4[%s]^3 До конца разминки осталось ^1%d^3 минут!",cw_servername,g_iWarmupMinutes);
	client_print_color(0, print_team_blue, "^4[%s]^3 До конца разминки осталось ^1%d^3 минут!",cw_servername,g_iWarmupMinutes);
	client_print_color(0, print_team_default, "^4[%s]^3 До конца разминки осталось ^1%d^3 минут!",cw_servername,g_iWarmupMinutes);
	
	new warmmsg[256];
	formatex(warmmsg,charsmax(warmmsg),"Разминка завершится через %d минут...", g_iWarmupMinutes);
	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 3.0, 0.0, 0.0);
	xshow_dhudmessage(0, warmmsg);
	
	g_iWarmupMinutes--;
}


public cw_warmup_time_end( id )
{
	if (g_iGameStage != 1)
		return;
		
	if (cw_knife_round > 0)
	{
		g_iGameStage = 2;
	}
	remove_task(WARMUP_TASK);	
		
	client_print_color(0, print_team_red, "^4[%s]^3 Разминка завершена!",cw_servername);
	client_print_color(0, print_team_blue, "^4[%s]^3 Разминка завершена!",cw_servername);
	client_print_color(0, print_team_red, "^4[%s]^3 Разминка завершена!",cw_servername);
	
	

	xset_dhudmessage(100, 150, 0, -1.0, 0.25, 0, 0.0, 7.0, 0.0, 0.0);
	xshow_dhudmessage(0, "Разминка завершена...");
	
	set_task_ex(2.0,"cw_mode_restartround");
	set_task_ex(4.0,"cw_mode_restartround");
	
	set_task_ex(6.0,"cw_initialize_knife_round");
	
	
	
	new g_sConfigDirPath[256];
	get_configsdir(g_sConfigDirPath, charsmax(g_sConfigDirPath));
	server_cmd("exec %s/unreal_war/%s",g_sConfigDirPath, cw_knife_config);
	server_exec();
}

public cw_mode_multirestart()
{
	set_task_ex(2.0,"cw_mode_restartround");
	set_task_ex(4.0,"cw_mode_restartround");
	set_task_ex(6.0,"cw_mode_restartround");
}

public cw_mode_restartround(id)
{
	server_cmd("sv_restart 1");
}

public cw_initialize_knife_round(id)
{
	server_cmd("sv_restart 1");
	if (cw_knife_round > 0)
	{
		client_print_color(0, print_team_red, "^4[%s]^3 Раунд на ножах за выбор команды! Вперед!!!",cw_servername);
		set_task_ex(3.0,"cw_mode_game_knife_round");
		set_task_ex(3.5,"cw_mode_game_happy");
	}
	else
	{	
		g_iGameStage = 3;
		cw_mode_init_game();
	}
}

public cw_kick_players_game_start(id)
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount);
	for(new i = 0; i < mCount; i++)
	{
		if (is_user_hltv(mPlayers[i]))
		{
			
		}
		else if (mPlayers[i] != g_iUserCW)
		{
			server_cmd("kick #%d ^"Извините проводится CW матч^"",get_user_userid(mPlayers[i]));
		}
	}
	server_exec();
}

public cw_kick_players_game_end(id)
{
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount);
	for(new i = 0; i < mCount; i++)
	{
		if (!is_user_hltv(mPlayers[i]) && mPlayers[i] != id)
		{
			server_cmd("kick #%d ^"Конец игры^"",get_user_userid(mPlayers[i]));
		}
	}
	server_exec();
	server_cmd("restart");
}

public cw_stop_preinstalled_plugins(id)
{	
	/* Остановка моего ReRuneMod */
	pause("c", "rm_base.amxx");
	pause("c", "rm_portal_rune.amxx");
	pause("c", "rm_invis_rune.amxx");
	pause("c", "rm_speed_rune.amxx");
	pause("c", "rm_regen_rune.amxx");
	pause("c", "rm_protect_rune.amxx");
	pause("c", "rm_teleport_rune.amxx");
	pause("c", "rm_medkit_onetime_rune.amxx");
	pause("c", "rm_phantom_rune.amxx");
	
	new iEntity = 0;
	while( ( iEntity = find_ent_by_class( iEntity, "rune_model" ) ) )
	{
		if( is_valid_ent( iEntity ) )
		{
			remove_entity(iEntity);
		}
	}
}

public cw_init_password(id)
{
	g_iServerPassword = random_num(1000,9999);
	server_cmd("sv_password ^"%d^"",g_iServerPassword);
	
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount);
	for(new i = 0; i < mCount; i++)
	{
		if (is_user_hltv(mPlayers[i]))
		{
			client_cmd(mPlayers[id], "serverpassword ^"%d^"", g_iServerPassword)
			break;
		}
	}
	server_exec();
	
	client_print_color(id, print_team_red, "^4[%s]^3 Установлен пароль ^1%d^3, сообщите всем игрокам!",cw_servername, g_iServerPassword);
	client_print_color(id, print_team_blue, "^4[%s]^3 Установлен пароль ^2%d^3, сообщите всем игрокам!",cw_servername, g_iServerPassword);
	client_print_color(id, print_team_default, "^4[%s]^3 Установлен пароль ^4%d^3, сообщите всем игрокам!",cw_servername, g_iServerPassword);
}

public cw_init_hostname_and_pwd(id)
{
	cw_mode_multirestart();
	
	g_bIsPaused = false;
	
	new mPlayers[32];
	new mCount;
	get_players(mPlayers, mCount,"hc");
	
	for(new i = 0; i < mCount; i++)
	{
		if (is_user_connected(mPlayers[i]))
		{
			if ((get_entvar(mPlayers[i], var_flags) & FL_FROZEN))
			{
				set_entvar(mPlayers[i], var_flags, get_entvar(mPlayers[i], var_flags) - FL_FROZEN);
			}
		}
	}
	
	server_cmd("hostname ^"%s^"",cw_servername);
	set_member_game(m_GameDesc, "PIN-CODE!");
	server_exec();
}

stock rg_set_user_deaths(const player, deaths) {
	set_member(player, m_iDeaths, deaths);
}

stock rg_set_user_frags(const player, Float:frags) {
	set_entvar(player, var_frags, Float:frags);
}

stock UpdateScore(attacker, frags, deaths)
{
	if (is_user_connected(attacker))
	{
		//log_to_file("cw_mode.txt","UpdateScore:%d %d",frags,deaths);
		
		rg_set_user_frags(attacker, float(frags));
		rg_set_user_deaths(attacker, deaths)
		
		message_begin(MSG_ALL, g_msgScoreInfo);
		write_byte(attacker);
		write_short(frags);
		write_short(deaths);
		write_short(0);
		write_short(get_member(attacker, m_iTeam));
		message_end();
	}
}

stock rg_set_user_rendering(const index, fx = kRenderFxNone, {Float,_}:color[3] = {0.0,0.0,0.0}, render = kRenderNormal, Float:amount = 0.0)
{
    set_entvar(index, var_renderfx, fx);
    set_entvar(index, var_rendercolor, color);
    set_entvar(index, var_rendermode, render);
    set_entvar(index, var_renderamt, amount);
}




stock __xdhud_color;
stock __xdhud_x;
stock __xdhud_y;
stock __xdhud_effect;
stock __xdhud_fxtime;
stock __xdhud_holdtime;
stock __xdhud_fadeintime;
stock __xdhud_fadeouttime;

stock xset_dhudmessage( red = 0, green = 160, blue = 0, Float:x = -1.0, Float:y = 0.65, effects = 2, Float:fxtime = 0.0, Float:holdtime = 3.0, Float:fadeintime = 0.0, Float:fadeouttime = 0.0)
{
    #define clamp_byte(%1)       ( clamp( %1, 0, 255 ) )
    #define pack_color(%1,%2,%3) ( %3 + ( %2 << 8 ) + ( %1 << 16 ) )

    __xdhud_color       = pack_color( clamp_byte( red ), clamp_byte( green ), clamp_byte( blue ) );
    __xdhud_x           = _:x;
    __xdhud_y           = _:y;
    __xdhud_effect      = effects;
    __xdhud_fxtime      = _:fxtime;
    __xdhud_holdtime    = _:holdtime;
    __xdhud_fadeintime  = _:fadeintime;
    __xdhud_fadeouttime = _:fadeouttime;

    return 1;
}

stock xshow_dhudmessage( index, const message[])
{
	send_dhudMessage(index,message);
}

stock send_dhudMessage( const index, const message[] )
{
	new buffer[ 128 ];
	formatex(buffer,charsmax(buffer),"%s",message);
	message_begin( index ? MSG_ONE : MSG_ALL , SVC_DIRECTOR, _, index );
	write_byte( strlen( buffer ) + 31 );
	write_byte( DRC_CMD_MESSAGE );
	write_byte( __xdhud_effect );
	write_long( __xdhud_color );
	write_long( __xdhud_x );
	write_long( __xdhud_y );
	write_long( __xdhud_fadeintime );
	write_long( __xdhud_fadeouttime );
	write_long( __xdhud_holdtime );
	write_long( __xdhud_fxtime );
	write_string( buffer );
	message_end();
}

#define MAX_LEN_COMMAND 40
#define MAX_LEN_CHALLENGE 32

bool:hltv_open_connection(const host[], port, &socket, challenge[MAX_LEN_CHALLENGE])
{
    new error;
    socket = socket_open(host, port, SOCKET_UDP, error);
    if(!(SOCK_ERROR_CREATE_SOCKET <= error <= SOCK_ERROR_WHILE_CONNECTING))
    {
        socket_send2(socket, fmt("%c%c%c%cchallenge rcon", 0xFF, 0xFF, 0xFF, 0xFF), 23);
        if(socket_is_readable(socket,500000) && socket_recv(socket, challenge, MAX_LEN_CHALLENGE))
        {
            split_challenge(challenge);
            return true;
        }
        else
        {
            hltv_close_connection(socket);
            return false;
        }
    }
    return false;
}

bool:hltv_send_cmd(socket, challenge[MAX_LEN_CHALLENGE], adminpass[], cmd[MAX_LEN_COMMAND], any:...)
{
    new buffer[MAX_LEN_COMMAND + MAX_LEN_CHALLENGE];
    
    vformat(buffer, charsmax(buffer), cmd, 5);
    formatex(buffer, charsmax(buffer), "%c%c%c%c%s ^"%s^" %s", 0xFF, 0xFF, 0xFF, 0xFF, challenge, adminpass, buffer);
    
    return socket_send2(socket, buffer, charsmax(buffer)) ? true : false;
}

bool:hltv_close_connection(socket)
{
    return socket_close(socket) ? true : false;
}

split_challenge(input[])
{
    new i;
    while(i != 13)
    {
        input[i++] = ' ';
    }
    trim(input);
}

msg_servername(iPlayer, msg[]) {
	message_begin(MSG_ONE_UNRELIABLE, g_msgServerName, .player = iPlayer);
	write_string(msg);
	message_end();
}
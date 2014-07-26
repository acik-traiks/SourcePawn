#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_sound>
#include <sdktools_stringtables>
#include <clientprefs>
#include <colors>

public Plugin:myinfo = 
{
	name = "Random Quake Sounds by acik",
	version = "26.07.2014"
};

#define NOEVENT -1
#define JOIN 0
#define R_START 1
#define R_END 2
#define M_END 3
#define VOTE_START 4
#define VOTE_END 5
#define FIRST 6
#define HEAD 7
#define KNIFE 8
#define GREN 9
#define TEAMK 10 
#define SUIC 11
#define DOUB 12
#define TRIP 13
#define QUAD 14
#define MONS 15
#define KS_1 16
#define KS_2 17
#define KS_3 18
#define KS_4 19
#define KS_5 20
#define KS_6 21
#define KS_7 22
#define KS_8 23
#define KS_9 24
#define KS_10 25
#define KS_11 26
#define KS_12 27
#define KS_13 28
#define KS_14 29
#define KS_15 30
#define QUAKE 1
#define EVENT_SOUNDS 2 
#define OVERLAYS 4 
#define MESSAGE 8
#define TR 2
#define CT 3
#define CSS 1
#define CSGO 2

new	
	Game,														// Игра
	String:sSearchName[31][96],										// Имя для поиска
	bool:bSearchName[31] = {false, ...},								// Использовать ли имя
	String:sPathFolder[31][192],										// Путь в папку
	iEventConfig[31],												// Конфигурации для события
	bool:bRandom[31],												// Будет ли случайный звук
	Float:fVolume[31],												// Громкость события
	Float:fComboTimer,												// Таймер для Combo
	bool:bEnableSound[31],											// Проверяет на включение звук
	iAbacusSounds[31],												// Количество звуков
	iKillSound[31],												// Cколько нужно убить
	iSoundNumber[31] = { -1, ...},									// Счетчик количества звуков
	iFirstKill,													// Первое убийство
	iPlayerKills[MAXPLAYERS + 1],										// Сколько убил каждый игрок
	iComboTimer_Player[MAXPLAYERS + 1],								// Сколько убил кадлый игрок для комба
	Float:fComboTimer_Player[MAXPLAYERS + 1],							// Таймер убийства игроков
	Handle:hPathSound[31],											// Запись пути к звукам
	Handle:hDir,													// По очередное присваевание пути
	Handle:QS_key,													// Ключ
	Handle:hClientCookie,											// Запись настроек в куки
	iCookieConfigs[MAXPLAYERS + 1] ={15, ...},							// Настройки у игроков
	Handle:TimerAdvert = INVALID_HANDLE,								// Запись времени появления сообщения 
	Handle:TimerVote = INVALID_HANDLE,									// Время проверки голосование
	Handle:TimerOverlay[MAXPLAYERS + 1],								// Таймер накладки оверлея
	String:sPathOverlay[4][31][192],									// Путь к оверлею командному
	Float:fOverlayClear[31],											// Через сколько секунд очищать экран
	bool:bEnableOverlay[31] = {false, ...},								// Включен ли Оверлай
	iEvent_Sound = 0,												// Есть EVENT_SOUNDS
	iQuake_Sound = 0,												// Есть QUAKE
	iOverlays = 0,													// Есть OVERLAYS
	bool:bStartVote,												// Голосование началось
	kill[15] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},						// Для Обычных убийств
	iNumberRounds,													// Количество Раундов
	Handle:hEnable,												// Конфиг Включения плагина
	bool:bEnable,													// Включен плагин	
	Handle:hIntervalMessage,											// Конфиг изменение интервала
	Float:fIntervalMessage,											// Интервал повтора сообщения
	Handle:hConnectedClient,											// Конфиг настроек нового игрока
	iConnectedClient,												// Настройки нового игрока
	bool:bSimpleDeath;												// Настройка простых убийств
		
static const String:NameEvents[31][96] = {"JoinPlay", "Round Start", "Round End", "Map End", "Vote Start", "Vote End", "FirstBlood", "Headshot", "Knife", "Grenade", "TeamKill", "Suicide", "Double", "Triple", "Quad", "Monster", "KillSound 1", "KillSound 2", "KillSound 3", "KillSound 4", "KillSound 5", "KillSound 6", "KillSound 7", "KillSound 8", "KillSound 9", "KillSound 10", "KillSound 11", "KillSound 12", "KillSound 13", "KillSound 14", "KillSound 15"};

new Handle:g_Cvar_WinLimit;
new Handle:g_Cvar_MaxRounds;

public OnPluginStart() 
{
	new String:bufferString[16];
	GetGameFolderName(bufferString,16);
	if(StrEqual(bufferString,"cstrike",false)) Game = CSS;
	else if(StrEqual(bufferString,"csgo",false)) Game = CSGO;
	else LogError("Plugin not supported game");
	g_Cvar_WinLimit = FindConVar("mp_winlimit");
	g_Cvar_MaxRounds = FindConVar("mp_maxrounds");
	hEnable = CreateConVar("sm_quake_enable", "1", "Включить плагин", _, true, 0.0, true, 1.0);
	hIntervalMessage = CreateConVar("sm_quake_interval", "150.0", "Интервал повтора сообщения", _, true, 60.0);
	hConnectedClient = CreateConVar("sm_quake_config_player", "15", "Что будет вкл у нового игрока, Сумматор:\n1 - QuakeSound, 2 - EventSound\n4 - Ovelays, 8 - Сообщения плагина", _, true, 0.0, true, 15.0);
	LoadTranslations("random_quakesounds");
	AutoExecConfig(true, "random_quakesounds");
	bEnable = GetConVarBool(hEnable);
	fIntervalMessage = GetConVarFloat(hIntervalMessage);
	iConnectedClient = GetConVarInt(hConnectedClient);	
	if(bEnable) 
	{
		Load_Configs_Sounds();
		HookEvent("player_death", Event_PlayerDeath);
		HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
		HookEvent("round_freeze_end", Event_FreezeEnd, EventHookMode_PostNoCopy);
		HookEvent("round_end", Event_RoundEnd);
		hClientCookie = RegClientCookie("RandomQuakeSounds", "RandomQuakeSounds", CookieAccess_Private);
		RegConsoleCmd("sm_quake",CMD_ShowQuakePrefsMenu);
		SetCookieMenuItem(QuakePrefSelected, 0, "Quake Sound Prefs");
		RegConsoleCmd("sm_votemap", Command_Vote);
		RegConsoleCmd("sm_votekick", Command_Vote);
		RegConsoleCmd("sm_voteban", Command_Vote);
		RegConsoleCmd("sm_vote", Command_Vote);
		RegConsoleCmd("say", Command_Vote);
		RegConsoleCmd("say2", Command_Vote);
		RegConsoleCmd("say_team", Command_Vote);
	}
}

public OnConfigsExecuted()
{
	bEnable = GetConVarBool(hEnable);
	fIntervalMessage = GetConVarFloat(hIntervalMessage);
	iConnectedClient = GetConVarInt(hConnectedClient);
}

Load_Configs_Sounds() 
{	
	QS_key = CreateKeyValues("Random_QuakeSounds");
	decl String:fileQSL[192];

	BuildPath(Path_SM, fileQSL, 192, "configs/Random_QuakeSounds.ini");
	FileToKeyValues(QS_key, fileQSL);
		
	for(new event = JOIN; event <= KS_15; event++) 
	{
		KvRewind(QS_key);
		if(bEvent_Sound(event)) 
		{
			KvJumpToKey(QS_key, "Event Sounds");
		}
		else 
		{
			KvJumpToKey(QS_key, "Quake Sounds");
			if(event >= DOUB && event <= MONS) 
			{
				KvJumpToKey(QS_key, "Combo Kills");
				fComboTimer = Float:KvGetFloat(QS_key, "Timer Kills", 1.5);	
			}
			else if(event >= KS_1 && event <= KS_15)
			{
				KvJumpToKey(QS_key, "Number Kills");
				bSimpleDeath = bool:KvGetNum(QS_key, "Simple Death");
			}
		}
		KvJumpToKey(QS_key, NameEvents[event]);
		if(bEvent_Sound(event))
		{
			iEventConfig[event] = KvGetNum(QS_key, "Enable", 1);
		}
		else 
		{
			iEventConfig[event] = KvGetNum(QS_key, "Config", 7);
		}
		if(iEventConfig[event] == 0) 
		{
			bEnableSound[event] = false;
			continue;
		}
		fVolume[event] = Float:KvGetFloat(QS_key, "Volume Sound", 0.9);	
		bRandom[event] = bool:KvGetNum(QS_key, "Random Sound");
		if(event >= KS_1 && event <= KS_15) 
		{
			iKillSound[event] = KvGetNum(QS_key, "Kill");
			if(iKillSound[event] == 0) 
			{
				bEnableSound[event] = false;
				continue;
			}	
		}	
		KvGetString(QS_key, "Search Name", sSearchName[event], 96);
		if(!StrEqual(sSearchName[event], "", false)) 
		{
			bSearchName[event] = true;
		}
		KvGetString(QS_key, "Path Folder", sPathFolder[event], 192);
		if(StrEqual(sPathFolder[event], "", false)) 
		{
			bEnableSound[event] = false;
			continue;
		}
		decl String:PathSound[192];
		Format(PathSound, 192, "sound/%s", sPathFolder[event]);
		hDir = OpenDirectory(PathSound);
		if(hDir == INVALID_HANDLE) 
		{
			LogError("The event \"%s\", could not open folder: \"%s\"", NameEvents[event], PathSound);
			bEnableSound[event] = false;
			continue;
		}
		decl String:SoundName[192], FileType:type;
		hPathSound[event] = CreateArray(192);
		while (ReadDirEntry(hDir, SoundName, 192, type)) 
		{
			if (type == FileType_File && StrContains(SoundName, ".ztmp") == -1) 
			{
				if (StrContains(SoundName, ".mp3") >= 0 || StrContains(SoundName, ".wav") >= 0) 
				{
					if(bSearchName[event]) 
					{
						if(StrContains(SoundName, sSearchName[event]) >= 0) 
						{
							Format(SoundName, 192, "%s/%s", sPathFolder[event], SoundName);
							PushArrayString(hPathSound[event], SoundName);
						}
					} 
					else 
					{
						Format(SoundName, 192, "%s/%s", sPathFolder[event], SoundName);
						PushArrayString(hPathSound[event], SoundName);
					}
				}
			}
		}
		CloseHandle(hDir);
		
		if((iAbacusSounds[event] = GetArraySize(hPathSound[event])) < 1) 
		{
			LogError("The event \"%s\", folder no has sounds", NameEvents[event]);
			bEnableSound[event] = false;
		} 
		else 
		{
			bEnableSound[event] = true;
		}
		if(bEnableSound[event]) 
		{
			if(event != R_END && event != M_END) 
			{
				KvGetString(QS_key, "Path Overlay", sPathOverlay[0][event], 192);
				if(!StrEqual(sPathOverlay[0][event], "", false)) 
				{
					bEnableOverlay[event] = true;
				}
			} 
			else 
			{
				KvGetString(QS_key, "Path Overlay TR", sPathOverlay[TR][event], 192);
				KvGetString(QS_key, "Path Overlay CT", sPathOverlay[CT][event], 192);
				if(!StrEqual(sPathOverlay[TR][event], "", false) && !StrEqual(sPathOverlay[CT][event], "", false)) 
				{
					bEnableOverlay[event] = true;
				}
			}
			
			fOverlayClear[event] = Float:KvGetFloat(QS_key, "Timer Overlay", 2.0);
		
		
			if(bEvent_Sound(event))
			{
				iEvent_Sound++;
			}
			else 
			{
				iQuake_Sound++;
			}
		}
		if(bEnableOverlay[event]) 
		{
			iOverlays++;
		}
	}
	if(iEvent_Sound == 0 && iQuake_Sound == 0 && iOverlays == 0) 
	{
		LogError("All events disabled");
	}
	
 }
 
 public OnMapStart() 
 {
	iNumberRounds = 0;
	decl String:SoundName[192], String:buffer[192]; 
	for(new event = JOIN; event <= KS_15; event++) 
	{
		if(bEnableSound[event]) 
		{
			for(new number = 0; number < iAbacusSounds[event]; number++) 
			{
				GetArrayString(hPathSound[event], number, SoundName, 192);
				Format(buffer, 192, "sound/%s", SoundName); 
				AddFileToDownloadsTable(buffer);				
				if(Game == CSGO)
				{
					Format(SoundName, 192, "*%s", SoundName);
					AddToStringTable(FindStringTable("soundprecache"), SoundName);
				}
				else
				{
					PrecacheSound(SoundName, true);
				}
			}
		}
		if(bEnableOverlay[event]) 
		{
			if(event != R_END && event != M_END) 
			{
				Format(buffer, 192, "%s.vtf", sPathOverlay[0][event]);
				PrecacheDecal(buffer, true);
				Format(buffer, 192, "materials/%s", buffer);
				AddFileToDownloadsTable(buffer);
				
				Format(buffer, 192, "%s.vmt", sPathOverlay[0][event]);
				PrecacheDecal(buffer, true);
				Format(buffer, 192, "materials/%s", buffer);
				AddFileToDownloadsTable(buffer);
			}
			else 
			{
				for(new team = TR; team <= CT; team++) 
				{
					Format(buffer, 192, "%s.vtf", sPathOverlay[team][event]);
					PrecacheDecal(buffer, true);
					Format(buffer, 192, "materials/%s", buffer);
					AddFileToDownloadsTable(buffer);
					
					Format(buffer, 192, "%s.vmt", sPathOverlay[team][event]);
					PrecacheDecal(buffer, true);
					Format(buffer, 192, "materials/%s", buffer);
					AddFileToDownloadsTable(buffer);			
				}
			}
		}
	}
 	if(TimerAdvert == INVALID_HANDLE) 
	{
		TimerAdvert = CreateTimer(fIntervalMessage, MessageSayAll, _, TIMER_REPEAT);
	}
}

public Action:MessageSayAll(Handle:timer) 
{
	for(new iClient = 1; iClient <= MaxClients; iClient++) 
	{
		if(IsClientInGame(iClient) && !IsFakeClient(iClient)) 
		{
			if(iEvent_Sound || iQuake_Sound || iOverlays)  
			{
				if(iCookieConfigs[iClient] & MESSAGE)
				{
					CPrintToChat(iClient, "%t", "Message_Player");
				}
			}
		}
	}
}

public Action:Command_Vote(client, args) 
{
	CreateTimer(0.1, Actively_Vote, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public OnMapVoteStarted() 
{
	CreateTimer(0.1, Actively_Vote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Actively_Vote(Handle:timer) 
{
	if(IsVoteInProgress() && !bStartVote) 
	{
		if(bEnableSound[VOTE_START]) 
		{
			Play_Event_Sound(VOTE_START, 0);
		}
		if(bEnableOverlay[VOTE_START]) 
		{
			Play_Overlay(VOTE_START, 0, false, 0);
		}
		bStartVote = true;
		if(TimerVote == INVALID_HANDLE) 
		{
			TimerVote = CreateTimer(0.5, Actively_Vote, _, TIMER_REPEAT);
		}
	}
	if(!IsVoteInProgress() && bStartVote) 
	{
		if(bEnableSound[VOTE_END])
		{
			Play_Event_Sound(VOTE_END, 0);
		}
		if(bEnableOverlay[VOTE_END]) 
		{
			Play_Overlay(VOTE_END, 0, false, 0);
		}
		bStartVote = false;
		ClearHandle(TimerVote, true);
	}
}
		
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(!bEnable) 
	{
		return;
	}
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!attacker || !victim || !IsClientInGame(attacker) || !IsClientInGame(victim)) 
	{
		return;
	}
	decl String:weapon[64];
	new attacker_team = GetClientTeam(attacker), victim_team = GetClientTeam(victim);
	new bool:headshot = GetEventBool(event, "headshot");
	new Id = -1;
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	iFirstKill++;
	iPlayerKills[attacker]++;
	iPlayerKills[victim] = 0;
	iComboTimer_Player[victim] = 0;
	if(!bSimpleDeath) 
	{
		if(bEnableSound[HEAD])
		{
			if(headshot) 
			{
				Id = HEAD;
			}
		}
		if(bEnableSound[KNIFE]) 
		{
			if(ThisKnife(weapon)) 
			{
				Id = KNIFE;
			}
		}
		if(bEnableSound[GREN]) 
		{
			if(ThisGrenade(weapon)) 
			{
				Id = GREN;
			}
		}
	}
	for(new ks = KS_1; ks <= KS_15; ks++) 
	{
		if(bEnableSound[ks]) 
		{
			if(!bSimpleDeath) 
			{
				if(iPlayerKills[attacker] == iKillSound[ks]) 
				{
					Id = ks;
					break;
				}
			} 
			else 
			{
				if(iPlayerKills[attacker] == kill[ks-KS_1]) 
				{
					Id = ks;
					if(!bEnableSound[ks+1]) 
					{
						iPlayerKills[attacker] = 0;
					}
					break;
				}
			}
		}
	}
	if(bSimpleDeath) 
	{
		if(bEnableSound[HEAD])
		{
			if(headshot) 
			{
				Id = HEAD;
			}
		}
		if(bEnableSound[KNIFE]) 
		{
			if(ThisKnife(weapon)) 
			{
				Id = KNIFE;
			}
		}
		if(bEnableSound[GREN]) 
		{
			if(ThisGrenade(weapon)) 
			{
				Id = GREN;
			}
		}
	}
	
	if(bEnableSound[DOUB] || bEnableSound[TRIP] || bEnableSound[QUAD] || bEnableSound[MONS]) 
	{
		new Float:fLastKillTime = fComboTimer_Player[attacker];
		fComboTimer_Player[attacker] = GetEngineTime();
		if(fLastKillTime == -1.0 || (fComboTimer_Player[attacker] - fLastKillTime) > fComboTimer) 
		{
			iComboTimer_Player[attacker] = 1;
		} 
		else 
		{
			switch(++iComboTimer_Player[attacker]) 
			{
				case 2: 
				{
					Id = DOUB;
				}
				case 3: 
				{
					Id = TRIP;
				}
				case 4: 
				{
					Id = QUAD;
				}
				case 5: 
				{
					Id = MONS;
					iComboTimer_Player[attacker] = 0;
				}
			}
		}
	}
		
	if(bEnableSound[TEAMK]) 
	{
		if(attacker_team == victim_team) 
		{
			Id = TEAMK; 
		}
	}
	
	if(bEnableSound[SUIC]) 
	{
		if(attacker == victim) 
		{
			Id = SUIC;
		}
	}
	if(bEnableSound[FIRST])
	{
		if(iFirstKill == 1) 
		{
			Id = FIRST;
		}
	}
	if(Id >= FIRST && bEnableSound[Id])
	{
		Play_Quake_Sound(Id, attacker, victim);
	}
	if(Id >= FIRST && bEnableOverlay[Id]) 
	{
		Play_Overlay(Id, attacker, true, 0);
	}
}
		
public NewRoundInitialization()
{
	iFirstKill = 0;	
	new iMaxClients = GetMaxClients();
	for(new iClient = 1; iClient <= iMaxClients; iClient++) 
	{
		if(bSimpleDeath) 
		{
			iPlayerKills[iClient] = 0;
		}
		iComboTimer_Player[iClient] = 0;
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(!bEnable)
	{
		return;
	}
	NewRoundInitialization();
}

public Event_FreezeEnd(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(!bEnable) 
	{
		return;
	}
	if(bEnableSound[R_START]) 
	{
		Play_Event_Sound(R_START, 0);
	}
	if(bEnableOverlay[R_START]) 
	{
		Play_Overlay(R_START, 0, false, 0);
	}
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(!bEnable) 
	{
		return;
	}
	new win = GetEventInt(event, "winner");
	if (win > 1) 
	{
		if(!CheckMapEnd())
		{
			if(bEnableSound[R_END]) 
			{
				Play_Event_Sound(R_END, 0);
			}
			if(bEnableOverlay[R_END]) 
			{
				Play_Overlay(R_END, 0, false, win);
			}
		} 
		else 
		{
			if(bEnableSound[M_END]) 
			{
				Play_Event_Sound(M_END, 0);
			}
			if(bEnableOverlay[M_END])
			{
				Play_Overlay(M_END, 0, false, win);
			}
		}
	}
}

public OnClientPutInServer(client) 
{
	if(!bEnable || !client) 
	{
		return;
	}
	if (!IsFakeClient(client)) 
	{
		Load_Setting_Player(client);
	}
	CreateTimer(0.5, Join_Player, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(15.0, Advert_Message, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Join_Player(Handle:timer, any:client) 
{
	if(bEnableSound[JOIN])
	{
		Play_Event_Sound(JOIN, client);
	}
	if(bEnableOverlay[JOIN]) 
	{
		Play_Overlay(JOIN, client, true, 0);
	}
}

#define ADVERT_MESSAGE "\"Random Quake Sounds\" by acik"
public Action:Advert_Message(Handle:timer, any:client) 
{
	if(IsClientInGame(client) && bEnable) 
	{
		if(iEvent_Sound || iQuake_Sound || iOverlays) 
		{
			if(iCookieConfigs[client] & MESSAGE) 
			{
				CPrintToChat(client, "\x01\x04[%s]\x01 %s", Game == CSS ? "CS:S" : "CS:GO", ADVERT_MESSAGE);		
			}
		}
	}
}

public OnClientDisconnect(client)
{
	ClearHandle(TimerOverlay[client], true);
}

public Play_Overlay(Id, client, bool:bNoAll, win) 
{
	if(!bEnable)
	{
		return;
	}
	if(bNoAll)
	{
		if(IsClientInGame(client) && !IsFakeClient(client)) 
		{
			if(iCookieConfigs[client] & OVERLAYS) 
			{
				ClearHandle(TimerOverlay[client], true);
				TimerOverlay[client] = CreateTimer(fOverlayClear[Id], ClearOverlay, client);
				
				Client_ClearOverlay(client);
				Client_SetOverlay(client, sPathOverlay[win][Id]);
			}
		}
	}
	else 
	{
		for(new iClient = 1; iClient <= MaxClients; iClient++) 
		{
			if(IsClientInGame(iClient)  && !IsFakeClient(iClient)) 
			{
				if(iCookieConfigs[iClient] & OVERLAYS) 
				{
					ClearHandle(TimerOverlay[iClient], true);
					TimerOverlay[iClient] = CreateTimer(fOverlayClear[Id], ClearOverlay, iClient);
					Client_ClearOverlay(iClient);
					Client_SetOverlay(iClient, sPathOverlay[win][Id]);
				}
			}
		}
	}
}

public Action:ClearOverlay(Handle:timer, any:client) 
{
	if(client && IsClientInGame(client))
	{
		Client_ClearOverlay(client);
	}
	ClearHandle(TimerOverlay[client], true);
}

ClearHandle(&Handle:hdl, bool:timer = false) 
{
	if (hdl != INVALID_HANDLE) 
	{
		if(timer)
		{
			KillTimer(hdl);
		}
		else
		{
			CloseHandle(hdl);
		}
		hdl = INVALID_HANDLE;
	}
}

public Play_Quake_Sound(Id, attacker, victim) 
{
	if(!bEnable || iEventConfig[Id] < 1 || iAbacusSounds[Id] < 1) 
	{
		return;
	}
	decl String:SoundName[192];
	if(bRandom[Id]) 
	{
		iSoundNumber[Id] = GetRandomInt(0, iAbacusSounds[Id]-1);
	}
	else
	{
		if(++iSoundNumber[Id] > iAbacusSounds[Id]-1) iSoundNumber[Id] = 0;
	}
	GetArrayString(hPathSound[Id], iSoundNumber[Id], SoundName, 192);
	if(Game == CSGO)
	{
		Format(SoundName, 192, "*%s", SoundName);
	}
	if(iEventConfig[Id] & 1) 
	{
		if(iCookieConfigs[attacker] & QUAKE)
		{
			EmitSoundToClient(attacker, SoundName, _, _, _, _, fVolume[Id]);
		}
	}
	if(iEventConfig[Id] & 2) 
	{
		if(iCookieConfigs[victim] & QUAKE) 
		{
			EmitSoundToClient(victim, SoundName, _, _, _, _, fVolume[Id]);
		}
	}
	if(iEventConfig[Id] & 4 || iEventConfig[Id] & 8) 
	{
		for(new iClient = 1; iClient <= MaxClients; iClient++) 
		{
			if(!IsClientInGame(iClient) || IsFakeClient(iClient) || iClient == attacker || iClient == victim)
			{
				continue;
			}
			if(iEventConfig[Id] & 8 && !IsPlayerAlive(iClient))
			{
				continue;
			}
			if(iCookieConfigs[iClient] & QUAKE)
			{
				EmitSoundToClient(iClient, SoundName, _, _, _, _, fVolume[Id]);
			}
		}
	}
}

public Play_Event_Sound(Id, client) 
{
	if(!bEnable || iEventConfig[Id] != 1 || iAbacusSounds[Id] < 1) 
	{
		return;
	}
	decl String:SoundName[192];
	if(bRandom[Id]) 
	{
		iSoundNumber[Id] = GetRandomInt(0, iAbacusSounds[Id]-1);
	} 
	else 
	{
		if(++iSoundNumber[Id] > iAbacusSounds[Id]-1)
		{
			iSoundNumber[Id] = 0;
		}
	}
	GetArrayString(hPathSound[Id], iSoundNumber[Id], SoundName, 192);
	if(Game == CSGO)
	{
		Format(SoundName, 192, "*%s", SoundName);
	}
	if(Id == JOIN) 
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			 if(iCookieConfigs[client] & EVENT_SOUNDS) 
			 {
				EmitSoundToClient(client, SoundName, _, _, _, _, fVolume[Id]);
			 }
		}
	} 
	else 
	{
		for(new iClient = 1; iClient <= MaxClients; iClient++)
		{
			if(IsClientInGame(iClient) && !IsFakeClient(iClient))
			{
				if(iCookieConfigs[iClient] & EVENT_SOUNDS)
				{
					EmitSoundToClient(iClient, SoundName, _, _, _, _, fVolume[Id]);
				}
			}
		}
	}
}

Load_Setting_Player(client) 
{
	if(!client) 
	{
		return;
	}
	decl String:buffer[10];
	GetClientCookie(client, hClientCookie, buffer, sizeof(buffer));
	if (buffer[0]) 
	{
		iCookieConfigs[client] = StringToInt(buffer);
	} 
	else 
	{
		iCookieConfigs[client] = iConnectedClient;
	}
}

public QuakePrefSelected(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) 
{
	if(action == CookieMenuAction_SelectOption) 
	{
		ShowQuakeMenu(client);
	}
}

public Action:CMD_ShowQuakePrefsMenu(client, args) 
{
	ShowQuakeMenu(client);
	return Plugin_Handled;
}

#define MENU_TITLE "Настройка плагина\n\"Random Quake Sounds\"\n \n"
public ShowQuakeMenu(client) 
{
	new Handle:menu = CreateMenu(MenuHandlerQuake);
	new String:buffer[100];
	Format(buffer, 100, MENU_TITLE);
	SetMenuTitle(menu, buffer);
	if(iEvent_Sound || iQuake_Sound || iOverlays) 
	{
		if(iQuake_Sound) 
		{
			Format(buffer, 100, "%t", "Menu_Item_Quake");
			if(iCookieConfigs[client] & QUAKE) 
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			}
			else
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			}
			AddMenuItem(menu, "", buffer);
		}
		if(iEvent_Sound) 
		{
			Format(buffer, 100, "%t", "Menu_Item_Event");
			if(iCookieConfigs[client] & EVENT_SOUNDS) 
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			}
			else
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			}
			AddMenuItem(menu, "", buffer);
		}
		if(iOverlays)
		{
			Format(buffer, 100, "%t", "Menu_Item_Overlay");
			if(iCookieConfigs[client] & OVERLAYS)
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			}
			else
			{
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			}
			AddMenuItem(menu, "", buffer);
		}
		Format(buffer, 100, "%t", "Menu_Item_Message");
		if(iCookieConfigs[client] & MESSAGE) 
		{
			Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
		}
		else
		{
			Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
		}
		AddMenuItem(menu, "", buffer);	
	} 
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
}

public MenuHandlerQuake(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)	
	{
		if(iEvent_Sound || iQuake_Sound || iOverlays) 
		{
			new key = -1;
			if(iQuake_Sound)
			{
				key++;
				if(param2 == key) 
				{
					if(iCookieConfigs[client] & QUAKE) 
					{
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Quake_Off");
						iCookieConfigs[client] -= QUAKE;
					} 
					else 
					{
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Quake_On");
						iCookieConfigs[client] += QUAKE;
					}
				}
			}		
			if(iEvent_Sound) 
			{
				key++;
				if(param2 == key) 
				{
					if(iCookieConfigs[client] & EVENT_SOUNDS) 
					{
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Event_Off");
						iCookieConfigs[client] -= EVENT_SOUNDS;
					}
					else 
					{
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Event_On");
						iCookieConfigs[client] += EVENT_SOUNDS;
					}
				}
			}
			if(iOverlays) 
			{
				key++;
				if(param2 == key) 
				{
					if(iCookieConfigs[client] & OVERLAYS) 
					{
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Overlays_Off");
						ClearHandle(TimerOverlay[client], true);
						Client_ClearOverlay(client);						
						iCookieConfigs[client] -= OVERLAYS;
					}
					else 
					{ 
						if(iCookieConfigs[client] & MESSAGE) CPrintToChat(client, "%t", "Message_Overlays_On");		
						iCookieConfigs[client] += OVERLAYS;
					}
				}
			}
			key++;
			if(param2 == key) 
			{
				if(iCookieConfigs[client] & MESSAGE) 
				{
					iCookieConfigs[client] -= MESSAGE;
				} 
				else 
				{ 
					iCookieConfigs[client] += MESSAGE;
				}
			}
			new String:buffer[10];
			IntToString(iCookieConfigs[client], buffer, 10);
			SetClientCookie(client, hClientCookie, buffer);
			ShowQuakeMenu(client);
		}
	} 
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock Client_SetOverlay(client, const String:path[]) 
{
	ClientCommand(client, "r_screenoverlay \"%s.vtf\"", path);
}

stock Client_ClearOverlay(client) 
{
	ClientCommand(client, "r_screenoverlay \"\"");
}

stock bool:CheckMapEnd()
{
	new bool:lastround = false;
	new bool:notimelimit = false;
	new timeleft;
	if (GetMapTimeLeft(timeleft))
	{
		new timelimit;
		if (timeleft > 0) 
		{
			return false;
		}
		else if (GetMapTimeLimit(timelimit) && !timelimit)
		{
			notimelimit = true;
		}
		else 
		{
			lastround = true;
		}
	}
	if (!lastround)
	{
		if (g_Cvar_WinLimit != INVALID_HANDLE)
		{
			new winlimit = GetConVarInt(g_Cvar_WinLimit);
			if (winlimit > 0)
			{
				if (GetTeamScore(TR) >= winlimit || GetTeamScore(CT) >= winlimit)
				{
					lastround = true;
				}
			}
		}
		if (g_Cvar_MaxRounds != INVALID_HANDLE)
		{
			new maxrounds = GetConVarInt(g_Cvar_MaxRounds);
			if (maxrounds > 0)
			{
				new remaining = maxrounds - iNumberRounds;	
				if (!remaining) 
				{
					lastround = true;
				}
			}		
		}
	}
	if (lastround) 
	{
		return true;
	}
	else if (notimelimit) 
	{
		return false;
	}
	return true;
}

stock bool:bEvent_Sound(event) 
{
	if(event != R_END &&
	event != R_START &&
	event != JOIN &&
	event != M_END &&
	event != VOTE_END &&
	event != VOTE_START) 
	{
		return false;
	}
	return true;
}

stock bool:ThisGrenade(String:weapon[]) 
{
	if(Game == CSS) 
	{ 
		if(StrEqual(weapon, "hegrenade") || 
		StrEqual(weapon, "smokegrenade") || 
		StrEqual(weapon, "flashbang")) 
		{
			return true;
		}
		
	} 
	else if(Game == CSGO)
	{
		if(StrEqual(weapon,"inferno") || 
		StrEqual(weapon,"hegrenade") || 
		StrEqual(weapon,"flashbang") || 
		StrEqual(weapon,"decoy") || 
		StrEqual(weapon,"smokegrenade")) 
		{
			return true;
		}
	}
	return false;
}

stock bool:ThisKnife(String:weapon[]) 
{
	if(Game == CSS) 
	{ 
		if(StrEqual(weapon, "knife")) 
		{
			return true;
		}
	}
	else if(Game == CSGO)
	{
		if(StrEqual(weapon,"knife_default_ct") ||
		StrEqual(weapon,"knife_default_t") || 
		StrEqual(weapon,"knife_ct") ||
		StrEqual(weapon,"knife_t") || 
		StrEqual(weapon,"knifegg") || 
		StrEqual(weapon,"knife_flip") || 
		StrEqual(weapon,"knife_gut") || 
		StrEqual(weapon,"knife_gg") || 
		StrEqual(weapon,"knife_karambit") || 
		StrEqual(weapon,"knife_karam") || 
		StrEqual(weapon,"bayonet") || 
		StrEqual(weapon,"knife_tactical") || 
		StrEqual(weapon,"knife_bayonet") || 
		StrEqual(weapon,"knife_butterfly") || 
		StrEqual(weapon,"knife_m9_bay") || 
		StrEqual(weapon,"knife") || 
		StrEqual(weapon,"knife_m9_bayonet")) 
		{
			return true;
		}
	}
	return false;
}

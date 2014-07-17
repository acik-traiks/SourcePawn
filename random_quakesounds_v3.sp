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
	version = "17.07.2014"
};

/* ---------- Id Event ---------- */
#define FIRST 0
#define HEAD 1
#define KNIFE 2
#define GREN 3
#define TEAMK 4 
#define SUIC 5
#define DOUB 6
#define TRIP 7
#define QUAD 8
#define MONS 9
#define JOIN 10
#define R_START 11
#define R_END 12
#define M_END 13
#define KS_1 14
#define KS_2 15
#define KS_3 16
#define KS_4 17
#define KS_5 18
#define KS_6 19
#define KS_7 20
#define KS_8 21
#define KS_9 22
#define KS_10 23
#define KS_11 24
#define KS_12 25
#define KS_13 26
#define KS_14 27
#define KS_15 28
#define VOTE_START 29
#define VOTE_END 30

/* ---------- Configs Cookie ---------- */
#define QUAKE 1
#define EVENT_SOUNDS 2 
#define OVERLAYS 4 
#define MESSAGE 8

/* ---------- Player team ---------- */
#define TR 2
#define CT 3

/* ---------- Game ---------- */
#define CSS 1
#define CSGO 2

/* ---------- Variables ---------- */
new	
	Game,															// Игра
	String:sSearchName[31][96],										// Имя для поиска
	bool:bSearchName[31] = {false, ...},							// Использовать ли имя
	String:sPathFolder[31][192],									// Путь в папку
	iEventConfig[31],												// Конфигурации для события
	bool:bRandom[31],												// Будет ли случайный звук
	Float:fVolume[31],												// Громкость события
	Float:fComboTimer,												// Таймер для Combo
	
	bool:bEnableEvent[31],											// Проверяет на включение звук
	iAbacusSounds[31],												// Количество звуков
	iKillSound[31],													// Cколько нужно убить
	iSoundNumber[31] = { -1, ...},									// Счетчик количества звуков
	
	iFirstKill,														// Первое убийство
	iPlayerKills[MAXPLAYERS + 1],									// Сколько убил каждый игрок
	iComboTimer_Player[MAXPLAYERS + 1],								// Сколько убил кадлый игрок для комба
	Float:fComboTimer_Player[MAXPLAYERS + 1],						// Таймер убийства игроков
		
	Handle:hPathSound[31],											// Запись пути к звукам
	Handle:hDir,													// По очередное присваевание пути
	Handle:QS_key,													// Ключ
	
	Handle:hClientCookie,											// Запись настроек в куки
	iCookieConfigs[MAXPLAYERS + 1] ={15, ...},						// Настройки у игроков
		
	Handle:TimerAdvert = INVALID_HANDLE,							// Запись времени появления сообщения 
		
	Handle:TimerOverlay[MAXPLAYERS + 1],							// Таймер накладки оверлея
	String:sPathOverlay[4][31][192],								// Путь к оверлею командному
	Float:fOverlayClear[31],										// Через сколько секунд очищать экран
	bool:bEnableOverlay[31] = {false, ...},							// Включен ли Оверлай
	bool:bMapEnd = false,											// Карта закончилась
	
	iEvent_Sound = 0,												// Есть EVENT_SOUNDS
	iQuake_Sound = 0,												// Есть QUAKE
	iOverlays = 0,													// Есть OVERLAYS

	bool:bStartVote,												// Голосование началось
	
	kill = 0,														// Для Обычных убийств
	iNumberRounds;													// Количество Раундов

/* ---------- Exec Config ---------- */
new
	Handle:hEnable,													// Конфиг Включения плагина
	bool:bEnable,													// Включен плагин	

	Handle:hIntervalMessage,										// Конфиг изменение интервала
	Float:fIntervalMessage,											// Интервал повтора сообщения

	Handle:hConnectedClient,										// Конфиг настроек нового игрока
	iConnectedClient,												// Настройки нового игрока
	
	Handle:hSimpleDeath,											// Конфиг включения простых убийств
	bool:bSimpleDeath;												// Настройка простых убийств
		
static const String:NameEvents[31][96] = {"FirstBlood", "Headshot", "Knife", "Grenade", "TeamKill", "Suicide", "Double", "Triple", "Quad", "Monster", "JoinPlay", "Round Start", "Round End", "Map End", "KillSound 1", "KillSound 2", "KillSound 3", "KillSound 4", "KillSound 5", "KillSound 6", "KillSound 7", "KillSound 8", "KillSound 9", "KillSound 10", "KillSound 11", "KillSound 12", "KillSound 13", "KillSound 14", "KillSound 15", "Vote Start", "Vote End"};

new Handle:g_Cvar_WinLimit;
new Handle:g_Cvar_MaxRounds;

public OnPluginStart() {
	new String:bufferString[16];
	GetGameFolderName(bufferString,16);
	if(StrEqual(bufferString,"cstrike",false)) Game = CSS;
	else if(StrEqual(bufferString,"csgo",false)) Game = CSGO;
	else SetFailState("Plugin not supported game");
	
	g_Cvar_WinLimit = FindConVar("mp_winlimit");
	g_Cvar_MaxRounds = FindConVar("mp_maxrounds");
	
	hEnable = CreateConVar("sm_quake_enable", "1", "Включить плагин", _, true, 0.0, true, 1.0);
	hIntervalMessage = CreateConVar("sm_quake_interval", "150.0", "Интервал повтора сообщения", _, true, 60.0);
	hConnectedClient = CreateConVar("sm_quake_config_player", "15", "Что будет вкл у нового игрока, Сумматор:\n1 - QuakeSound, 2 - EventSound\n4 - Ovelays, 8 - Сообщения плагина", _, true, 0.0, true, 15.0);
	hSimpleDeath = CreateConVar("sm_quake_simple_death", "0", "Обычные Убийства, 1 - В KillSound-ах их номер означает количество убийств,\n 0 - Учитывается параметр 'Kill'", _, true, 0.0, true, 1.0);
	
	LoadTranslations("random_quakesounds");
	AutoExecConfig(true, "random_quakesounds");
	
	bEnable = GetConVarBool(hEnable);
	fIntervalMessage = GetConVarFloat(hIntervalMessage);
	iConnectedClient = GetConVarInt(hConnectedClient);	
	bSimpleDeath = GetConVarBool(hSimpleDeath);
		
	if(bEnable) {
		Load_Configs_Sounds();
		/* ---------- HookEvent ----------- */	
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

public OnConfigsExecuted() {
	bEnable = GetConVarBool(hEnable);
	fIntervalMessage = GetConVarFloat(hIntervalMessage);
	iConnectedClient = GetConVarInt(hConnectedClient);
	bSimpleDeath = GetConVarBool(hSimpleDeath);
}

Load_Configs_Sounds() {
	
	QS_key = CreateKeyValues("Random_QuakeSounds");
	decl String:fileQSL[192];

	BuildPath(Path_SM, fileQSL, 192, "configs/Random_QuakeSounds.ini");
	FileToKeyValues(QS_key, fileQSL);
		
	for(new event = FIRST; event <= VOTE_END; event++) {
		
		KvRewind(QS_key);
		if(event >= DOUB && event <= MONS) {
			KvJumpToKey(QS_key, "Combo");
			fComboTimer = Float:KvGetFloat(QS_key, "Timer_Kills", 1.5);	
		}
		KvJumpToKey(QS_key, NameEvents[event]);
		
		if(bNunbEventSound(event))
			iEventConfig[event] = KvGetNum(QS_key, "Enable", 1);
		else 
			iEventConfig[event] = KvGetNum(QS_key, "Config", 7);
		if(iEventConfig[event] == 0) {
			bEnableEvent[event] = false;
			continue;
		}
		
		fVolume[event] = Float:KvGetFloat(QS_key, "Volume_Sound", 0.9);	
		
		if(!bSimpleDeath && event >= KS_1 && event <= KS_15) {
			iKillSound[event] = KvGetNum(QS_key, "Kill");
			if(iKillSound[event] == 0) {
				bEnableEvent[event] = false;
				continue;
			}	
		}	
		
		bRandom[event] = bool:KvGetNum(QS_key, "Random_Sound");
				
		KvGetString(QS_key, "Path_Folder", sPathFolder[event], 192);
		if(StrEqual(sPathFolder[event], "", false)) {
			bEnableEvent[event] = false;
			continue;
		}
		KvGetString(QS_key, "Search_Name", sSearchName[event], 96);
		if(!StrEqual(sSearchName[event], "", false)) {
			bSearchName[event] = true;
		}
		
		decl String:PathSound[192];
		Format(PathSound, 192, "sound/%s", sPathFolder[event]);
		hDir = OpenDirectory(PathSound);
		if(hDir == INVALID_HANDLE) {
			LogError("The event \"%s\" could not open \"%s\"", NameEvents[event], PathSound);
			bEnableEvent[event] = false;
			continue;
		}
		decl String:SoundName[192], FileType:type;
		hPathSound[event] = CreateArray(192);
		
		while (ReadDirEntry(hDir, SoundName, 192, type)) {
			if (type == FileType_File && StrContains(SoundName, ".ztmp") == -1) {
				if (StrContains(SoundName, ".mp3") >= 0 || StrContains(SoundName, ".wav") >= 0) {
					if(bSearchName[event]) {
						if(StrContains(SoundName, sSearchName[event]) >= 0) {
							Format(SoundName, 192, "%s/%s", sPathFolder[event], SoundName);
							PushArrayString(hPathSound[event], SoundName);
						}
					} else {
						Format(SoundName, 192, "%s/%s", sPathFolder[event], SoundName);
						PushArrayString(hPathSound[event], SoundName);
					}
				}
			}
		}
		CloseHandle(hDir);
		if((iAbacusSounds[event] = GetArraySize(hPathSound[event])) < 1) {
			LogError("The event \"%s\" no has sounds", NameEvents[event]);
			bEnableEvent[event] = false;
		} else bEnableEvent[event] = true;
		
		if(bEnableEvent[event]) {
			if(bNunbEventSound(event)) iEvent_Sound++;
			else iQuake_Sound++;
			
			if(event != R_END && event != M_END) {
				KvGetString(QS_key, "Path_Overlay", sPathOverlay[0][event], 192);
				if(!StrEqual(sPathOverlay[0][event], "", false)) {
					bEnableOverlay[event] = true;
				}
			} else {
				KvGetString(QS_key, "Path_OverlayTR", sPathOverlay[TR][event], 192);
				KvGetString(QS_key, "Path_OverlayCT", sPathOverlay[CT][event], 192);
				if(!StrEqual(sPathOverlay[TR][event], "", false) && !StrEqual(sPathOverlay[CT][event], "", false)) {
					bEnableOverlay[event] = true;
				}
			}
			
			fOverlayClear[event] = Float:KvGetFloat(QS_key, "Timer_Overlay", 2.0);
			if(bEnableOverlay[event]) iOverlays++;
		}
	}
	if(iEvent_Sound == 0 && iQuake_Sound == 0 && iOverlays == 0) LogError("All Events Disabled");
 }
 
 public OnMapStart() {

	iNumberRounds = 0;
	decl String:SoundName[192];
	for(new event = FIRST; event <= VOTE_END; event++) {
		if(!bEnableEvent[event]) continue;
		for(new number = 0; number < iAbacusSounds[event]; number++) {
			GetArrayString(hPathSound[event], number, SoundName, 192);
			PrecacheSound(SoundName, true);
			Format(SoundName, 192, "sound/%s", SoundName); 
			AddFileToDownloadsTable(SoundName);
		}
		if(!bEnableOverlay[event]) continue;
		decl String:buffer[192];
		if(event != R_END && event != M_END) {
			Format(buffer, 192, "%s.vtf", sPathOverlay[0][event]);
			PrecacheDecal(buffer, true);
			Format(buffer, 192, "materials/%s", buffer);
			AddFileToDownloadsTable(buffer);
			
			Format(buffer, 192, "%s.vmt", sPathOverlay[0][event]);
			PrecacheDecal(buffer, true);
			Format(buffer, 192, "materials/%s", buffer);
			AddFileToDownloadsTable(buffer);
		} else {
			for(new team = TR; team <= CT; team++) {
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
 	if(TimerAdvert == INVALID_HANDLE) {
		TimerAdvert = CreateTimer(fIntervalMessage, MessageSayAll, _, TIMER_REPEAT);
	}
}

public Action:MessageSayAll(Handle:timer) {
	for(new iClient = 1; iClient <= MaxClients; iClient++) {
		if(IsClientInGame(iClient) && !IsFakeClient(iClient)) {
			if(iEvent_Sound || iQuake_Sound || iOverlays)  {
				if(iCookieConfigs[iClient] & MESSAGE) 
					CPrintToChat(iClient, "%t", "Message_Player");
			}
		}
	}
}

public Action:Command_Vote(client, args) {
	
 	CreateTimer(0.01, Actively_Vote, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public OnMapVoteStarted() {

	CreateTimer(0.01, Actively_Vote, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Actively_Vote(Handle:timer) {
	new VoteId = 0;
	if(IsVoteInProgress() && !bStartVote) {
		VoteId = VOTE_START;
		bStartVote = true;
	}
	if(!IsVoteInProgress() && bStartVote) {
		VoteId = VOTE_END;
		bStartVote = false;
	}
	if(VoteId) {
		if(bEnableEvent[VoteId]) Play_Event_Sound(VoteId, 0);
		if(bEnableOverlay[VoteId]) Play_Overlay(VoteId, 0, false, 0);				
	} else
		CreateTimer(0.5, Actively_Vote, _, TIMER_FLAG_NO_MAPCHANGE);
}
		
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!bEnable) return;
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!attacker || !victim || !IsClientInGame(attacker) || !IsClientInGame(victim)) return;
	
	decl String:weapon[64];
	new attacker_team = GetClientTeam(attacker), victim_team = GetClientTeam(victim);
	new bool:headshot = GetEventBool(event, "headshot");
	new Id = -1;
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	iFirstKill++;
	iPlayerKills[attacker]++;
	iPlayerKills[victim] = 0;
	iComboTimer_Player[victim] = 0;

	if(!bSimpleDeath) {
		if(bEnableEvent[HEAD]) if(headshot) Id = HEAD;
		if(bEnableEvent[KNIFE]) if(ThisKnife(weapon)) Id = KNIFE;
		if(bEnableEvent[GREN]) if(ThisGrenade(weapon)) Id = GREN;
	}
	
	for(new ks = KS_1; ks <= KS_15; ks++) {
		if(++kill >= 16) kill = 0;
		if(!bEnableEvent[ks]) continue;
		if(!bSimpleDeath) {
			if(iPlayerKills[attacker] == iKillSound[ks]) {
				Id = ks;
				break;
			}
		} else {
			if(iPlayerKills[attacker] == kill) {
				Id = ks;
				break;
			}
		}
	}
	
	if(bSimpleDeath) {
		if(bEnableEvent[HEAD]) if(headshot) Id = HEAD;
		if(bEnableEvent[KNIFE]) if(ThisKnife(weapon)) Id = KNIFE;
		if(bEnableEvent[GREN]) if(ThisGrenade(weapon)) Id = GREN;
	}
	
	if(bEnableEvent[DOUB] || bEnableEvent[TRIP] || bEnableEvent[QUAD] || bEnableEvent[MONS]) {
		new Float:fLastKillTime = fComboTimer_Player[attacker];
		fComboTimer_Player[attacker] = GetEngineTime();
		if(fLastKillTime == -1.0 || (fComboTimer_Player[attacker] - fLastKillTime) > fComboTimer) {
			iComboTimer_Player[attacker] = 1;
		} else {
			switch(++iComboTimer_Player[attacker]) {
				case 2: Id = DOUB;
				case 3: Id = TRIP;
				case 4: Id = QUAD;
				case 5: {
					Id = MONS;
					iComboTimer_Player[attacker] = 0;
				}
			}
		}
	}
		
	if(bEnableEvent[TEAMK]) if(attacker_team == victim_team) Id = TEAMK; 
	
	if(bEnableEvent[SUIC]) if(attacker == victim) Id = SUIC;
	
	if(bEnableEvent[FIRST])	if(iFirstKill == 1) Id = FIRST;
	
	if(Id >= FIRST && bEnableEvent[Id] && !bMapEnd) Play_Quake_Sound(Id, attacker, victim);
	if(Id >= FIRST && bEnableOverlay[Id]) Play_Overlay(Id, attacker, true, 0);
}
		
public NewRoundInitialization(){

	kill = 0;
	iFirstKill = 0;	
	new iMaxClients = GetMaxClients();
	for(new iClient = 1; iClient <= iMaxClients; iClient++) {
		iComboTimer_Player[iClient] = 0;
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!bEnable) return;
	NewRoundInitialization();
}
public Event_FreezeEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!bEnable) return;
	if(bEnableEvent[R_START]) Play_Event_Sound(R_START, 0);
	if(bEnableOverlay[R_START]) Play_Overlay(R_START, 0, false, 0);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!bEnable) return;
	new win = GetEventInt(event, "winner");
	if (win > 1) {
		if(CheckMapEnd()){
			if(bEnableEvent[R_END]) Play_Event_Sound(R_END, 0);
			if(bEnableOverlay[R_END]) Play_Overlay(R_END, 0, false, win);
		} else {
			if(bEnableEvent[M_END]) Play_Event_Sound(M_END, 0);
			if(bEnableOverlay[M_END]) Play_Overlay(M_END, 0, false, win);
		}
	}
}

public OnClientPutInServer(client) {
	if(!bEnable || !client) return;
	if (!IsFakeClient(client)) {
		Load_Setting_Player(client);
	}
	CreateTimer(0.5, Join_Player, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(15.0, Advert_Message, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Join_Player(Handle:timer, any:client) {
	if(bEnableEvent[JOIN]) Play_Event_Sound(JOIN, client);
	if(bEnableOverlay[JOIN]) Play_Overlay(JOIN, client, true, 0);
}

#define ADVERT_MESSAGE "\"Random Quake Sounds\" by acik"

public Action:Advert_Message(Handle:timer, any:client) 
	if(IsClientInGame(client) && bEnable) 
		if(iEvent_Sound || iQuake_Sound || iOverlays) 
			if(iCookieConfigs[client] & MESSAGE) 
				CPrintToChat(client, "\x01\x04[%s]\x01 %s", Game == CSS ? "CS:S" : "CS:GO", ADVERT_MESSAGE);


public OnClientDisconnect(client) ClearHandle(TimerOverlay[client], true);

/* ----------	Start Overlay	---------- */
public Play_Overlay(Id, client, bool:bAll, win) {
	if(!bEnable) return;
	if(bAll) {
		if(IsClientInGame(client) && !IsFakeClient(client)) {
			if(iCookieConfigs[client] & OVERLAYS) {
				ClearHandle(TimerOverlay[client], true);
				TimerOverlay[client] = CreateTimer(fOverlayClear[Id], ClearOverlay, client);
				
				Client_ClearOverlay(client);
				Client_SetOverlay(client, sPathOverlay[win][Id]);
			}
		}
	} else {
		for(new iClient = 1; iClient <= MaxClients; iClient++) {
			if(IsClientInGame(iClient)  && !IsFakeClient(iClient)) {
				if(iCookieConfigs[iClient] & OVERLAYS) {
					ClearHandle(TimerOverlay[iClient], true);
					TimerOverlay[iClient] = CreateTimer(fOverlayClear[Id], ClearOverlay, iClient);
					
					Client_ClearOverlay(iClient);
					Client_SetOverlay(iClient, sPathOverlay[win][Id]);
				}
			}
		}
	}
}

public Action:ClearOverlay(Handle:timer, any:client) {

	if(client && IsClientInGame(client)) Client_ClearOverlay(client);
	ClearHandle(TimerOverlay[client], true);
}

ClearHandle(&Handle:hdl, bool:timer = false) {
	if (hdl != INVALID_HANDLE) {
		if(timer) KillTimer(hdl);
		else CloseHandle(hdl);
		hdl = INVALID_HANDLE;
	}
}
/* ----------	End Overlay	---------- */

/* ----------	Start Event & Quake Sound	---------- */
public Play_Quake_Sound(Id, attacker, victim) {

	if(iAbacusSounds[Id] < 1 || iEventConfig[Id] < 1 || !bEnable) return;
	decl String:SoundName[192];
	
	if(bRandom[Id]) 
		iSoundNumber[Id] = GetRandomInt(0, iAbacusSounds[Id]-1);
	else {
		if(++iSoundNumber[Id] > iAbacusSounds[Id]-1) iSoundNumber[Id] = 0;
	}
	GetArrayString(hPathSound[Id], iSoundNumber[Id], SoundName, 192);	
	
	PrintToChat(attacker, "%s: %s", NameEvents[Id], SoundName);
	if(iEventConfig[Id] & 1) if(iCookieConfigs[attacker] & QUAKE) EmitSoundToClient(attacker, SoundName, _, _, _, _, fVolume[Id]);
	if(iEventConfig[Id] & 2) if(iCookieConfigs[victim] & QUAKE) EmitSoundToClient(victim, SoundName, _, _, _, _, fVolume[Id]);
	if(iEventConfig[Id] & 4 || iEventConfig[Id] & 8) {
		for(new iClient = 1; iClient <= MaxClients; iClient++) {
			if(!IsClientInGame(iClient) || IsFakeClient(iClient) || iClient == attacker || iClient == victim) continue;
			if(iEventConfig[Id] & 8 && !IsPlayerAlive(iClient)) continue;
			if(iCookieConfigs[iClient] & QUAKE)
				EmitSoundToClient(iClient, SoundName, _, _, _, _, fVolume[Id]);
		}
	}
}

public Play_Event_Sound(Id, client) {

	if(!bEnable || iEventConfig[Id] != 1 || iAbacusSounds[Id] < 1) return;
	decl String:SoundName[192];
	
	if(bRandom[Id]) 
		iSoundNumber[Id] = GetRandomInt(0, iAbacusSounds[Id]-1);
	else {
		if(++iSoundNumber[Id] > iAbacusSounds[Id]-1) iSoundNumber[Id] = 0;
	}
	GetArrayString(hPathSound[Id], iSoundNumber[Id], SoundName, 192);	

	if(Id == JOIN) {
		if(IsClientInGame(client) && !IsFakeClient(client)) if(iCookieConfigs[client] & EVENT_SOUNDS) EmitSoundToClient(client, SoundName, _, _, _, _, fVolume[Id]);
	} else {
		for(new iClient = 1; iClient <= MaxClients; iClient++) {
			if(IsClientInGame(iClient) && !IsFakeClient(iClient))
				if(iCookieConfigs[iClient] & EVENT_SOUNDS)
					EmitSoundToClient(iClient, SoundName, _, _, _, _, fVolume[Id]);
		}
	}
}
/* ----------	End Event & Quake Sound	---------- */

Load_Setting_Player(client) {
	
	if(!client) return;
	decl String:buffer[10];
	GetClientCookie(client, hClientCookie, buffer, sizeof(buffer));
	if (buffer[0]) {
		iCookieConfigs[client] = StringToInt(buffer);
	} else {
		iCookieConfigs[client] = iConnectedClient;
	}
}

public QuakePrefSelected(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if(action == CookieMenuAction_SelectOption) ShowQuakeMenu(client);
}

public Action:CMD_ShowQuakePrefsMenu(client, args) {

	ShowQuakeMenu(client);
	return Plugin_Handled;
}

#define MENU_TITLE "Настройка плагина\n\"Random Quake Sounds\"\n \n"

public ShowQuakeMenu(client) {

	new Handle:menu = CreateMenu(MenuHandlerQuake);
	new String:buffer[100];
	Format(buffer, 100, MENU_TITLE);
	SetMenuTitle(menu, buffer);

	if(iEvent_Sound || iQuake_Sound || iOverlays) {
		if(iQuake_Sound) {
			Format(buffer, 100, "%t", "Menu_Item_Quake");
			if(iCookieConfigs[client] & QUAKE) 
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			else
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			AddMenuItem(menu, "", buffer);
		}
		
		if(iEvent_Sound) {
			Format(buffer, 100, "%t", "Menu_Item_Event");
			if(iCookieConfigs[client] & EVENT_SOUNDS) 
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			else
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			AddMenuItem(menu, "", buffer);
		}

		if(iOverlays) {
			Format(buffer, 100, "%t", "Menu_Item_Overlay");
			if(iCookieConfigs[client] & OVERLAYS) 
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
			else
				Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
			AddMenuItem(menu, "", buffer);
		}
		
		Format(buffer, 100, "%t", "Menu_Item_Message");
		if(iCookieConfigs[client] & MESSAGE) 
			Format(buffer, 100, "%s %t", buffer, "Menu_Item_On");
		else
			Format(buffer, 100, "%s %t", buffer, "Menu_Item_Off");
		AddMenuItem(menu, "", buffer);	
	} 
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
}

public MenuHandlerQuake(Handle:menu, MenuAction:action, param1, param2) {

	if(action == MenuAction_Select)	
	{
		if(iEvent_Sound || iQuake_Sound || iOverlays) {
			new key = -1;
			if(iQuake_Sound) {
				key++;
				if(param2 == key) {
					if(iCookieConfigs[param1] & QUAKE) {
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Quake_Off");		
						iCookieConfigs[param1] -= QUAKE;
					} else {
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Quake_On");
						iCookieConfigs[param1] += QUAKE;
					}
				}
			}		
			if(iEvent_Sound) {
				key++;
				if(param2 == key) {
					if(iCookieConfigs[param1] & EVENT_SOUNDS) {
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Event_Off");
						iCookieConfigs[param1] -= EVENT_SOUNDS;
					} else {
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Event_On");
						iCookieConfigs[param1] += EVENT_SOUNDS;
					}
				}
			}
			if(iOverlays) {
				key++;
				if(param2 == key) {
					if(iCookieConfigs[param1] & OVERLAYS) {
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Overlays_Off");			
						iCookieConfigs[param1] -= OVERLAYS;
					} else { 
						if(iCookieConfigs[param1] & MESSAGE) CPrintToChat(param1, "%t", "Message_Overlays_On");		
						iCookieConfigs[param1] += OVERLAYS;
					}
				}
			}
			key++;
			if(param2 == key) {
				if(iCookieConfigs[param1] & MESSAGE) {
					iCookieConfigs[param1] -= MESSAGE;
				} else { 
					iCookieConfigs[param1] += MESSAGE;
				}
			}
			new String:buffer[10];
			IntToString(iCookieConfigs[param1], buffer, 10);
			SetClientCookie(param1, hClientCookie, buffer);
			ShowQuakeMenu(param1);
		}
	} 
	else if(action == MenuAction_End) CloseHandle(menu);
}

/* ----------	Include is smlib	---------- */

// Надеть Оверлай
stock Client_SetOverlay(client, const String:path[]) ClientCommand(client, "r_screenoverlay \"%s.vtf\"", path);

// Очистить Оверлай
stock Client_ClearOverlay(client) ClientCommand(client, "r_screenoverlay \"\"");

/* ----------	Start author Riko	---------- */
bool:CheckMapEnd()
{
	new bool:lastround = false;
	new bool:notimelimit = false;
	new timeleft;
	
	if (GetMapTimeLeft(timeleft))
	{
		new timelimit;
		if (timeleft > 0) return false;
		else if (GetMapTimeLimit(timelimit) && !timelimit) notimelimit = true;
		else lastround = true;
	}
	
	if (!lastround)
	{
		if (g_Cvar_WinLimit != INVALID_HANDLE)
		{
			new winlimit = GetConVarInt(g_Cvar_WinLimit);
			if (winlimit > 0)
			{
				if (GetTeamScore(2) >= winlimit || GetTeamScore(3) >= winlimit) lastround = true;
			}
		}
		
		if (g_Cvar_MaxRounds != INVALID_HANDLE)
		{
			new maxrounds = GetConVarInt(g_Cvar_MaxRounds);
			
			if (maxrounds > 0)
			{
				new remaining = maxrounds - iNumberRounds;	
				if (!remaining) lastround = true;
			}		
		}
	}
	
	if (lastround) return true;
	else if (notimelimit) return false;
	return true;
}
/* ----------	End author Riko	---------- */


public bool:bNunbEventSound(event) {
	if(event == R_END ||
		event == R_START ||
		event == JOIN ||
		event == M_END ||
		event == VOTE_END ||
		event == VOTE_START) return true;
	return false;
}

public bool:ThisGrenade(String:weapon[]) {
	if(Game == CSS) { 
		if(StrEqual(weapon, "hegrenade") || 
			StrEqual(weapon, "smokegrenade") || 
			StrEqual(weapon, "flashbang")) return true;
		
	} else if(Game == CSGO){
		if(StrEqual(weapon,"inferno") || 
			StrEqual(weapon,"hegrenade") || 
			StrEqual(weapon,"flashbang") || 
			StrEqual(weapon,"decoy") || 
			StrEqual(weapon,"smokegrenade")) return true;
	}
	return false;
}

public bool:ThisKnife(String:weapon[]) {
	if(Game == CSS) { 
		if(StrEqual(weapon, "knife")) 
		return true;
	
	} else if(Game == CSGO){
		if(StrEqual(weapon,"knife_default_ct") ||
			StrEqual(weapon,"knife_default_t") || 
			StrEqual(weapon,"knifegg") || 
			StrEqual(weapon,"knife_flip") || 
			StrEqual(weapon,"knife_gut") || 
			StrEqual(weapon,"knife_karambit") || 
			StrEqual(weapon,"bayonet") || 
			StrEqual(weapon,"knife_m9_bayonet")) return true;
	}
	return false;
}

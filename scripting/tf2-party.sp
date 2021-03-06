/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] Party"
#define PLUGIN_DESCRIPTION "Drixevel, Grizzly Berry"
#define PLUGIN_VERSION "1.0.0"

#define MAX_COINS 1024

/*****************************/
//Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <misc-colors>
#include <cbasenpc>
#include <cbasenpc/util>

/*****************************/
//ConVars

/*****************************/
//Globals

char sModels[10][PLATFORM_MAX_PATH] =
{
	"",
	"models/player/scout.mdl",
	"models/player/sniper.mdl",
	"models/player/soldier.mdl",
	"models/player/demo.mdl",
	"models/player/medic.mdl",
	"models/player/heavy.mdl",
	"models/player/pyro.mdl",
	"models/player/spy.mdl",
	"models/player/engineer.mdl"
};

enum struct Coins
{
	int coins;

	void SetCoins(int coins)
	{
		this.coins = coins;

		if (this.coins < 0)
			this.coins = 0;
		else if (this.coins > MAX_COINS)
			this.coins = MAX_COINS;
	}

	bool AddCoins(int coins, bool force = false)
	{
		this.coins += coins;

		if (this.coins > MAX_COINS)
		{
			if (force)
				this.coins = MAX_COINS;
			
			return false;
		}

		return true;
	}

	bool RemoveCoins(int coins, bool force = false)
	{
		this.coins -= coins;

		if (this.coins < 0)
		{
			if (force)
				this.coins = 0;
			
			return false;
		}

		return true;
	}
}

Coins g_Coins[MAXPLAYERS + 1];

PathFollower pPath[MAX_NPCS];

enum struct Pawn
{
	CBaseNPC npc;

	void Init()
	{
		this.npc = INVALID_NPC;
	}

	void Clear()
	{
		this.npc = INVALID_NPC;
	}

	void Spawn(float origin[3])
	{
		this.npc = new CBaseNPC();

		CBaseCombatCharacter npcEntity = CBaseCombatCharacter(this.npc.GetEntity());
		npcEntity.Spawn();
		npcEntity.Teleport(origin);
		npcEntity.SetModel(sModels[1]);

		SDKHook(npcEntity.iEnt, SDKHook_Think, Hook_NPCThink);

		this.npc.flStepSize = 18.0;
		this.npc.flGravity = 800.0;
		this.npc.flAcceleration = 4000.0;
		this.npc.flJumpHeight = 85.0;
		this.npc.flWalkSpeed = 300.0;
		this.npc.flRunSpeed = 300.0;
		this.npc.flDeathDropHeight = 2000.0;
		
		float vecMins[3] = {-1.0, -1.0, 0.0};
		float vecMaxs[3] = {1.0, 1.0, 90.0};
		this.npc.SetBodyMins(vecMins);
		this.npc.SetBodyMaxs(vecMaxs);
		
		int iSequence = npcEntity.SelectWeightedSequence(ACT_MP_STAND_MELEE);
		if (iSequence != -1)
		{
			npcEntity.ResetSequence(iSequence);
			SetEntPropFloat(npcEntity.iEnt, Prop_Data, "m_flCycle", 0.0);
		}
	}

	void Teleport(float origin[3])
	{
		CBaseCombatCharacter(this.npc.GetEntity()).Teleport(origin);
	}

	void Delete()
	{
		AcceptEntityInput(this.npc.GetEntity(), "Kill");
		this.npc = INVALID_NPC;
	}

	void Move(float origin[3])
	{
		pPath[this.npc.Index].ComputeToPos(this.npc.GetBot(), origin, 9999999999.0);
		pPath[this.npc.Index].SetMinLookAheadDistance(300.0);
	}
}

Pawn g_Pawn[MAXPLAYERS + 1];

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel, Grizzly Berry", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	//Fix a compile error, can't be bothered.
	if (TheNavMesh) { }

	LoadTranslations("common.phrases");

	CSetPrefix("{ancient}[{aliceblue}Party{ancient}]{honeydew}");

	RegConsoleCmd("sm_coins", Command_Coins, "Shows how many coins you have in chat.");
	RegAdminCmd("sm_setcoins", Command_SetCoins, ADMFLAG_ROOT, "Set your own coins or others coins.");

	RegAdminCmd("sm_spawnpawn", Command_SpawnPawn, ADMFLAG_ROOT, "Spawn a pawn on the map.");
	RegAdminCmd("sm_telepawn", Command_TelePawn, ADMFLAG_ROOT, "Teleport a pawn on the map.");
	RegAdminCmd("sm_teleportpawn", Command_TelePawn, ADMFLAG_ROOT, "Teleport a pawn on the map.");
	RegAdminCmd("sm_delpawn", Command_DelPawn, ADMFLAG_ROOT, "Delete a pawn on the map.");
	RegAdminCmd("sm_deletepawn", Command_DelPawn, ADMFLAG_ROOT, "Delete a pawn on the map.");
	RegAdminCmd("sm_movepawn", Command_MovePawn, ADMFLAG_ROOT, "Move a pawn on the map.");

	for (int i = 0; i < MAX_NPCS; i++)
		pPath[i] = PathFollower(_, Path_FilterIgnoreActors, Path_FilterOnlyActors);

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		if (g_Pawn[i].npc != INVALID_NPC)
			g_Pawn[i].Delete();
}

public void OnMapStart()
{
	for (int i = 1; i <= 9; i++)
		PrecacheModel(sModels[i]);
}

public Action Command_Coins(int client, int args)
{
	CPrintToChat(client, "You have %i coins.", g_Coins[client].coins);
	return Plugin_Handled;
}

public Action Command_SetCoins(int client, int args)
{
	int target = client;

	if (args > 1)
	{
		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArg(1, sTarget, sizeof(sTarget));
		target = FindTarget(client, sTarget, false, false);

		if (target == -1)
		{
			CPrintToChat(client, "Target %s not found, please try again.", sTarget);
			return Plugin_Handled;
		}
	}

	char sAmount[32];
	GetCmdArg((args > 1) ? 2 : 1, sAmount, sizeof(sAmount));
	int amount = StringToInt(sAmount);

	g_Coins[target].SetCoins(amount);

	if (client == target)
		CPrintToChat(client, "You have set your own coins to %i.", g_Coins[target].coins);
	else
	{
		CPrintToChat(client, "You have set %N's coins to %i.", target, g_Coins[target].coins);
		CPrintToChat(target, "%N has set your coins to %i.", client, g_Coins[target].coins);
	}

	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_Pawn[client].Init();
}

public void OnClientDisconnect_Post(int client)
{
	g_Pawn[client].Clear();
}

public void Hook_NPCThink(int iEnt)
{
	CBaseNPC npc = TheNPCs.FindNPCByEntIndex(iEnt);

	if (npc != INVALID_NPC)
	{
		INextBot bot = npc.GetBot();
		NextBotGroundLocomotion loco = npc.GetLocomotion();
		
		float vecNPCPos[3];
		bot.GetPosition(vecNPCPos);

		float vecNPCAng[3];
		GetEntPropVector(iEnt, Prop_Data, "m_angAbsRotation", vecNPCAng);

		loco.Run();
		
		int iSequence = GetEntProp(iEnt, Prop_Send, "m_nSequence");

		CBaseCombatCharacter animationEntity = CBaseCombatCharacter(iEnt);
		
		static int sequence_ilde = -1;
		if (sequence_ilde == -1) sequence_ilde = animationEntity.SelectWeightedSequence(ACT_MP_STAND_MELEE);
		
		static int sequence_air_walk = -1;
		if (sequence_air_walk == -1) sequence_air_walk = animationEntity.SelectWeightedSequence(ACT_MP_JUMP_FLOAT_MELEE);
		
		static int sequence_run = -1;
		if (sequence_run == -1) sequence_run = animationEntity.SelectWeightedSequence(ACT_MP_RUN_MELEE);
		
		int iPitch = animationEntity.LookupPoseParameter("body_pitch");
		int iYaw = animationEntity.LookupPoseParameter("body_yaw");
		float vecDir[3], vecAng[3], vecNPCCenter[3];
		animationEntity.WorldSpaceCenter(vecNPCCenter);
		NormalizeVector(vecDir, vecDir);
		GetVectorAngles(vecDir, vecAng); 
		
		float flPitch = animationEntity.GetPoseParameter(iPitch);
		float flYaw = animationEntity.GetPoseParameter(iYaw);
		
		vecAng[0] = UTIL_Clamp(UTIL_AngleNormalize(vecAng[0]), -44.0, 89.0);
		animationEntity.SetPoseParameter(iPitch, UTIL_ApproachAngle(vecAng[0], flPitch, 1.0));
		vecAng[1] = UTIL_Clamp(-UTIL_AngleNormalize(UTIL_AngleDiff(UTIL_AngleNormalize(vecAng[1]), UTIL_AngleNormalize(vecNPCAng[1]+180.0))), -44.0,  44.0);
		animationEntity.SetPoseParameter(iYaw, UTIL_ApproachAngle(vecAng[1], flYaw, 1.0));
		
		int iMoveX = animationEntity.LookupPoseParameter("move_x");
		int iMoveY = animationEntity.LookupPoseParameter("move_y");
		
		if (iMoveX < 0 || iMoveY < 0)
			return;
		
		float flGroundSpeed = loco.GetGroundSpeed();

		if (flGroundSpeed != 0.0)
		{
			if (!(GetEntityFlags(iEnt) & FL_ONGROUND))
			{
				if (iSequence != sequence_air_walk)
					animationEntity.ResetSequence(sequence_air_walk);
			}
			else
			{			
				if (iSequence != sequence_run)
					animationEntity.ResetSequence(sequence_run);
			}
			
			float vecForward[3], vecRight[3], vecUp[3];
			animationEntity.GetVectors(vecForward, vecRight, vecUp);

			float vecMotion[3];
			loco.GetGroundMotionVector(vecMotion);

			float newMoveX = (vecForward[1] * vecMotion[1]) + (vecForward[0] * vecMotion[0]) +  (vecForward[2] * vecMotion[2]);
			float newMoveY = (vecRight[1] * vecMotion[1]) + (vecRight[0] * vecMotion[0]) + (vecRight[2] * vecMotion[2]);
			
			animationEntity.SetPoseParameter(iMoveX, newMoveX);
			animationEntity.SetPoseParameter(iMoveY, newMoveY);
		}
		else
		{
			if (iSequence != sequence_ilde)
				animationEntity.ResetSequence(sequence_ilde);
		}
	}
}

public Action Command_SpawnPawn(int client, int args)
{
	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	TR_GetEndPosition(endPos, hTrace);
	delete hTrace;

	g_Pawn[client].Spawn(endPos);
	CPrintToChat(client, "Pawn has been spawned.");

	return Plugin_Handled;
}

public Action Command_TelePawn(int client, int args)
{
	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	TR_GetEndPosition(endPos, hTrace);
	delete hTrace;

	g_Pawn[client].Teleport(endPos);
	CPrintToChat(client, "Pawn has been teleported.");

	return Plugin_Handled;
}

public Action Command_DelPawn(int client, int args)
{
	g_Pawn[client].Delete();
	CPrintToChat(client, "Pawn has been deleted.");
	return Plugin_Handled;
}

public Action Command_MovePawn(int client, int args)
{
	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	Handle hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	TR_GetEndPosition(endPos, hTrace);
	delete hTrace;

	endPos[2] += 10.0;
	g_Pawn[client].Move(endPos);
	CPrintToChat(client, "Pawn has been moved.");

	return Plugin_Handled;
}

public bool TraceRayDontHitEntity(int entity,int mask,any data)
{
	if (entity == data) return false;
	if (entity != 0) return false;
	return true;
}
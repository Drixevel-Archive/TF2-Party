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

/*****************************/
//ConVars

/*****************************/
//Globals

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

	void AddCoins(int coins)
	{
		this.coins += coins;

		if (this.coins > MAX_COINS)
			this.coins = MAX_COINS;
	}

	void RemoveCoins(int coins)
	{
		this.coins -= coins;

		if (this.coins < 0)
			this.coins = 0;
	}
}

Coins g_Coins[MAXPLAYERS + 1];

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
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_coins", Command_Coins, "Shows how many coins you have in chat.");

	RegAdminCmd("sm_setcoins", Command_SetCoins, ADMFLAG_ROOT, "Set your own coins or others coins.");
}

public Action Command_Coins(int client, int args)
{
	PrintToChat(client, "You have %i coins.", g_Coins[client].coins);
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
			PrintToChat(client, "Target %s not found, please try again.", sTarget);
			return Plugin_Handled;
		}
	}

	char sAmount[32];
	GetCmdArg((args > 1) ? 2 : 1, sAmount, sizeof(sAmount));
	int amount = StringToInt(sAmount);

	g_Coins[target].SetCoins(amount);

	if (client == target)
		PrintToChat(client, "You have set your own coins to %i.", g_Coins[target].coins);
	else
	{
		PrintToChat(client, "You have set %N's coins to %i.", target, g_Coins[target].coins);
		PrintToChat(target, "%N has set your coins to %i.", client, g_Coins[target].coins);
	}

	return Plugin_Handled;
}
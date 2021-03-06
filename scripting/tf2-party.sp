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
	RegConsoleCmd("sm_coins", Command_Coins, "Shows how many coins you have in chat.");
}

public Action Command_Coins(int client, int args)
{
	PrintToChat(client, "You have %i coins.", g_Coins[client].coins);
	return Plugin_Handled;
}
// iSimple Gamemode MySQL Roleplay //

// Include //
#include <a_samp>
#include <a_mysql>

// Define //
#define		MYSQL_HOST 			"127.0.0.1"
#define		MYSQL_USER 			"username"
#define		MYSQL_PASSWORD 		"password"
#define		MYSQL_DATABASE 		"database"

// Path //
#define     PLAYER_PATH         "players"

// Dialog //
#define DIALOG_UNUSED           0
#define DIALOG_REGISTER         1
#define DIALOG_LOGIN            2

// System //
#define GetOnlinePlayer(%0)     for (new %0 = 0, j = GetPlayerPoolSize(); %0 <= j; %0++)

// Global Variable //
new MySQL:handle;

// Enumerator //
enum pInfo_1
{
    // Save //
    pUser,
    pName[MAX_PLAYER_NAME],
	pPassword[65],
	pHash[17],
	pKills,
	pDeaths,
	Float:pX,
	Float:pY,
	Float:pZ,
	Float:pA,
	pInterior,
    pWorld,

    // Reset After Disconnect //
	Cache:pCache_ID,
	bool:pIsLoggedIn,
	pLoginAttempts,
	pLoginTimer
}

new PlayerInfo[MAX_PLAYERS][pInfo_1];

enum pInfo_2
{
    Race_Check
};

static MysqlInfo[MAX_PLAYERS][pInfo_2];

// Callback //
main(){}

public OnGameModeInit()
{
	new MySQLOpt:option = mysql_init_options();
	mysql_set_option(option, AUTO_RECONNECT, true);

	handle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, option);
	if(handle == MYSQL_INVALID_HANDLE || 
    mysql_errno(handle) != 0) SendRconCommand("exit");
	SetupPlayerTable();
	return 1;
}

public OnGameModeExit()
{
	GetOnlinePlayer(i)
	{
		if (IsPlayerConnected(i))
		{
			OnPlayerDisconnect(i, 1);
		}
	}
	mysql_close(handle);
	return 1;
}

public OnPlayerConnect(playerid)
{
    static const plr[pInfo_1];
    MysqlInfo[playerid][Race_Check] ++;
	PlayerInfo[playerid] = plr;
	GetPlayerName(playerid, PlayerInfo[playerid][pName], MAX_PLAYER_NAME);
	//
	new query[103];
	mysql_format(handle, query, sizeof query, "SELECT * FROM `"PLAYER_PATH"` WHERE `pName` = '%e' LIMIT 1", PlayerInfo[playerid][pName]);
	mysql_tquery(handle, query, "OnPlayerDataLoaded", "dd", playerid, MysqlInfo[playerid][Race_Check]);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	MysqlInfo[playerid][Race_Check] ++;
	UpdatePlayerData(playerid, reason);
	if(cache_is_valid(PlayerInfo[playerid][pCache_ID]))
	{
		cache_delete(PlayerInfo[playerid][pCache_ID]);
		PlayerInfo[playerid][pCache_ID] = MYSQL_INVALID_CACHE;
	}
	if (PlayerInfo[playerid][pLoginTimer])
	{
		KillTimer(PlayerInfo[playerid][pLoginTimer]);
		PlayerInfo[playerid][pLoginTimer] = 0;
	}
	PlayerInfo[playerid][pIsLoggedIn] = false;
	return 1;
}

public OnPlayerSpawn(playerid)
{
	SetPlayerInterior(playerid, PlayerInfo[playerid][pInterior]);
    SetPlayerVirtualWorld(playerid, PlayerInfo[playerid][pWorld]);
	SetPlayerPos(playerid, PlayerInfo[playerid][pX], PlayerInfo[playerid][pY], PlayerInfo[playerid][pZ]);
	SetPlayerFacingAngle(playerid, PlayerInfo[playerid][pA]);
	SetCameraBehindPlayer(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	UpdatePlayerDeaths(playerid);
	UpdatePlayerKills(killerid);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch (dialogid)
	{
		case DIALOG_UNUSED: return 1;
		case DIALOG_LOGIN:
		{
			if(!response) 
                return Kick(playerid);
            //
			new hash[65];
			SHA256_PassHash(inputtext, PlayerInfo[playerid][pHash], hash, 65);

			if (strcmp(hash, PlayerInfo[playerid][pPassword]) == 0)
			{
				ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have been successfully logged in.", "Okay", "");
				cache_set_active(PlayerInfo[playerid][pCache_ID]);
				AssignPlayerData(playerid);
				cache_delete(PlayerInfo[playerid][pCache_ID]);
				PlayerInfo[playerid][pCache_ID] = MYSQL_INVALID_CACHE;
				KillTimer(PlayerInfo[playerid][pLoginTimer]);
				PlayerInfo[playerid][pLoginTimer] = 0;
				PlayerInfo[playerid][pIsLoggedIn] = true;
				SetSpawnInfo(playerid, NO_TEAM, 0, PlayerInfo[playerid][pX], PlayerInfo[playerid][pY], PlayerInfo[playerid][pZ], PlayerInfo[playerid][pA], 0, 0, 0, 0, 0, 0);
				SpawnPlayer(playerid);
			}
			else
			{
				PlayerInfo[playerid][pLoginAttempts]++;
				if(PlayerInfo[playerid][pLoginAttempts] >= 3)
				{
					ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have mistyped your password too often (3 times).", "Okay", "");
					DelayedKick(playerid);
				}
				else ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Wrong password!\nPlease enter your password in the field below:", "Login", "Abort");
			}
		}
		case DIALOG_REGISTER:
		{
			if(!response) 
                return Kick(playerid);
			if (strlen(inputtext) <= 5) 
                return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", "Your password must be longer than 5 characters!\nPlease enter your password in the field below:", "Register", "Abort");
            //
			for (new i = 0; i < 16; i++) PlayerInfo[playerid][pHash][i] = random(94) + 33;
			SHA256_PassHash(inputtext, PlayerInfo[playerid][pHash], PlayerInfo[playerid][pPassword], 65);

			new query[221];
			mysql_format(handle, query, sizeof query, "INSERT INTO `"PLAYER_PATH"` (`pName`, `pPassword`, `pHash`) VALUES ('%e', '%s', '%e')", PlayerInfo[playerid][pName], PlayerInfo[playerid][pPassword], PlayerInfo[playerid][pHash]);
			mysql_tquery(handle, query, "OnPlayerRegister", "d", playerid);
		}
		default: return 0;
	}
	return 1;
}

// Function //
forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
	if (race_check != MysqlInfo[playerid][Race_Check]) 
        return Kick(playerid);
    //
	new string[115];
	if(cache_num_rows() > 0)
	{
		cache_get_value(0, "pPassword", PlayerInfo[playerid][pPassword], 65);
		cache_get_value(0, "pHash", PlayerInfo[playerid][pHash], 17);
		PlayerInfo[playerid][pCache_ID] = cache_save();

		format(string, sizeof string, "This account (%s) is registered. Please login by entering your password in the field below:", PlayerInfo[playerid][pName]);
		ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Abort");
		PlayerInfo[playerid][pLoginTimer] = SetTimerEx("OnLoginTimeout", 30 * 1000, false, "d", playerid);
	}
	else
	{
		format(string, sizeof string, "Welcome %s, you can register by entering your password in the field below:", PlayerInfo[playerid][pName]);
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", string, "Register", "Abort");
	}
	return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
	PlayerInfo[playerid][pLoginTimer] = 0;
	ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login", "You have been kicked for taking too long to login successfully to your account.", "Okay", "");
	DelayedKick(playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	PlayerInfo[playerid][pUser] = cache_insert_id();
	ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Registration", "Account successfully registered, you have been automatically logged in.", "Okay", "");
	PlayerInfo[playerid][pIsLoggedIn] = true;
	PlayerInfo[playerid][pX] = 1958.3783;
	PlayerInfo[playerid][pY] = 1343.1572;
	PlayerInfo[playerid][pZ] = 15.3746;
	PlayerInfo[playerid][pA] = 270.1425;
	SetSpawnInfo(playerid, NO_TEAM, 0, PlayerInfo[playerid][pX], PlayerInfo[playerid][pY], PlayerInfo[playerid][pZ], PlayerInfo[playerid][pA], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

forward _KickPlayerDelayed(playerid);
public _KickPlayerDelayed(playerid)
{
	Kick(playerid);
	return 1;
}

// Other //

AssignPlayerData(playerid)
{
	cache_get_value_int(0, "pUser", PlayerInfo[playerid][pUser]);
	cache_get_value_int(0, "pKills", PlayerInfo[playerid][pKills]);
	cache_get_value_int(0, "pDeaths", PlayerInfo[playerid][pDeaths]);
	cache_get_value_float(0, "pX", PlayerInfo[playerid][pX]);
	cache_get_value_float(0, "pY", PlayerInfo[playerid][pY]);
	cache_get_value_float(0, "pZ", PlayerInfo[playerid][pZ]);
	cache_get_value_float(0, "pA", PlayerInfo[playerid][pA]);
	cache_get_value_int(0, "pInterior", PlayerInfo[playerid][pInterior]);
    cache_get_value_int(0, "pWorld", PlayerInfo[playerid][pWorld]);
	return 1;
}

DelayedKick(playerid, time = 500)
{
	SetTimerEx("_KickPlayerDelayed", time, false, "d", playerid);
	return 1;
}

SetupPlayerTable()
{
	mysql_tquery(handle, "CREATE TABLE IF NOT EXISTS `"PLAYER_PATH"` (`pUser` int(11) NOT NULL AUTO_INCREMENT,`pName` varchar(24) NOT NULL,`pPassword` char(64) NOT NULL,`pHash` char(16) NOT NULL,`pKills` mediumint(8) NOT NULL DEFAULT '0',`pDeaths` mediumint(8) NOT NULL DEFAULT '0',`pX` float NOT NULL DEFAULT '0',`pY` float NOT NULL DEFAULT '0',`pZ` float NOT NULL DEFAULT '0',`pA` float NOT NULL DEFAULT '0',`pInterior` tinyint(3) NOT NULL DEFAULT '0', `pWorld` tinyint(3) NOT NULL DEFAULT '0', PRIMARY KEY (`pUser`), UNIQUE KEY `pName` (`pName`))");
	return 1;
}

UpdatePlayerData(playerid, reason)
{
	if(PlayerInfo[playerid][pIsLoggedIn] == false) 
        return 0;
    //
	if (reason == 1)
	{
		GetPlayerPos(playerid, PlayerInfo[playerid][pX], PlayerInfo[playerid][pY], PlayerInfo[playerid][pZ]);
		GetPlayerFacingAngle(playerid, PlayerInfo[playerid][pA]);
	}
	
	new query[145];
	mysql_format(handle, query, sizeof query, "UPDATE `"PLAYER_PATH"` SET `pX` = %f, `pY` = %f, `pZ` = %f, `pA` = %f, `pInterior` = %d WHERE `pUser` = %d LIMIT 1", PlayerInfo[playerid][pX], PlayerInfo[playerid][pY], PlayerInfo[playerid][pZ], PlayerInfo[playerid][pA], GetPlayerInterior(playerid), PlayerInfo[playerid][pUser]);
	mysql_tquery(handle, query);
	return 1;
}

UpdatePlayerDeaths(playerid)
{
	if (PlayerInfo[playerid][pIsLoggedIn] == false) 
        return 0;
    //
	PlayerInfo[playerid][pDeaths] ++;
	new query[70];
	mysql_format(handle, query, sizeof query, "UPDATE `"PLAYER_PATH"` SET `pDeaths` = %d WHERE `id` = %d LIMIT 1", PlayerInfo[playerid][pDeaths], PlayerInfo[playerid][pUser]);
	mysql_tquery(handle, query);
	return 1;
}

UpdatePlayerKills(killerid)
{
	if(killerid == INVALID_PLAYER_ID) return 0;
	if(PlayerInfo[killerid][pIsLoggedIn] == false) return 0;
	
	PlayerInfo[killerid][pKills]++;
	
	new query[70];
	mysql_format(handle, query, sizeof query, "UPDATE `"PLAYER_PATH"` SET `pKills` = %d WHERE `pUser` = %d LIMIT 1", PlayerInfo[killerid][pDeaths], PlayerInfo[killerid][pUser]);
	mysql_tquery(handle, query);
	return 1;
}

// Tamat //
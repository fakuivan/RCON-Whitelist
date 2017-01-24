#define REQUIRE_EXTENSIONS
#include <smrcon>
#undef REQUIRE_EXTENSIONS
#include <think_hooks>

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include "rcon_whitelist/rcon_whitelist.inc"

#define PLUGIN_VERSION "2.4"

public Plugin myinfo = 
{
	name = "RCON Whitelist",
	author = "fakuivan",
	description = "Restricts the IP addresses from which an RCON connection can be stablished",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/member.php?u=264797"
};

Handle gh_cache_addresses;
Database gh_db;
DBStatement gh_select_all;		//selects all of the addresses from the table "allowed"
DBStatement gh_select_by_state;	//selects all of the enabled/disabled addresses
DBStatement gh_select_by_id;	//selects an address by it's id
DBStatement gh_insert;			//insterts a new address into the database
DBStatement gh_switch;			//enables/disables an address given an id

bool gb_think_hooks_loaded = false;

public void OnPluginStart()
{
	LoadTranslations("rcon.whitelist.phrases");
	
	char s_error[255];
	gh_db = SQLite_UseDatabase(DB_NAME, s_error, sizeof(s_error));
	if (gh_db == INVALID_HANDLE)
	{
		SetFailState("%T", "connection_failed", LANG_SERVER, s_error);
	}

	
	char s_table_name[] = DB_TABLE_ALLOWED;
	bool b_table_exists = SQLite_TableExists(gh_db, s_table_name, sizeof(s_table_name));
	
	if (!b_table_exists)
	{
		LogMessage("%T", "couldnt_find_table_name", LANG_SERVER, s_table_name);
		LogMessage("%T", "creating_table", LANG_SERVER, s_table_name);
		
		if (!Make_Table(gh_db, s_error, sizeof(s_error)))
		{
			SetFailState("%T", "failed_to_create_table", LANG_SERVER, DB_TABLE_ALLOWED, s_error);
		}
		LogMessage("%T", "done", LANG_SERVER);
	}
	

	gh_select_all = SQL_PrepareQuery(gh_db, PREPARED_SELECT_ALL, s_error, sizeof(s_error));
	if (gh_select_all == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_prepare", LANG_SERVER, PREPARED_SELECT_ALL, s_error);
	}
	
	gh_select_by_state = SQL_PrepareQuery(gh_db, PREPARED_SELECT_STATE, s_error, sizeof(s_error));
	if (gh_select_by_state == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_prepare", LANG_SERVER, PREPARED_SELECT_STATE, s_error);
	}
	
	gh_select_by_id = SQL_PrepareQuery(gh_db, PREPARED_SELECT_BY_ID, s_error, sizeof(s_error));
	if (gh_select_by_id == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_prepare", LANG_SERVER, PREPARED_SELECT_BY_ID, s_error);
	}
	
	gh_insert = SQL_PrepareQuery(gh_db, PREPARED_INSERT, s_error, sizeof(s_error));
	if (gh_insert == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_prepare", LANG_SERVER, PREPARED_INSERT, s_error);
	}
	
	gh_switch = SQL_PrepareQuery(gh_db, PREPARED_SWITCH, s_error, sizeof(s_error));
	if (gh_switch == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_prepare", LANG_SERVER, PREPARED_SWITCH, s_error);
	}
	
	
	gh_cache_addresses = GetAddresses(false, s_error, sizeof(s_error));
	if (gh_cache_addresses == INVALID_HANDLE)
	{
		SetFailState("%T", "failed_to_get_addresses", LANG_SERVER, s_error);
	}


	if (!b_table_exists)
	{
		int i_default_loopback_ip[4] = RCONWL_DFLTL;
		RCONWh_InsertResult i_result;
		LogMessage("%T", "inserting_address", LANG_SERVER,	i_default_loopback_ip[0], 
															i_default_loopback_ip[1], 
															i_default_loopback_ip[2], 
															i_default_loopback_ip[3]);
		InsertAddress(i_default_loopback_ip, i_result, s_error, sizeof(s_error));
		if (i_result == InsertResult_Success)
		{
			LogMessage("%T", "done", LANG_SERVER);
		}
		else if (i_result == InsertResult_Failed_NotAnIP)
		{
			LogError("%T", "failed_to_insert_invalid_ip", LANG_SERVER,	i_default_loopback_ip[0], 
																		i_default_loopback_ip[1], 
																		i_default_loopback_ip[2], 
																		i_default_loopback_ip[3]);
		}
		else
		{
			LogError("%T", "failed_to_insert", LANG_SERVER, s_error);
		}
	}
	

	RegAdminCmd("sm_rconw_print_allowed", Command_GetAddresses, ADMFLAG_RCON, "Shows a list of the IP Addresses allowed to connect via RCON.");
	RegAdminCmd("sm_rconw_reload_db",     Command_ReloadDB,     ADMFLAG_RCON, "Reloads the RCON Whitelist cache."                            );
}
 
public void OnAllPluginsLoaded()
{
	gb_think_hooks_loaded = LibraryExists(THINK_HOOKS_LIB_NAME);
}
 
public void OnLibraryRemoved(const char[] s_name)
{
	if (StrEqual(s_name, THINK_HOOKS_LIB_NAME))
	{
		gb_think_hooks_loaded = false;
	}
}
 
public void OnLibraryAdded(const char[] s_name)
{
	if (StrEqual(s_name, THINK_HOOKS_LIB_NAME))
	{
		gb_think_hooks_loaded = true;
	}
}


//command callbacks//
public Action Command_GetAddresses(int i_client, int i_args)
{
	int i_address_buff[6];
	int i_size = GetArraySize(gh_cache_addresses);
	ReplyToCommand(i_client, "[SM] %t", "allowed_rcon");
	for (int i_index = 0; i_index < i_size; i_index++)
	{
		GetArrayArray(gh_cache_addresses, i_index, i_address_buff);
		ReplyToCommand(i_client, "[SM] %i) %i.%i.%i.%i",	i_address_buff[0], 
															i_address_buff[2], 
															i_address_buff[3], 
															i_address_buff[4], 
															i_address_buff[5]);
	}
	ReplyToCommand(i_client, "[SM] %t", "done");
	return Plugin_Handled;
}

public Action Command_ReloadDB(int i_client, int i_args)
{
	ReplyToCommand(i_client, "[SM] %t", "reloading_cache");
	char s_error[255];
	if (!ReloadCache(s_error, sizeof(s_error)))
	{
		ReplyToCommand(i_client, "[SM] %t", "failed_to_reload", s_error);
		return Plugin_Handled;
	}
	ReplyToCommand(i_client, "[SM] %t", "done");
	return Plugin_Handled;
}

//smrcon management//

public Action SMRCon_OnAuth(int i_rconid, const char[] s_address, const char[] s_password, bool &b_allow)
{
	int i_size = GetArraySize(gh_cache_addresses);
	int i_cache[6];
	int i_IP[4];
	StringIPToIntArray(i_IP, s_address);
	
	Handle h_data = CreateArray(4);
	PushArrayArray(h_data, i_IP);
	
	for (int i_index = 0; i_index < i_size; i_index++)
	{
		GetArrayArray(gh_cache_addresses, i_index, i_cache);
		if (i_IP[0] == i_cache[2] && // index 0 is the id, 1 is the enabled field
			i_IP[1] == i_cache[3] && 
			i_IP[2] == i_cache[4] && 
			i_IP[3] == i_cache[5] && 
			i_cache[1])
		{
			PushArrayCell(h_data, true);
			PushArrayCell(h_data, i_cache[0]);
			QueueNotify(h_data);
			return Plugin_Continue;
		}
	}
	PushArrayCell(h_data, false);
	QueueNotify(h_data);
	b_allow = false;
	return Plugin_Changed;
}

void QueueNotify(Handle h_data)
{
	if (gb_think_hooks_loaded)
	{
		RequestThink(Notify_OnNextGameFrame, h_data);
	}
	else if (IsServerProcessing())
	{
		//this is not going to work when the server is not generating frames
		RequestFrame(Notify_OnNextGameFrame, h_data);
	}
	else { Notify_OnNextGameFrame(h_data); }
}

/* We notify on the next frame because the output from the console is going to be
   replicated to the remote console attempting to get in on authentication, 
   you could call this a "security" enhancement because an "attacker" wouldn't 
   know if he actually knows the password or if he just got rejected */
void Notify_OnNextGameFrame(any i_data)
{
	Handle h_data = view_as<Handle>(i_data);
	
	int i_IP[4];
	GetArrayArray(h_data, 0, i_IP);			//the ip address itself
	char s_address[RCONWL_IP_ADDRESS_MAX_LENGTH];
	IntIPToString(i_IP, s_address);
	
	if (GetArrayCell(h_data, 1))			//if it passed
	{
		int i_id = GetArrayCell(h_data, 2);	//address id
		PrintToServer("[SM] %T", "allowed_connecting", LANG_SERVER, s_address, i_id);
		LogMessage("%T", "log_allowed_connecting", LANG_SERVER, s_address, i_id);
	}
	else
	{
		PrintToServer("[SM] %T", "disallowed_connecting", LANG_SERVER, s_address);
		LogMessage("%T", "log_disallowed_connecting", LANG_SERVER, s_address);
	}
	CloseHandle(h_data);
}

public APLRes AskPluginLoad2(Handle h_myself, bool b_late, char[] s_error, int i_err_max)
{
	CreateNative("RCONWh_GetAuthorizedIPAddresses",   NativeWarper_GetAuthorizedIPAddresses);
	CreateNative("RCONWh_AddAuthorizedIPAddress",     NativeWarper_AddAuthorizedIPAddress);
	CreateNative("RCONWh_DisableAuthorizedIPAddress", NativeWarper_DisableAuthorizedIPAddress);
	CreateNative("RCONWh_GetAddressInfoByID",         NativeWarper_GetAddressInfoByID);
	CreateNative("RCONWh_ReloadDB",                   NativeWarper_ReloadDB);
	RegPluginLibrary("rcon_whitelist");
	return APLRes_Success;
}

//db interfaces//

Handle GetAddresses(bool b_get_disabled = false, char[] s_error = NULL_STRING, int i_sizeof_error = 0)
{
	Handle h_array;
	DBStatement h_used;
	if (b_get_disabled)
	{
		if (!SQL_Execute(gh_select_all))
		{
			SQL_GetError(gh_select_all, s_error, i_sizeof_error);
			return INVALID_HANDLE;
		}
		h_used = gh_select_all;
	}
	else
	{
		SQL_BindParamInt(gh_select_by_state, 0, 1);
		if (!SQL_Execute(gh_select_by_state))
		{
			SQL_GetError(gh_select_by_state, s_error, i_sizeof_error);
			return INVALID_HANDLE;
		}
		h_used = gh_select_by_state;
	}
	int i_cache[6];
	h_array = CreateArray(6);
	while (SQL_FetchRow(h_used))
	{
		i_cache[0] = SQL_FetchInt(h_used, 0);
		i_cache[1] = SQL_FetchInt(h_used, 1);
		i_cache[2] = SQL_FetchInt(h_used, 2);
		i_cache[3] = SQL_FetchInt(h_used, 3);
		i_cache[4] = SQL_FetchInt(h_used, 4);
		i_cache[5] = SQL_FetchInt(h_used, 5);
		PushArrayArray(h_array, i_cache);
	}
	return h_array;
}

bool GetAddressDetails(int i_id, int i_details[6], RCONWh_InsertResult &i_result, char[] s_error = NULL_STRING, int i_sizeof_error = 0)
{
	SQL_BindParamInt(gh_select_by_id, 0, i_id);
	if (!SQL_Execute(gh_select_by_id))
	{
		SQL_GetError(gh_select_by_id, s_error, i_sizeof_error);
		i_result = InsertResult_Failed_GetID;
		return false;
	}
	i_result = InsertResult_Success;
	if (SQL_GetRowCount(gh_select_by_id) != 1)
	{
		return false;
	}
	while (SQL_FetchRow(gh_select_by_id))
	{
		i_details[0] = SQL_FetchInt(gh_select_by_id, 0);
		i_details[1] = SQL_FetchInt(gh_select_by_id, 1);
		i_details[2] = SQL_FetchInt(gh_select_by_id, 2);
		i_details[3] = SQL_FetchInt(gh_select_by_id, 3);
		i_details[4] = SQL_FetchInt(gh_select_by_id, 4);
		i_details[5] = SQL_FetchInt(gh_select_by_id, 5);
	}
	return true;
}

int InsertAddress(const int i_ip[4], RCONWh_InsertResult &i_result, char[] s_error = NULL_STRING, int i_sizeof_error = 0)
{
	if (IntArrayOutOfLimits(i_ip, 4, 0, 255))
	{
		i_result = InsertResult_Failed_NotAnIP;
		return RCONWL_INVALID_ID;
	}
	SQL_BindParamInt(gh_insert, 0, 1);
	SQL_BindParamInt(gh_insert, 1, i_ip[0]);
	SQL_BindParamInt(gh_insert, 2, i_ip[1]);
	SQL_BindParamInt(gh_insert, 3, i_ip[2]);
	SQL_BindParamInt(gh_insert, 4, i_ip[3]);
	if (!SQL_Execute(gh_insert))
	{
		SQL_GetError(gh_insert, s_error, i_sizeof_error);
		i_result = InsertResult_Failed_Insert;
		return RCONWL_INVALID_ID;
	}
	
	i_result = InsertResult_Success;
	return SQL_GetInsertId(gh_insert);
}

bool SwitchAddress(int i_id, bool b_enabled, char[] s_error = NULL_STRING, int i_sizeof_error = 0, RCONWh_InsertResult &i_result)
{
	SQL_BindParamInt(gh_select_by_id, 0, i_id);
	if (!SQL_Execute(gh_select_by_id))
	{
		SQL_GetError(gh_select_by_id, s_error, i_sizeof_error);
		i_result = InsertResult_Failed_GetID;
		return false;
	}
	if (SQL_GetRowCount(gh_select_by_id) <= 0)
	{
		i_result = InsertResult_Success;
		return false;
	}
	
	int i_enabled = b_enabled ? 1 : 0; //I hate ternaries tho :u
	SQL_BindParamInt(gh_switch, 0, i_enabled);
	SQL_BindParamInt(gh_switch, 1, i_id);
	if (!SQL_Execute(gh_switch))
	{
		i_result = InsertResult_Failed_GetID;
		SQL_GetError(gh_switch, s_error, i_sizeof_error);
		return false;
	}
	i_result = InsertResult_Success;
	return true;
}

bool ReloadCache(char[] s_error = NULL_STRING, int i_sizeof_error = 0)
{
	Handle h_array = GetAddresses(false, s_error, i_sizeof_error);
	if (h_array == INVALID_HANDLE)
	{
		return false;
	}
	CloseHandle(gh_cache_addresses);
	gh_cache_addresses = h_array;
	return true;
}

bool Make_Table(Database h_db, char[] s_error, int i_sizeof_error)
{
	if (!SQL_FastQuery(h_db, DB_STATEMENT_MAKE))
	{
		return !SQL_GetError(h_db, s_error, i_sizeof_error);
	}
	return true;
}

//native callacks//

//native Handle RCONWh_GetAuthorizedIPAddresses()
public int NativeWarper_GetAuthorizedIPAddresses(Handle h_plugin, int i_nof_params)
{
	char s_error[255];
	Handle h_array = GetAddresses(GetNativeCell(1), s_error, sizeof(s_error));
	if (h_array == INVALID_HANDLE)
	{
		ThrowNativeError(RCONWL_ERROR_CANT_EXECUTE, "%T", "failed_execute_query", LANG_SERVER, s_error);
	}
	int i_cloned_array = view_as<int>(CloneHandle(h_array, h_plugin));
	CloseHandle(h_array);
	return i_cloned_array;
}

//native int RCONWh_AddAuthorizedIPAddress(const int i_ip[4], RCONWh_InsertResult &i_result)
public int NativeWarper_AddAuthorizedIPAddress(Handle h_plugin, int i_nof_params)
{
	int i_ip[4];
	RCONWh_InsertResult i_result;
	char s_error[255];
	GetNativeArray(1, i_ip, sizeof(i_ip));
	int i_id = InsertAddress(i_ip, i_result, s_error, sizeof(s_error));
	if (i_result == InsertResult_Failed_NotAnIP)
	{
		return RCONWL_INVALID_ID;
	}
	else if (i_result == InsertResult_Success)
	{
		return i_id;
	}
	else
	{
		//PrintToServer("[SM-DEBUG] i_result = %i", i_result);
		ThrowNativeError(RCONWL_ERROR_CANT_EXECUTE, "%T", "failed_to_insert", LANG_SERVER, s_error);
	}
	return 0;
}

//native bool RCONWh_DisableAuthorizedIPAddress(int i_id)
public int NativeWarper_DisableAuthorizedIPAddress(Handle h_plugin, int i_nof_params)
{
	char s_error[255];
	RCONWh_InsertResult i_result;
	bool b_removed = SwitchAddress(GetNativeCell(1), false, s_error, sizeof(s_error), i_result);
	if (i_result == InsertResult_Success)
	{
		return view_as<int>(b_removed);
	}
	ThrowNativeError(RCONWL_ERROR_CANT_EXECUTE, "%T", "failed_to_disable", LANG_SERVER, s_error);
	return 0;
}

//native bool RCONWh_GetAddressInfoByID(int i_id, int i_address[6])
public int NativeWarper_GetAddressInfoByID(Handle h_plugin, int i_nof_params)
{
	char s_error[255];
	RCONWh_InsertResult i_result;
	int i_details[6];
	bool b_found = GetAddressDetails(GetNativeCell(1), i_details, i_result, s_error, sizeof(s_error));
	if (i_result == InsertResult_Success)
	{
		SetNativeArray(2, i_details, sizeof(i_details));	//I should throw an error when this fails... but w/e
		return view_as<int>(b_found);
	}
	ThrowNativeError(RCONWL_ERROR_CANT_EXECUTE, "%T", "failed_to_get_info", LANG_SERVER, s_error);
	return 0;
}

//native void RCONWh_ReloadDB()
public int NativeWarper_ReloadDB(Handle h_plugin, int i_nof_params)
{
	char s_error[255];
	if (!ReloadCache(s_error, sizeof(s_error)))
	{
		ThrowNativeError(RCONWL_ERROR_CANT_EXECUTE, "%T", "failed_to_reload", LANG_SERVER, s_error);
	}
	return 0;
}

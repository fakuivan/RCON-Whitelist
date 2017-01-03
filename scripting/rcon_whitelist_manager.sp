#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include "rcon_whitelist.inc"
#include "rcon_whitelist/rcon_whitelist_manager.inc"
#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION "1.03"

public Plugin myinfo = 
{
	name = "RCON Whitelist Manager",
	author = "fakuivan",
	description = "Manage the RCON Whitelist plugin. Add, remove and list addresses",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/member.php?u=264797"
};

Handle gh_adminmenu;

public void OnPluginStart()
{
	RegAdminCmd("sm_rconw_add",		Command_AddEntry,	ADMFLAG_RCON, "Add an address to the RCON Whitelist database.");
	RegAdminCmd("sm_rconw_disable",	Command_Disable,	ADMFLAG_RCON, 
		"Flags an address from the RCON Whitelist database as not being allowed to establish an RCON connection.");
	RegAdminCmd("sm_rconw_menu", 	Command_Menu,		ADMFLAG_RCON, "Shows the RCON Whitelist administration menu");
	
	LoadTranslations("rcon.whitelist.manager.phrases");
	
	
	Handle h_topmenu;
	if (LibraryExists("adminmenu") && ((h_topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(h_topmenu);
	}
}

//command callbacks

public Action Command_Menu(int i_client, int i_args)
{
	AdminMenu_ShowMenu(i_client, false);
	return Plugin_Handled;
}

public Action Command_AddEntry(int i_client, int i_args)
{
	if (i_args != 1)
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_command_usage", "sm_rconw_add <ip>"); 
		return Plugin_Handled;
	}
	char s_arg[RCONWL_IP_ADDRESS_MAX_LENGTH];
	GetCmdArg(1, s_arg, sizeof(s_arg));
	int i_IP[4];
	RegexError i_error;
	if (!RegexParseIP(s_arg, i_IP, i_error))	//:TODO: if i_error differs from REGEX_ERROR_NONE we should throw an error
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_command_add_invalid_ip");
		return Plugin_Handled;
	}
	Preform_Add(i_client, i_IP, GetCmdReplySource());
	return Plugin_Handled;
}

public Action Command_Disable(int i_client, int i_args)
{
	if (i_args != 1)
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_command_usage", "sm_rconw_disable <id>");
	}
	else
	{
		int i_id = GetCmdArgInt(1);
		Perform_Disable(i_client, i_id, GetCmdReplySource());
	}
	return Plugin_Handled;
}

//admin menu preparation

public void OnAdminMenuReady(Handle h_topmenu)
{
	//call me as many times as you want
	static bool sb_called = false;
	if (sb_called)
	{
		return;
	}
	sb_called = true;
	
	gh_adminmenu = h_topmenu;
	TopMenuObject h_server_commands = FindTopMenuCategory(gh_adminmenu, ADMINMENU_SERVERCOMMANDS);
	if (h_server_commands == INVALID_TOPMENUOBJECT)
	{
		//error, for some reason
		return;
	}
	
	AddToTopMenu(gh_adminmenu,			//admin menu handle
				"sm_rconw_add",			//unique identifier
				TopMenuObject_Item, 	//type
				AdminMenu_Handler, 		//topofbj handler
				h_server_commands, 		//server commands category
				"sm_rconw_add", 		//command used for overrides
				ADMFLAG_RCON);			//admin cheats flag
}

/**
 * This function is called when the client selects us from the menu or when the menu requests information about us.
 */
public void AdminMenu_Handler(	Handle h_topmenu, 
								TopMenuAction i_action,
								TopMenuObject i_topobj_id,
								int i_param,
								char[] s_buffer,
								int i_maxlength)
{
	if (i_action == TopMenuAction_DisplayOption)
	{
		Format(s_buffer, i_maxlength, "%T", "rconwl_menu_option_name", i_param);
	}
	else if (i_action == TopMenuAction_SelectOption)
	{
		AdminMenu_ShowMenu(i_param, true);
	}
}

//Option selection menu

void AdminMenu_ShowMenu(int i_client, bool b_from_adminmenu)
{
	Handle h_info = CreateArray();
	PushArrayCell(h_info, b_from_adminmenu);
	
	Menu h_menu = CreateMenu(MenuHandler_SelectOption);
	SetMenuTitle(h_menu, "%T:", "rconwl_menu_option_title", i_client);
	SetMenuExitBackButton(h_menu, b_from_adminmenu);
	
	char s_option[2];
	s_option[0] = view_as<char>(RCONWh_MenuOption_Disable);	AddTranslatedMenuItem(h_menu, s_option, ITEMDRAW_DEFAULT, "%T", "rconwl_menu_option_disable", i_client);
	s_option[0] = view_as<char>(RCONWh_MenuOption_Reload);	AddTranslatedMenuItem(h_menu, s_option, ITEMDRAW_DEFAULT, "%T", "rconwl_menu_option_reload" , i_client);
	s_option[0] = view_as<char>(RCONWh_MenuOption_List);	AddTranslatedMenuItem(h_menu, s_option, ITEMDRAW_DEFAULT, "%T", "rconwl_menu_option_list"   , i_client);
	AddHandleToMenuAsInvisibleItem(h_menu, h_info);
	
	DisplayMenu(h_menu, i_client, MENU_TIME_FOREVER);
}

public int MenuHandler_SelectOption(Menu h_menu, MenuAction i_action, int i_param1, int i_param2)
{
	switch(i_action)
	{
		case MenuAction_Select:
		{
			char s_info[2];
			GetMenuItem(h_menu, i_param2, s_info, sizeof(s_info));
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			bool b_from_adminmenu = GetArrayCell(h_info, 0);
			switch(s_info[0])
			{
				case RCONWh_MenuOption_Disable:
				{
					SelectForDisable_ShowMenu(i_param1, b_from_adminmenu);
				}
				case RCONWh_MenuOption_Reload:
				{
					Perform_DBReload(i_param1, SM_REPLY_TO_CHAT);
					AdminMenu_ShowMenu(i_param1, b_from_adminmenu);
				}
				case RCONWh_MenuOption_List:
				{
					ListAddresses_ShowMenu(i_param1, b_from_adminmenu);
				}
			}
		}
		case MenuAction_Cancel:
		{
			//if the client selected the back button, our topmenu handle is not invalid and if the client came from the admin menu. 
			if (i_param2 == MenuCancel_ExitBack && gh_adminmenu)
			{
				DisplayTopMenu(gh_adminmenu, i_param1, TopMenuPosition_LastCategory);	//we show the last position of the admin menu.
			}
		}
		case MenuAction_End:
		{
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			CloseHandle(h_info);
			CloseHandle(h_menu);
		}
	}
}

//List menu

void ListAddresses_ShowMenu(int i_client, bool b_from_adminmenu)
{
	Handle h_info = CreateArray();
	Handle h_addresses = RCONWh_GetAuthorizedIPAddresses();
	PushArrayCell(h_info, b_from_adminmenu);
	
	Menu h_menu = CreateMenu(MenuHandler_ListAddresses);
	SetMenuTitle(h_menu, "%T:", "rconwl_menu_list_title", i_client);
	SetMenuExitBackButton(h_menu, true);
	
	RCONWlManager_AddEnabledAddressesToMenu(h_menu, h_addresses, ITEMDRAW_DISABLED);
	CloseHandle(h_addresses);
	
	AddHandleToMenuAsInvisibleItem(h_menu, h_info);
		
	DisplayMenu(h_menu, i_client, MENU_TIME_FOREVER);
}

public int MenuHandler_ListAddresses(Menu h_menu, MenuAction i_action, int i_param1, int i_param2)
{
	switch(i_action)
	{
		case MenuAction_Select:
		{
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			bool b_from_adminmenu = GetArrayCell(h_info, 0);
			PrintToChat(i_param1, "[SM-BETA] Not a feature yet :'v");
			ListAddresses_ShowMenu(i_param1, b_from_adminmenu);
		}
		case MenuAction_Cancel:
		{
			if (i_param2 == MenuCancel_ExitBack)	//if the client selected the back button.
			{
				Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
				AdminMenu_ShowMenu(i_param1, GetArrayCell(h_info, 0)); 				//we show the first layer.
			}
		}
		case MenuAction_End:
		{
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			CloseHandle(h_info);
			CloseHandle(h_menu);
		}
	}
}

//Disable menu

void SelectForDisable_ShowMenu(int i_client, bool b_from_adminmenu)
{
	Handle h_info = CreateArray();
	Handle h_addresses = RCONWh_GetAuthorizedIPAddresses();
	PushArrayCell(h_info, b_from_adminmenu);
	
	Menu h_menu = CreateMenu(MenuHandler_SelectForDisable);
	SetMenuTitle(h_menu, "%T:", "rconwl_menu_disable_title", i_client);
	SetMenuExitBackButton(h_menu, true);
	
	RCONWlManager_AddEnabledAddressesToMenu(h_menu, h_addresses);
	CloseHandle(h_addresses);
	
	AddHandleToMenuAsInvisibleItem(h_menu, h_info);
		
	DisplayMenu(h_menu, i_client, MENU_TIME_FOREVER);
}

public int MenuHandler_SelectForDisable(Menu h_menu, MenuAction i_action, int i_param1, int i_param2)
{
	switch(i_action)
	{
		case MenuAction_Select:
		{
			char s_info[HANDLE_HEX_LENGTH];
			GetMenuItem(h_menu, i_param2, s_info, sizeof(s_info));
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			int i_id = StringToInt(s_info, 16);
			bool b_from_adminmenu = GetArrayCell(h_info, 0);
			DisableConfirm_ShowMenu(i_param1, i_id, b_from_adminmenu);
		}
		case MenuAction_Cancel:
		{
			if (i_param2 == MenuCancel_ExitBack)	//if the client selected the back button.
			{
				Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
				AdminMenu_ShowMenu(i_param1, GetArrayCell(h_info, 0)); 				//we show the first layer.
			}
		}
		case MenuAction_End:
		{
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			CloseHandle(h_info);
			CloseHandle(h_menu);
		}
	}
}

//Confirm disable menu

void DisableConfirm_ShowMenu(int i_client, int i_id, bool b_from_adminmenu)
{
	int i_info[6];
	if (!RCONWh_GetAddressInfoByID(i_id, i_info))
	{
		PrintToChat(i_client, "[SM] %t", "rconwl_menu_disable_failed_get_info", i_id);
		SelectForDisable_ShowMenu(i_client, true);
		return;
	}
	
	Handle h_info = CreateArray();
	PushArrayCell(h_info, i_id);
	PushArrayCell(h_info, b_from_adminmenu);
	
	Menu h_menu = CreateMenu(MenuHandler_DisableConfirm);
	SetMenuTitle(h_menu, "%T", "rconwl_menu_disable_confirm", i_client, i_id, i_info[2], i_info[3], i_info[4], i_info[5]);
	SetMenuExitBackButton(h_menu, true);
	char s_option[2];
	s_option[0] = view_as<char>(2);	AddTranslatedMenuItem(h_menu, s_option, ITEMDRAW_DEFAULT, "%T", "rconwl_yes", i_client);
	s_option[0] = view_as<char>(1);	AddTranslatedMenuItem(h_menu, s_option, ITEMDRAW_DEFAULT, "%T", "rconwl_no", i_client);
	AddHandleToMenuAsInvisibleItem(h_menu, h_info);
	
	DisplayMenu(h_menu, i_client, MENU_TIME_FOREVER);
}

public int MenuHandler_DisableConfirm(Menu h_menu, MenuAction i_action, int i_param1, int i_param2)
{
	switch(i_action)
	{
		case MenuAction_Select:
		{
			char s_info[2];
			GetMenuItem(h_menu, i_param2, s_info, sizeof(s_info));
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			int i_id = GetArrayCell(h_info, 0);
			bool b_from_adminmenu = GetArrayCell(h_info, 1);
			
			if (s_info[0] == 2)
			{
				Perform_Disable(i_param1, i_id, SM_REPLY_TO_CHAT);
			}
			
			SelectForDisable_ShowMenu(i_param1, b_from_adminmenu);
		}
		case MenuAction_Cancel:
		{	
			if (i_param2 == MenuCancel_ExitBack)	//if the client selected the back button.
			{
				Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
				SelectForDisable_ShowMenu(i_param1, GetArrayCell(h_info, 1)); //we show the second layer.
			}
		}
		case MenuAction_End:
		{
			Handle h_info = GetHandleFromInvisibleMenuItem(h_menu, true, 0);
			CloseHandle(h_info);
			CloseHandle(h_menu);
		}
	}
}

void Perform_DBReload(int i_client, ReplySource i_source)
{
	RCONWh_ReloadDB();
	LogMessage("%T", "rconwl_log_reload", LANG_SERVER, i_client);
	ReplySource i_orig = SetCmdReplySource(i_source);
	ReplyToCommand(i_client, "[SM] %t", "rconwl_notify_reload");
	SetCmdReplySource(i_orig);
}

bool Perform_Disable(int i_client, int i_id, ReplySource i_source)
{
	ReplySource i_orig = SetCmdReplySource(i_source);
	int i_info[6];
	bool b_exists = RCONWh_GetAddressInfoByID(i_id, i_info);
	bool b_could_disable = RCONWh_DisableAuthorizedIPAddress(i_info[0]);
	if (!b_exists)
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_menu_disable_notify_failed_dne", i_id);
		SetCmdReplySource(i_orig);
		return false;
	}
	if (!b_could_disable)
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_menu_disable_notify_failed_already_down", i_id);
		SetCmdReplySource(i_orig);
		return false;
	}
	ReplyToCommand(i_client, "[SM] %t", "rconwl_menu_disable_notify", i_info[2], i_info[3], i_info[4], i_info[5], i_info[0]);
	LogMessage("%T", "rconwl_log_disabled", LANG_SERVER, i_client, i_info[0], i_info[2], i_info[3], i_info[4], i_info[5]);
	Perform_DBReload(i_client, i_source);
	SetCmdReplySource(i_orig);
	return true;
}

int Preform_Add(int i_client, int i_IP[4], ReplySource i_source)
{
	ReplySource i_orig = SetCmdReplySource(i_source);
	int i_id = RCONWh_AddAuthorizedIPAddress(i_IP);
	if (i_id != RCONWL_INVALID_ID)
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_command_add_notify", i_id, i_IP[0], i_IP[1], i_IP[2], i_IP[3]);
		LogMessage("%T", "rconwl_log_added", LANG_SERVER, i_client, i_id, i_IP[0], i_IP[1], i_IP[2], i_IP[3]);
		Perform_DBReload(i_client, i_source);
	}
	else
	{
		ReplyToCommand(i_client, "[SM] %t", "rconwl_command_add_invalid_ip");
	}
	SetCmdReplySource(i_orig);
	return i_id;
}
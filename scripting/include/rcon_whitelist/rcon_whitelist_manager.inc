/*
**
*/
#if defined _RCON_WHITELIST_MANAGER_included
 #endinput
#endif
#define _RCON_WHITELIST_MANAGER_included
#include <regex>


#define IP_REGEX	"^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)[\\s]*$"

#define HANDLE_HEX_LENGTH			10
#define INT_DECIMAL_LENGTH			12

enum RCONWh_MenuOption
{
	RCONWh_MenuOption_Disable = 1,
	RCONWh_MenuOption_Reload,
	RCONWh_MenuOption_List
};

stock bool RegexParseIP(const char s_IP[16], int i_IP[4], RegexError &i_error)
{
	Regex h_ip_regex = CompileRegex(IP_REGEX, 0, "", 0, i_error);
	if (h_ip_regex == INVALID_HANDLE)
	{
		return false;
	}
	
	int i_matches = MatchRegex(h_ip_regex, s_IP, i_error);	//the error code here tells us about if the matching failed or if it just found nothing.
	if (i_matches == -1 || i_matches == 0)
	{
		return false;
	}
	
	char s_substring[4];
	GetRegexSubString(h_ip_regex, 1, s_substring, sizeof(s_substring));
	i_IP[0] = StringToInt(s_substring);
	GetRegexSubString(h_ip_regex, 2, s_substring, sizeof(s_substring));
	i_IP[1] = StringToInt(s_substring);
	GetRegexSubString(h_ip_regex, 3, s_substring, sizeof(s_substring));
	i_IP[2] = StringToInt(s_substring);
	GetRegexSubString(h_ip_regex, 4, s_substring, sizeof(s_substring));
	i_IP[3] = StringToInt(s_substring);
	return true;
}

stock int GetCmdArgInt(int argnum, int length = 12, int base = 10)
{
	char[] s_buffer = new char[length];
	GetCmdArg(argnum, s_buffer, length);
	return StringToInt(s_buffer, base);
}

stock bool AddHandleToMenuAsInvisibleItem(Handle h_menu, Handle h_info)
{
	char s_info[HANDLE_HEX_LENGTH];
	Format(s_info, sizeof(s_info), "%x", h_info);
	return AddMenuItem(h_menu, s_info, "", ITEMDRAW_IGNORE);
}

stock Handle GetHandleFromInvisibleMenuItem(Handle h_menu, bool b_last_position, int i_position, bool &b_success = false)
{
	char s_info[HANDLE_HEX_LENGTH];
	if (b_last_position)
	{
		i_position = GetMenuItemCount(h_menu) - 1;
	}
	b_success = GetMenuItem(h_menu, i_position, s_info, sizeof(s_info));
	return view_as<Handle>(StringToInt(s_info, 16));
}

stock bool AddTranslatedMenuItem(Handle h_menu, const char[] s_info, int i_style, char[] s_format , any ...)
{
	int i_len = 0;
	int i_written = 0;
	do
	{
		i_len += 255;
		char[] s_buffer = new char[i_len];
		i_written = VFormat(s_buffer, i_len, s_format, 5);
		if (i_written < (i_len - 1))
		{
			return AddMenuItem(h_menu, s_info, s_buffer, i_style);
		}
	} while (i_written >= (i_len - 1));
	return false;
}

stock void RCONWlManager_AddEnabledAddressesToMenu(Handle h_menu, Handle h_addresses, int i_style = ITEMDRAW_DEFAULT)
{
	int i_size = GetArraySize(h_addresses);
	int i_buffer[6];
	//Formats like "[i_id] i_IP"
	char s_buffer[RCONWL_IP_ADDRESS_MAX_LENGTH + 3 + INT_DECIMAL_LENGTH];
	char s_id[HANDLE_HEX_LENGTH];
	for (int i_index = 0; i_index < i_size; i_index++)
	{
		GetArrayArray(h_addresses, i_index, i_buffer);
		if (i_buffer[1] == 0)	//if this addres is disabled, we don't add it
		{
			continue;
		}
		Format(s_id, sizeof(s_id), "%x", i_buffer[0]);
		Format(s_buffer, sizeof(s_buffer), "%i.%i.%i.%i (%i)", i_buffer[2], i_buffer[3], i_buffer[4], i_buffer[5], i_buffer[0]);
		AddMenuItem(h_menu, s_id, s_buffer, i_style);
	}
}

stock int IntIPToString(const int i_IP[4], char s_buffer[RCONWL_IP_ADDRESS_MAX_LENGTH])
{
	return Format(s_buffer, sizeof(s_buffer), "%i.%i.%i.%i", i_IP[0], i_IP[1], i_IP[2], i_IP[3]);
}
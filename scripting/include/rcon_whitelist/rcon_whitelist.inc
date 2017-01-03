/*
**
*/
#if defined _RCON_WHITELIST_CORE_included
 #endinput
#endif
#define _RCON_WHITELIST_CORE_included

#define DB_NAME							"rcon-addresses"

#define PREPARED_SELECT_ALL				"SELECT * FROM allowed"
#define PREPARED_SELECT_STATE			"SELECT * FROM allowed WHERE enabled = ?"
#define PREPARED_SELECT_BY_ID			"SELECT * FROM allowed WHERE id = ?"
#define PREPARED_INSERT					"INSERT INTO allowed(enabled,address1,address2,address3,address4) VALUES (?,?,?,?,?)"
#define PREPARED_SWITCH					"UPDATE allowed SET enabled = ? WHERE id = ?"
#define RCONWL_IP_ADDRESS_MAX_LENGTH	16

#define RCONWL_INVALID_ID				-1

#define RCONWL_ERROR_CANT_EXECUTE		10001

enum RCONWh_InsertResult
{
	InsertResult_Success = 1,			
	InsertResult_Failed_NotAnIP,		//invalid, out of bounds ip address
	InsertResult_Failed_Insert,			//failed to insert the row
	InsertResult_Failed_GetID,			//
};

stock bool IntArrayOutOfLimits(int[] i_array, int i_size, int i_min, int i_max)
{
	for (int i_index; i_index < i_size; i_index++)
	{
		if (i_array[i_index] < i_min || i_array[i_index] > i_max)
		{
			return true;
		}
	}
	return false;
}

stock void StringIPToIntArray(int i_buffer[4], const char[] s_IP)
{
	char s_bytes[4][4];
	ExplodeString(s_IP, ".", s_bytes, 4, 4);
	i_buffer[0] = StringToInt(s_bytes[0]);
	i_buffer[1] = StringToInt(s_bytes[1]);
	i_buffer[2] = StringToInt(s_bytes[2]);
	i_buffer[3] = StringToInt(s_bytes[3]);
}

stock int IntIPToString(const int i_IP[4], char s_buffer[RCONWL_IP_ADDRESS_MAX_LENGTH])
{
	return Format(s_buffer, sizeof(s_buffer), "%i.%i.%i.%i", i_IP[0], i_IP[1], i_IP[2], i_IP[3]);
}
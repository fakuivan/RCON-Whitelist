/*
**
*/
#if defined _RCON_WHITELIST_CORE_included
 #endinput
#endif
#define _RCON_WHITELIST_CORE_included

#define DB_NAME							"sourcemod-local"

#define DB_TABLE_ALLOWED				"rconwl_allowed"

#define DB_COLUMN_ALLOWED_ID			"id"
#define DB_COLUMN_ALLOWED_ENABLED		"enabled"
#define DB_COLUMN_ALLOWED_ADDRESS1		"address1"
#define DB_COLUMN_ALLOWED_ADDRESS2		"address2"
#define DB_COLUMN_ALLOWED_ADDRESS3		"address3"
#define DB_COLUMN_ALLOWED_ADDRESS4		"address4"

#define PREPARED_SELECT_ALL				"SELECT * FROM "...DB_TABLE_ALLOWED
#define PREPARED_SELECT_STATE			"SELECT * FROM "...DB_TABLE_ALLOWED..." WHERE "...DB_COLUMN_ALLOWED_ENABLED..." = ?"
#define PREPARED_SELECT_BY_ID			"SELECT * FROM "...DB_TABLE_ALLOWED..." WHERE "...DB_COLUMN_ALLOWED_ENABLED..." = ?"
#define PREPARED_INSERT					"INSERT INTO "...DB_TABLE_ALLOWED..."("...DB_COLUMN_ALLOWED_ENABLED... \
																			","...DB_COLUMN_ALLOWED_ADDRESS1... \
																			","...DB_COLUMN_ALLOWED_ADDRESS2... \
																			","...DB_COLUMN_ALLOWED_ADDRESS3... \
																			","...DB_COLUMN_ALLOWED_ADDRESS4... \
																			") VALUES (?,?,?,?,?)"
#define PREPARED_SWITCH					"UPDATE "...DB_TABLE_ALLOWED...\
										" SET "...DB_COLUMN_ALLOWED_ENABLED..." = ? WHERE "...DB_COLUMN_ALLOWED_ID..." = ?"
										
#define DB_STATEMENT_MAKE				"CREATE TABLE `"...DB_TABLE_ALLOWED..."` ("..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ID..."`		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT CHECK(`"...DB_COLUMN_ALLOWED_ID..."` >= 1),"..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ENABLED..."`	BOOLEAN NOT NULL DEFAULT 0 CHECK (`"...DB_COLUMN_ALLOWED_ENABLED..."` IN (0,1)),"..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ADDRESS1..."`	INTEGER NOT NULL DEFAULT 0 CHECK(`"...DB_COLUMN_ALLOWED_ADDRESS1..."` <= 255 AND `"...DB_COLUMN_ALLOWED_ADDRESS1..."` >= 0),"..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ADDRESS2..."`	INTEGER NOT NULL DEFAULT 0 CHECK(`"...DB_COLUMN_ALLOWED_ADDRESS2..."` <= 255 AND `"...DB_COLUMN_ALLOWED_ADDRESS2..."` >= 0),"..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ADDRESS3..."`	INTEGER NOT NULL DEFAULT 0 CHECK(`"...DB_COLUMN_ALLOWED_ADDRESS3..."` <= 255 AND `"...DB_COLUMN_ALLOWED_ADDRESS3..."` >= 0),"..."\n"... \
	"`"...DB_COLUMN_ALLOWED_ADDRESS4..."`	INTEGER NOT NULL DEFAULT 0 CHECK(`"...DB_COLUMN_ALLOWED_ADDRESS4..."` <= 255 AND `"...DB_COLUMN_ALLOWED_ADDRESS4..."` >= 0)"..."\n"... \
");"
										
#define RCONWL_IP_ADDRESS_MAX_LENGTH	16

#define RCONWL_INVALID_ID				-1

#define RCONWL_DFLTL					{ 127, 0, 0, 1 }

#define RCONWL_ERROR_CANT_EXECUTE		10001

enum RCONWh_InsertResult
{
	InsertResult_Success = 1,			
	InsertResult_Failed_NotAnIP,		//invalid, out of bounds ip address
	InsertResult_Failed_Insert,			//failed to insert the row
	InsertResult_Failed_GetID,			//failed to fetch the insert id
};

stock bool IntArrayOutOfLimits(const int[] i_array, int i_size, int i_min, int i_max)
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

stock bool SQLite_TableExists(Database h_database, const char[] s_table_name, int i_sizeof_table_name)
{
	int i_sizeof_table_name_escaped = i_sizeof_table_name * 2 + 1;
	char[] s_table_name_escaped = new char[i_sizeof_table_name * 2 + 1];
	SQL_EscapeString(h_database, s_table_name, s_table_name_escaped, i_sizeof_table_name_escaped);
	
	int i_sizeof_query = 67 + i_sizeof_table_name_escaped;
	char[] s_query = new char[i_sizeof_query]; 
	Format(s_query, i_sizeof_query, "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='%s';" /*67 chars*/ , s_table_name_escaped);
	
	DBResultSet h_result = SQL_Query(h_database, s_query);
	bool b_table_exists;
	while (SQL_FetchRow(h_result))
	{
		b_table_exists = SQL_FetchInt(h_result, 0) != 0;
	}
	CloseHandle(h_result);
	return b_table_exists;
}

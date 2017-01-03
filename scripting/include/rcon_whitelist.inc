/*
**
*/
#if defined _RCON_WHITELIST_included
 #endinput
#endif
#define _RCON_WHITELIST_included

#define RCONWL_INVALID_ID				-1	/**< Not a valid Address ID */
#define RCONWL_IP_ADDRESS_MAX_LENGTH	16	/**< Max length needed to fit an IPv4 address into a string */

enum RCONWh_InsertResult
{
	InsertResult_Success = 1,			/**< Self explanatory */
	InsertResult_Failed_NotAnIP,		/**< Invalid, out of bounds ip address */
	InsertResult_Failed_Insert,			/**< Failed to insert the row */
	InsertResult_Failed_GetID			/**< Failed to get the id of the address */
};

/**
 * Returns an ADT Array loaded with arrays of integers.
 * Each array follows this structure:
 * 
 * [0]  : id of this address in the database.
 * [1]  : if it's enabled or not. if this b_disabled_too is set to false, this will allways be true.
 * [2:5]: bytes of this address.
 * 
 * @return 			ADT Array of addresses.
 */
native Handle RCONWh_GetAuthorizedIPAddresses(bool b_disabled_too = false);

/**
 * Adds an address to the whitelist database.
 * 
 * @param i_ip 		New IP, one byte by cell.
 * 
 * @return 			ID of the new address. RCONWL_INVALID_ID if not an IP.
 */
native int RCONWh_AddAuthorizedIPAddress(const int i_ip[4]);

/**
 * Removes (disables) an address from the whitelist database.
 * 
 * @note for security purposes, no entry should ever get deleted from the database.
 * 
 * @param i_ip			ID of the address.
 * @return				False if the id is not in the database.
 */
native bool RCONWh_DisableAuthorizedIPAddress(int i_id);

/**
 * Retrives info about an specific address.
 * This performs some queries to get data directly from the database, 
 * if you need to make a lot of calls to this function 
 * just use RCONWh_GetAuthorizedIPAddresses and cash the results.
 * 
 * [0]  : id of this address in the database.
 * [1]  : if it's enabled or not. if this b_disabled_too is set to false, this will allways be true
 * [2:5]: bytes of this address.
 * 
 * @param  i_id			ID of the address.
 * @param  i_info		Buffer to store the retrived data.
 * @return 				True if the the address exists
 */
native bool RCONWh_GetAddressInfoByID(int i_id, int i_info[6]);

/**
 * Reloads the internal cache
 * @note This will not be triggered by any of the natives above, is your responsibility to call this function when you make changes to the database.
 * 
 * @noreturn
 */
native void RCONWh_ReloadDB();


#if !defined REQUIRE_PLUGIN
public __pl_rcon_whitelist_SetNTVOptional()
{
	MarkNativeAsOptional("RCONWh_GetAuthorizedIPs");
	MarkNativeAsOptional("RCONWh_AddAuthorizedIP");
	MarkNativeAsOptional("RCONWh_DisableAuthorizedIP");
	MarkNativeAsOptional("RCONWh_GetAddressInfoByID");
	MarkNativeAsOptional("RCONWh_ReloadDB");
}
#endif

public SharedPlugin __pl_rcon_whitelist =
{
	name = "rcon_whitelist",
	file = "rcon_whitelist.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
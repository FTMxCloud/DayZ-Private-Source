#include "\@dayzcc\addons\dayz_server_config.hpp"

waituntil { !isnil "bis_fnc_init" };

BIS_MPF_remoteExecutionServer 	= { if ((_this select 1) select 2 == "JIPrequest") then { [nil, (_this select 1) select 0, "loc", rJIPEXEC, [any, any, "per", "execVM", "ca\Modules\Functions\init.sqf"]] call RE; }; };
BIS_Effects_Burn 				= {};

server_playerLogin 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerLogin.sqf";
server_playerSetup 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerSetup.sqf";
server_playerDied 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerDied.sqf";
server_playerHit 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerHit.sqf";
server_playerSync 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerSync.sqf";
server_publishObj 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_objectPublish.sqf";
server_deleteObj 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_objectDelete.sqf";
server_onPlayerDisconnect 	= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_playerDisconnect.sqf";
server_updateObject 		= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_objectUpdate.sqf";
server_updateNearbyObjects	= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_objectUpdateNearby.sqf";
server_spawnWreck 			= compile preprocessFileLineNumbers "\z\addons\dayz_server\compile\server_spawnWreck.sqf";

//onPlayerConnected 		"[_uid, _name] spawn server_onPlayerConnect;";
onPlayerDisconnected 		"[_uid, _name] call server_onPlayerDisconnect;";

check_publishobject = {
	private["_allowed", "_allowedObjects", "_object", "_playername"];
	
	_object = _this select 0;
	_playername = _this select 1;
	_allowedObjects = ["TentStorage", "tent2017", "Hedgehog_DZ", "Sandbag1_DZ", "BearTrap_DZ", "Wire_cat1", "Gate1_DZ", "LadderLarge", "LadderSmall", "Sandbag3_DZ", "Sandbag2_DZ", "Scaffolding", "HBarrier", "Wire2", "SandBagNest", "WatchTower", "DeerStand", "CamoNet"];
	_allowed = false;

	if ((typeOf _object) in _allowedObjects || !CheckObject) then {
		_allowed = true;
	} else {
		diag_log format ["DEBUG: Invalid object %1 by %2", _object, _playername];
	};
	
	_allowed
};

vehicle_handleInteract = {
	private ["_object"];

	_object = _this select 0;
	needUpdate_objects = needUpdate_objects - [_object];
	[_object, "all"] call server_updateObject;
};

vehicle_handleServerKilled = {
	private ["_unit", "_killer"];

	_unit = _this select 0;
	_killer = _this select 1;
	[_unit, "killed"] call server_updateObject;
	_unit removeAllMPEventHandlers "MPKilled";
	_unit removeAllEventHandlers "Killed";
	_unit removeAllEventHandlers "HandleDamage";
	_unit removeAllEventHandlers "GetIn";
	_unit removeAllEventHandlers "GetOut";
};

eh_localCleanup = {
	private ["_object"];

	_object = _this select 0;
	_object addEventHandler ["local", {
		if (_this select 1) then {
			private["_type", "_unit"];
			_unit = _this select 0;
			_type = typeOf _unit;
			 _myGroupUnit = group _unit;
 			_unit removeAllMPEventHandlers "mpkilled";
 			_unit removeAllMPEventHandlers "mphit";
 			_unit removeAllMPEventHandlers "mprespawn";
 			_unit removeAllEventHandlers "FiredNear";
			_unit removeAllEventHandlers "HandleDamage";
			_unit removeAllEventHandlers "Killed";
			_unit removeAllEventHandlers "Fired";
			_unit removeAllEventHandlers "GetOut";
			_unit removeAllEventHandlers "GetIn";
			_unit removeAllEventHandlers "Local";
			clearVehicleInit _unit;
			deleteVehicle _unit;
			deleteGroup _myGroupUnit;
			_unit = nil;
			diag_log ("CLEANUP: DELETED A " + str(_type) );
		};
	}];
};

zombie_findOwner = {
	private ["_unit"];

	_unit = _this select 0;
	diag_log ("CLEANUP: DELETE UNCONTROLLED ZOMBIE: " + (typeOf _unit) + " OF " + str(_unit) );

	deleteVehicle _unit;
};

server_hiveWrite = {
	private ["_data"];

	_data = "HiveExt" callExtension _this;
	//diag_log ("HIVE: WRITE: " + str(_data));
};

server_hiveReadWrite = {
	private["_key", "_resultArray", "_data"];

	_key = _this;
	_data = "HiveExt" callExtension _key;
	//diag_log ("HIVE: READ/WRITE: " + str(_data));
	_resultArray = call compile format ["%1", _data];

	_resultArray
};

server_characterSync = {
	private ["_characterID", "_playerPos", "_playerGear", "_playerBackp", "_medical", "_currentState", "_currentModel", "_key"];

	_characterID = _this select 0;	
	_playerPos = _this select 1;
	_playerGear = _this select 2;
	_playerBackp = _this select 3;
	_medical = _this select 4;
	_currentState = _this select 5;
	_currentModel = _this select 6;
	_key = format["CHILD:201:%1:%2:%3:%4:%5:%6:%7:%8:%9:%10:%11:%12:%13:%14:%15:%16:", _characterID, _playerPos, _playerGear, _playerBackp, _medical, false, false, 0, 0, 0, 0, _currentState, 0, 0, _currentModel, 0];
	_key call server_hiveWrite;
};

server_getDiff = {
	private ["_variable", "_object", "_vNew", "_vOld", "_result"];
	
	_variable 	= _this select 0;
	_object 	= _this select 1;
	_vNew 		= _object getVariable[_variable,0];
	_vOld 		= _object getVariable[(_variable + "_CHK"), _vNew];
	_result 	= 0;
	
	if (_vNew < _vOld) then {
		_vNew 	= _vNew + _vOld;
		_object getVariable[(_variable + "_CHK"), _vNew];
	} else {
		_result = _vNew - _vOld;
		_object setVariable[(_variable + "_CHK"), _vNew];
	};
	
	_result
};

server_getDiff2 = {
	private ["_variable", "_object", "_vNew", "_vOld", "_result"];
	
	_variable 	= _this select 0;
	_object 	= _this select 1;
	_vNew 		= _object getVariable[_variable,0];
	_vOld 		= _object getVariable[(_variable + "_CHK"),_vNew];
	_result 	= _vNew - _vOld;
	_object setVariable[(_variable + "_CHK"),_vNew];
	
	_result
};

dayz_objectUID = {
	private ["_position", "_dir", "_key", "_object"];
	
	_object 	= _this;
	_position 	= getPosATL _object;
	_dir 		= direction _object;
	_key 		= [_dir, _position] call dayz_objectUID2;
	
	_key
};

dayz_objectUID2 = {
	 private ["_position", "_dir", "_key"];
	
	_dir 		= _this select 0;
	_key 		= "";
	_position 	= _this select 1;
	
	{
		_x = _x * 10;
		if ( _x < 0 ) then { _x = _x * -10 };
		_key = _key + str(round(_x));
	} forEach _position;

	_key = _key + str(round(_dir));

	_key
};

dayz_recordLogin = {
	private ["_key"];
	_key = format["CHILD:103:%1:%2:%3:", _this select 0, _this select 1, _this select 2];
	_key call server_hiveWrite;
};
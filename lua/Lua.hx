package lua;

#if cpp
import cpp.Lib;
#elseif neko
import neko.Lib;
#elseif flash
import Lua as LuaAs3; // this Lua class is from crossbridge-lua.swc
#end

class Lua
{

	/**
	 * Creates a new lua vm state
	 */
	public function new()
	{
		handle = lua_create();
	}

	/**
	 * Get the version string from Lua
	 */
	public static var version(get, never):String;
	private inline static function get_version():String
	{
		return lua_get_version();
	}

	/**
	 * Loads lua libraries (base, debug, io, math, os, package, string, table)
	 * @param libs An array of library names to load
	 */
	public function loadLibs(libs:Array<String>):Void
	{
		lua_load_libs(handle, libs);
	}

	/**
	 * Defines variables in the lua vars
	 * @param vars An object defining the lua variables to create
	 */
	public function setVars(vars:Dynamic):Void
	{
		lua_load_context(handle, vars);
	}

	/**
	 * Runs a lua script
	 * @param script The lua script to run in a string
	 * @return The result from the lua script in Haxe
	 */
	public function execute(script:String):Dynamic
	{
		return lua_execute(handle, script, false);
	}
	
	/**
	 * Runs a lua file
	 * @param path The path of the lua file to run
	 * @return The result from the lua script in Haxe
	 */
	public function executeFile(path:String):Dynamic
	{
		return lua_execute(handle, path, true);
	}

	/**
	 * Calls a previously loaded lua function
	 * @param func The lua function name (globals only)
	 * @param args A single argument or array of arguments
	 */
	public function call(func:String, args:Dynamic):Dynamic
	{
		return lua_call_function(handle, func, args);
	}

	/**
	 * Convienient way to run a lua script in Haxe without loading any libraries
	 * @param script The lua script to run in a string
	 * @param vars An object defining the lua variables to create
	 * @return The result from the lua script in Haxe
	 */
	public static function run(script:String, ?vars:Dynamic):Dynamic
	{
		var lua = new Lua();
		lua.setVars(vars);
		return lua.execute(script);
	}
	/**
	 * Convienient way to run a lua file in Haxe without loading any libraries
	 * @param script The path of the lua file to run
	 * @param vars An object defining the lua variables to create
	 * @return The result from the lua script in Haxe
	 */
	public static function runFile(path:String, ?vars:Dynamic):Dynamic
	{
		var lua = new Lua();
		lua.setVars(vars);
		return lua.executeFile(path);
	}
	
	private var handle:Dynamic;

#if (cpp || neko)
	private static function load(func:String, numArgs:Int):Dynamic
	{
#if neko
		if (!moduleInit)
		{
			// initialize neko
			var init = Lib.load("lua", "neko_init", 5);
			if (init != null)
			{
				init(function(s) return new String(s), function(len:Int) { var r = []; if (len > 0) r[len - 1] = null; return r; }, null, true, false);
			}
			else
			{
				throw("Could not find NekoAPI interface.");
			}

			moduleInit = true;
		}
#end
		
		return Lib.load("lua", func, numArgs);
	}
	
	private static var lua_create = load("lua_create", 0);
	private static var lua_get_version = load("lua_get_version", 0);
	private static var lua_call_function = load("lua_call_function", 3);
	private static var lua_execute = load("lua_execute", 3);
	private static var lua_load_context = load("lua_load_context", 2);
	private static var lua_load_libs = load("lua_load_libs", 2);
	private static var moduleInit:Bool = false;
	
#elseif flash

	private static var funcs:Map<Int, Array<Dynamic>> = new Map();
	
	private static function lua_create():Int
	{
		// TODO: call lua_close() when this is gc-ed.
		return LuaAs3.luaL_newstate();
	}
	
	private static function release_lua(l:Int):Void
	{
		LuaAs3.lua_close(l);
		funcs.remove(l);
	}
	
	private static function lua_get_version():String
	{
		return LuaAs3.LUA_VERSION;
	}
	
	private static function lua_load_libs(handle:Int, libs:Array<String>):Void
	{
		for (lib in libs)
		{
			var open = switch (lib) 
			{
				case "base": LuaAs3.luaopen_base;
				case "debug": LuaAs3.luaopen_debug;
				case "io": LuaAs3.luaopen_io;
				case "math": LuaAs3.luaopen_math;
				case "os": LuaAs3.luaopen_os;
				case "package": LuaAs3.luaopen_package;
				case "string": LuaAs3.luaopen_string;
				case "table": LuaAs3.luaopen_table;
				case "coroutine": LuaAs3.luaopen_coroutine;
				default: null;
			}
			LuaAs3.luaL_requiref(handle, lib, open, 1);
			LuaAs3.lua_settop(handle, 0);
		}
	}
	
	private static function lua_execute(handle:Int, scriptOrFile:String, isFile:Bool):Dynamic
	{
		var v:Dynamic = null;
		var l = handle;
		
		if ((isFile ? luaL_dofile(l, scriptOrFile) : luaL_dostring(l, scriptOrFile)) == LuaAs3.LUA_OK)
		{
			var lua_v = 0;
			while ((lua_v = LuaAs3.lua_gettop(handle)) != 0)
			{
				v = lua_value_to_haxe(l, lua_v);
				LuaAs3.lua_pop(l, 1);
			}
		}
		else
		{
			v = LuaAs3.lua_tolstring(l, -1, 0);
			LuaAs3.lua_pop(l, 1);
		}
		return v;
	}
	
	private static function lua_value_to_haxe(l:Int, lua_v:Int)
	{
		var v:Dynamic = null;
		switch (LuaAs3.lua_type(l, lua_v)) 
		{
			case LuaAs3.LUA_TNIL:
				v = null;
				
			case LuaAs3.LUA_TNUMBER:
				var n = LuaAs3.lua_tonumberx(l, lua_v, 0);
				v = (n % 1 == 0) ? Std.int(n) : n;
				
			case LuaAs3.LUA_TTABLE:
				v = lua_table_to_haxe(l, lua_v);
				
			case LuaAs3.LUA_TSTRING:
				v = LuaAs3.lua_tolstring(l, lua_v, 0);
				
			case LuaAs3.LUA_TBOOLEAN:
				v = LuaAs3.lua_toboolean(l, lua_v);
				
			default: 
				trace('return value not supported');
				v = null;
				
		}
		return v;
	}
	
	private static function lua_table_to_haxe(l:Int, lua_v:Int)
	{
		var v:Dynamic;
		var field_count = 0;
		var array = true;
		
		LuaAs3.lua_pushnil(l);
		while (LuaAs3.lua_next(l, lua_v < 0 ? lua_v - 1 : lua_v) != 0)
		{
			if (LuaAs3.lua_type(l, -2) != LuaAs3.LUA_TNUMBER) array = false;
			else if (LuaAs3.lua_tonumberx(l, -2, 0) < 1 || LuaAs3.lua_tonumberx(l, -2, 0) % 1 != 0) array = false;
			
			field_count++;
			
			LuaAs3.lua_pop(l, 1);
		}
		
		if (array)
		{
			v = [];
			
			LuaAs3.lua_pushnil(l);
			while (LuaAs3.lua_next(l, lua_v < 0 ? lua_v - 1 : lua_v) != 0)
			{
				var index = Std.int(LuaAs3.lua_tonumberx(l, -2, 0) - 1);
				v[index] = lua_value_to_haxe(l, -1);
				
				LuaAs3.lua_pop(l, 1);
			}
			
		}
		else
		{
			v = { };
			
			LuaAs3.lua_pushnil(l);
			while (LuaAs3.lua_next(l, lua_v < 0 ? lua_v - 1 : lua_v) != 0)
			{
				switch(LuaAs3.lua_type(l, -2))
				{
					case LuaAs3.LUA_TSTRING:
						Reflect.setField(v, LuaAs3.lua_tolstring(l, -2, 0), lua_value_to_haxe(l, -1));
						
					case LuaAs3.LUA_TNUMBER:
						Reflect.setField(v, Std.string(LuaAs3.lua_tonumberx(l, -2, 0)), lua_value_to_haxe(l, -1));
						
					default:
						
				}
				
				LuaAs3.lua_pop(l, 1);
			}
		}
		return v;
	}
	
	private static function lua_load_context(l:Int, inContext:Dynamic):Void
	{
		if (inContext != null && Reflect.isObject(inContext))
		{
			for (field in Reflect.fields(inContext))
				haxe_iter_global(Reflect.field(inContext, field), field, l);
		}
	}
	
	private static function haxe_to_lua(v:Dynamic, l:Int):Int
	{
		if (v == null)
			LuaAs3.lua_pushnil(l);
		else if (Std.is(v, Bool))
			LuaAs3.lua_pushboolean(l, v);
		else if (Std.is(v, Float) || Std.is(v, Int))
			LuaAs3.lua_pushnumber(l, v);
		else if (Std.is(v, String))
			LuaAs3.lua_pushstring(l, v);
		else if (Reflect.isFunction(v))
		{
			if (funcs[l] == null)
				funcs[l] = [];
			
			funcs[l].push(v);
				
			LuaAs3.lua_pushnumber(l, funcs[l].length - 1);
			LuaAs3.lua_pushnumber(l, untyped v.length); // v.length gives the number of arguments
			LuaAs3.lua_pushcclosure(l, haxe_callback, 2);
		}
		else if (Std.is(v, Array))
			haxe_array_to_lua(v, l);
		else if (Reflect.isObject(v) || Reflect.isEnumValue(v))
		{
			LuaAs3.lua_createtable(l, 0, 0);
			for (field in Reflect.fields(v))
				haxe_iter_object(Reflect.field(v, field), field, l);
		}
		else if (Type.getClass(v) != null)
		{
			LuaAs3.lua_createtable(l, 0, 0);
			for (field in Type.getInstanceFields(Type.getClass(v)))
				haxe_iter_object(Reflect.getProperty(v, field), field, l);
		}
		return 1;
	}
	
	private static function haxe_array_to_lua(v:Dynamic, l:Int):Void
	{
		var arr:Array<Dynamic> = v;
		var size = arr.length;
		LuaAs3.lua_createtable(l, size, 0);
		for (i in 0...size)
		{
			LuaAs3.lua_pushnumber(l, i + 1);
			haxe_to_lua(arr[i], l);
			LuaAs3.lua_settable(l, -3);
		}
	}
	
	private static function haxe_callback(l:Int):Int
	{
		var num_args = LuaAs3.lua_gettop(l);
		var funcIndex = Std.int(LuaAs3.lua_tonumberx(l, lua_upvalueindex(1), 0));
		var root = funcs[l][funcIndex];
		var expected_args = Std.int(LuaAs3.lua_tonumberx(l, lua_upvalueindex(2), 0));
		if (num_args != expected_args)
			trace('Expected $expected_args arguements, received $num_args. The function is not called.');
		else
		{
			var args = [];
			for (i in 0...num_args)
				args[i] = lua_value_to_haxe(l, i + 1);
			var result = Reflect.callMethod(null, root, args);
			return haxe_to_lua(result, l);
		}
		
		return 0;
	}
	
	private static function haxe_iter_global(v:Dynamic, f:String, l:Int):Void
	{
		haxe_to_lua(v, l);
		LuaAs3.lua_setglobal(l, f);
	}
	
	private static function haxe_iter_object(v:Dynamic, f:String, l:Int):Void 
	{
		LuaAs3.lua_pushstring(l, f);
		haxe_to_lua(v, l);
		LuaAs3.lua_settable(l, -3);
	}
	
	private static function lua_call_function(l:Int, func:String, inArgs:Dynamic):Dynamic
	{
		LuaAs3.lua_getglobal(l, func);
		
		var numArgs = 1;
		if (Std.is(inArgs, Array))
		{
			var args:Array<Dynamic> = inArgs;
			numArgs = args.length;
			
			for (i in 0...numArgs)
				haxe_to_lua(args[i], l);
		}
		else
			haxe_to_lua(inArgs, l);
			
		if (LuaAs3.lua_pcallk(l, numArgs, 1, 0, 0, null) == 0)
		{
			var v = lua_value_to_haxe(l, -1);
			LuaAs3.lua_pop(l, 1);
			return v;
		}
		return null;
	}
	
	private static function lua_upvalueindex(i:Int):Int
	{
		//return LuaAs3.LUA_REGISTRYINDEX - i;
		return -1001000 - i;
	}
	
	private static function luaL_dofile(l:Int, filename:String):Int
	{
		var r = LuaAs3.luaL_loadfilex(l, filename, null);
		if (r != 0) 
			return r;
		return LuaAs3.lua_pcallk(l, 0, LuaAs3.LUA_MULTRET, 0, 0, null);
	}
	
	private static function luaL_dostring(l:Int, str:String):Int
	{
		var r = LuaAs3.luaL_loadstring(l, str);
		if (r != 0) 
			return r;
		return LuaAs3.lua_pcallk(l, 0, LuaAs3.LUA_MULTRET, 0, 0, null);
	}
#end

}

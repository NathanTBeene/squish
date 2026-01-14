# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

cmake_minimum_required ( VERSION 3.10...4.2 )
project ( squish VERSION 0.3.0 LANGUAGES NONE )
include ( cmake/dist.cmake )
include ( lua )

# Require Lua 5.2 or later
find_program ( LUA_EXECUTABLE lua REQUIRED )

# Verify Lua version
execute_process(
    COMMAND ${LUA_EXECUTABLE} -v
    OUTPUT_VARIABLE LUA_VERSION_STRING
    ERROR_VARIABLE LUA_VERSION_STRING
)
if(LUA_VERSION_STRING MATCHES "Lua 5\\.[01]")
    message(FATAL_ERROR "Lua 5.2 or later is required. Found: ${LUA_VERSION_STRING}")
endif()

# Squish itself
add_custom_target ( bootstrap ALL
    COMMAND ${LUA_EXECUTABLE} squish.lua -q
    COMMAND ${LUA_EXECUTABLE} squish -q gzip
    COMMAND ${LUA_EXECUTABLE} squish -q debug
    COMMAND ${LUA_EXECUTABLE} squish -q --with-minify --with-uglify --with-compile --with-virtual-io --with-gzip --with-debug
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

install_lua_executable ( squish ${CMAKE_CURRENT_SOURCE_DIR}/squish )
install_data ( README COPYRIGHT CHANGES )

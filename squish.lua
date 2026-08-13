#!/usr/bin/env lua

-- Initialise LuaRocks if present
pcall(require, "luarocks.require");

-- ----------------------------- OPTION PARSING ----------------------------- --

local short_opts = { v = "verbose", vv = "very_verbose", o = "output", q = "quiet", qq = "very_quiet", g = "debug" }
local opts = { use_http = false };

for _, opt in ipairs(arg) do
	if opt:match("^%-") then
		local name = opt:match("^%-%-?([^%s=]+)()")
		name = (short_opts[name] or name):gsub("%-+", "_");
		if name:match("^no_") then
			name = name:sub(4, -1);
			opts[name] = false;
		else
			opts[name] = opt:match("=(.*)$") or true;
		end
	else
		base_path = opt;
	end
end

if opts.very_verbose then opts.verbose = true; end
if opts.very_quiet then opts.quiet = true; end

local function setup_prints(opts)
    local noprint = function () end
    local print_err, print_info, print_verbose, print_debug = noprint, noprint, noprint, noprint;

    if not opts.very_quiet then print_err = print; end
    if not opts.quiet then print_info = print; end
    if opts.verbose or opts.very_verbose then print_verbose = print; end
    if opts.very_verbose then print_debug = print; end

    -- Set globals for modules that use them
    _G.print_err = print_err;
    _G.print_info = print_info;
    _G.print_verbose = print_verbose;
    _G.print_debug = print_debug;
    _G.opts = opts;

    -- Return Locals for use in this scope
    return print_err, print_info, print_verbose, print_debug;
end

-- Initial print setup for early errors
local print_err, print_info, print_verbose, print_debug = setup_prints(opts);

local modules, main_files, resources = {}, {}, {};
local builds = {} -- store builds for multi-output squishy files

-- -------------------------- SQUISHY API FUNCTIONS ------------------------- --

local function shallow_copy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v;
    end
    return copy;
end

function Build()
    -- Snapshot current state
    table.insert(builds, {
        -- All options are carried over to next build except output filename
        modules = shallow_copy(modules),
        main_files = shallow_copy(main_files),
        resources = shallow_copy(resources),
        opts = shallow_copy(opts),
        out_fn = out_fn
    })

    out_fn = nil
end

function Module(name)
	if modules[name] then
		print_verbose("Ignoring duplicate module definition for "..name);
		return function () end
	end
	local i = #modules+1;
	modules[i] = { name = name, url = ___fetch_url };
	modules[name] = modules[i];
	return function (path)
		modules[i].path = path;
	end
end

function UnsetModule(name)
    for i, module in ipairs(modules) do
        if module.name == name then
            table.remove(modules, i);
            modules[name] = nil;
            return;
        end
    end
end

function Resource(name, path)
	local i = #resources+1;
	resources[i] = { name = name, path = path or name };
	return function (path)
		resources[i].path = path;
	end
end

function UnsetResource(name)
    for i, resource in ipairs(resources) do
        if resource.name == name then
            table.remove(resources, i);
            return;
        end
    end
end

function AutoFetchURL(url)
	___fetch_url = url;
end

function Main(fn)
	table.insert(main_files, fn);
end

function Output(fn)
	if opts.output == nil then
		out_fn = fn;
	end
end

function Option(name)
    name = name:gsub("%-", "_");
    opts[name] = true
    return function (value)
        opts[name] = value
    end
end

function UnsetOption(name)
    name = name:gsub("%-", "_");
    opts[name] = nil;
end

function GetOption(name)
	return opts[name:gsub('%-', '_')];
end

function ClearOptions()
    opts = {};
end

function ClearModules()
    modules = {};
end

function ClearResources()
    resources = {};
end

function Reset()
    ClearModules();
    ClearResources();
    ClearOptions();
    out_fn = nil;
end

function Message(message)
	if not opts.quiet then
		print_info(message);
	end
end

function Error(message)
	if not opts.very_quiet then
		print_err(message);
	end
end

function Exit(code)
	os.exit(code or 1);
end

-- ------------------------------ READ SQUISHY ------------------------------ --

base_path = (base_path or "."):gsub("/$", "").."/"
squishy_file = base_path .. "squishy";
out_fn = opts.output;

local ok, err = pcall(dofile, squishy_file);

if not ok then
	print_err("Couldn't read squishy file: "..err);
	Exit();
end


-- ----------------------------- FETCH FUNCTIONS ---------------------------- --

local fetch = {};

-- Filesystem fetch
function fetch.filesystem(path)
	local f, err = io.open(path);
	if not f then return false, err; end

	local data = f:read("*a");
	f:close();

	return data;
end

-- HTTP fetch
if opts.use_http then
	function fetch.http(url)
		local http = require "socket.http";

		local body, status = http.request(url);
		if status == 200 then
			return body;
		end
		return false, "HTTP status code: "..tostring(status);
	end
else
	function fetch.http(url)
		return false, "Module not found. Re-squish with --use-http option to fetch it from "..url;
	end
end

-- ----------------------------- BUILD FUNCTION ----------------------------- --

local function pack_modules(f, modules, opts, base_path, print_debug, print_err)
    print_verbose("Packing modules...");
    for _, module in ipairs(modules) do
        local modulename, path = module.name, module.path;
        if module.path:sub(1,1) ~= "/" then
            path = base_path..module.path;
        end
        print_debug("Packing "..modulename.." ("..path..")...");
        local data, err = fetch.filesystem(path);
        if (not data) and module.url then
            local url = module.url:gsub("%?", module.path);
            print_debug("Fetching: ".. url)
            if url:match("^https?://") then
                data, err = fetch.http(url);
            elseif url:match("^file://") or url:match("^[/%.]") then
                local dataf, dataerr = io.open((url:gsub("^file://", "")));
                if dataf then
                    data, err = dataf:read("*a");
                    dataf:close();
                else
                    data, err = nil, dataerr;
                end
            end
        end
        if data then
            if not opts.debug then
                f:write("package.preload['", modulename, "'] = (function (...)\n");
                f:write(data);
                f:write(" end)\n");
            else
                f:write("package.preload['", modulename, "'] = assert(load(\n");
                f:write(("%q\n"):format(data));
                f:write(", ", ("%q"):format("@"..path), "))\n");
            end
        else
            print_err("Couldn't pack module '"..modulename.."': "..(err or "unknown error... path to module file correct?"));
            Exit();
        end
    end
end

local function pack_resources(f, resources, opts, base_path, print_debug, print_err)
    if #resources > 0 then
        print_verbose("Packing resources...")
        f:write("do local resources = {};\n");
        for _, resource in ipairs(resources) do
            local name, path = resource.name, resource.path;
            local res_file, err = io.open(base_path..path, "rb");
            if not res_file then
                print_err("Couldn't load resource: "..tostring(err));
                Exit();
            end
            local data = res_file:read("*a");
            local maxequals = 0;
            data:gsub("(=+)", function (equals_string) maxequals = math.max(maxequals, #equals_string); end);

            f:write(("resources[%q] = %q"):format(name, data));
    --[[		f:write(("resources[%q] = ["):format(name), string.rep("=", maxequals+1), "[");
            f:write(data);
            f:write("]", string.rep("=", maxequals+1), "];"); ]]
        end
        if opts.virtual_io then
            local vio = require_resource("vio");
            if not vio then
                print_err("Virtual IO requested but is not enabled in this build of squish");
            else
                -- Insert vio library
                f:write(vio, "\n")
                -- Override standard functions to use vio if opening a resource
                f:write[[local io_open, io_lines = io.open, io.lines; function io.open(fn, mode)
                        if not resources[fn] then
                            return io_open(fn, mode);
                        else
                            return vio.open(resources[fn]);
                    end end
                    function io.lines(fn)
                        if not resources[fn] then
                            return io_lines(fn);
                        else
                            return vio.open(resources[fn]):lines()
                    end end
                    local _dofile = dofile;
                    function dofile(fn)
                        if not resources[fn] then
                            return _dofile(fn);
                        else
                            return assert(load(resources[fn]))();
                    end end
                    local _loadfile = loadfile;
                    function loadfile(fn)
                        if not resources[fn] then
                            return _loadfile(fn);
                        else
                            return load(resources[fn], "@"..fn);
                    end end ]]
            end
        end
        f:write[[function require_resource(name) return resources[name] or error("resource '"..tostring(name).."' not found"); end end ]]
    end
end

local function resolve_modules(modules, base_path, print_debug, print_err)
    print_verbose("Resolving modules...");
    do
        local LUA_DIRSEP = package.config:sub(1,1);
        local LUA_PATH_MARK = package.config:sub(5,5);

        local package_path = package.path:gsub("[^;]+", function (path)
                if not path:match("^%"..LUA_DIRSEP) then
                    return base_path..path;
                end
            end):gsub("/%./", "/");
        local package_cpath = package.cpath:gsub("[^;]+", function (path)
                if not path:match("^%"..LUA_DIRSEP) then
                    return base_path..path;
                end
            end):gsub("/%./", "/");

        function resolve_module(name, path)
                name = name:gsub("%.", LUA_DIRSEP);
                for c in path:gmatch("[^;]+") do
                        c = c:gsub("%"..LUA_PATH_MARK, name);
                        print_debug("Looking for "..c)
                        local f = io.open(c);
                        if f then
                            print_debug("Found!");
                                f:close();
                            return c;
                        end
                end
                return nil; -- not found
        end

        for i, module in ipairs(modules) do
            if not module.path then
                module.path = resolve_module(module.name, package_path);
                if not module.path then
                    print_err("Couldn't resolve module: "..module.name);
                else
                    -- Strip base_path from resolved path
                    module.path = module.path:gsub("^"..base_path:gsub("%p", "%%%1"), "");
                end
            end
        end
    end
end

local function run_build(build)
    -- Load build data
    local modules = build.modules;
    local main_files = build.main_files;
    local resources = build.resources;
    local opts = build.opts;
    local out_fn = build.out_fn;

    -- Re-setup prints for this build
    print_err, print_info, print_verbose, print_debug = setup_prints(opts);

    -- Validate build
    if not out_fn then
        -- No output file specified
        print_err("No output file specified by user or squishy file");
        Exit();
    elseif #main_files == 0 and #modules == 0 and #resources == 0 then
        -- Nothing to pack
        print_err("No files, modules or resources. Not going to generate an empty file.");
        Exit();
    end

    -- Open output file
    print_info("Writing "..out_fn.."...");
    local f, err = io.open(out_fn, "w+");
    if not f then
        print_err("Couldn't open output file: "..tostring(err));
        Exit();
    end

    -- Write shebang if requested
    if opts.executable then
        if opts.executable == true then
            f:write("#!/usr/bin/env lua\n");
        else
            f:write(opts.executable, "\n");
        end
    end

    -- Load optional processing modules
    local minify_file, uglify_file, compile_file, gzip_file

    if opts.minify then
        local ok, minify = pcall(require, "squish.minify")
        if ok and type(minify) == "function" then
            minify_file = minify
        elseif ok and type(minify) == "table" and minify.minify then
            minify_file = minify.minify
        end
    end

    if opts.uglify then
        local ok, uglify = pcall(require, "squish.uglify")
        if ok and type(uglify) == "function" then
            uglify_file = uglify
        elseif ok and type(uglify) == "table" and uglify.uglify then
            uglify_file = uglify.uglify
        end
    end

    if opts.compile then
        local ok, compile = pcall(require, "squish.compile")
        if ok and type(compile) == "function" then
            compile_file = compile
        elseif ok and type(compile) == "table" and compile.compile then
            compile_file = compile.compile
        end
    end

    if opts.gzip then
        local ok, gzip = pcall(require, "squish.gzip")
        if ok and type(gzip) == "function" then
            gzip_file = gzip
        elseif ok and type(gzip) == "table" and gzip.gzip then
            gzip_file = gzip.gzip
        end
    end

    -- Resolve module paths if necessary
    resolve_modules(modules, base_path, print_debug, print_err);

    -- Pack modules
    pack_modules(f, modules, opts, base_path, print_debug, print_err);

    -- Pack resources
    pack_resources(f, resources, opts, base_path, print_debug, print_err);

    -- Write main files
    print_debug("Finalising...")
    for _, fn in pairs(main_files) do
        local fin, err = io.open(base_path..fn);
        if not fin then
            print_err("Failed to open "..fn..": "..err);
            Exit();
        else
            f:write((fin:read("*a"):gsub("^#.-\n", "")));
            fin:close();
        end
    end

    f:close();

    -- Finished
    print_info("OK!");

    -- Minify
    if opts.minify == true then
        print_info("Minifying "..out_fn.."...")
        if minify_file then
            minify_file(out_fn, out_fn)
            print_info("OK!")
        else
            print_err("Minify requested but squish.minify module not found or invalid!")
        end
    end

    -- Uglify
    if opts.uglify == true then
    print_info("Uglifying "..out_fn.."...")
    if uglify_file then
        uglify_file(out_fn, out_fn)
        print_info("OK!")
    else
        print_err("Uglify requested but squish.uglify module not found or invalid!")
    end
end

    -- Compile
    if opts.compile then
        print_info("Compiling "..out_fn.."...")
        if compile_file then
            compile_file(out_fn, out_fn)
            print_info("OK!")
        else
            print_err("Compile requested but squish.compile module not found or invalid!")
        end
    end

    -- Gzip
    if opts.gzip then
        print_info("Gzipping "..out_fn.."...")
        if gzip_file then
            gzip_file(out_fn, out_fn)
            print_info("OK!")
        else
            print_err("Gzip requested but squish.gzip module not found or invalid!")
        end
    end
end

-- ------------------------------- BUILD LOOP ------------------------------- --

if #builds > 0 then
    for _, build in ipairs(builds) do
        run_build(build);
    end
else
    run_build({
        modules = modules,
        main_files = main_files,
        resources = resources,
        opts = opts,
        out_fn = out_fn
    });
end

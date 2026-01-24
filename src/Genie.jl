"""
Loads dependencies and bootstraps a Genie app. Exposes core Genie functionality.
"""
module Genie

import Inflector

# Load Requires for Julia 1.6-1.8 backwards compatibility
# (Julia 1.9+ has Package Extensions built-in)
@static if !isdefined(Base, :get_extension)
  using Requires
end

include("Configuration.jl")
using .Configuration

const config = Configuration.Settings()

include("constants.jl")

import Sockets
import Logging

using Reexport

# ================================================= #
# ===  INJECTION HOOKS ============================ #
# ================================================= #

# Hook for Revise.revise (Immediate code update)
const _revise = Ref{Function}() do
  nothing
end

# Hook for Revise.entr (File Watcher) 
# Signature matches Revise.entr: f (callback function), watched_files, and all kwarg
const _entr = Ref{Function}() do f, watched_files; all=false
  @warn "Watch mode is disabled because Revise.jl is not loaded. Install Revise to enable file watching." maxlog=1
  nothing
end

# ================================================= #

include("Util.jl")
include("HTTPUtils.jl")
include("Exceptions.jl")
include("Repl.jl")
include("Watch.jl")
include("Loader.jl")
include("Secrets.jl")
include("FileTemplates.jl")
include("Toolbox.jl")
include("Generator.jl")
include("Encryption.jl")
include("Cookies.jl")
include("Input.jl")
include("JSONParser.jl")
include("Router.jl")
include("Renderer.jl")
include("WebChannels.jl")
include("WebThreads.jl")
include("Headers.jl")
include("Assets.jl")
include("Server.jl")
include("Commands.jl")
include("Responses.jl")
include("Requests.jl")
include("Logger.jl")

# === #

export up, down
@reexport using .Util
@reexport using .Router
@reexport using .Loader

const assets_config = Genie.Assets.assets_config


"""
    loadapp(path::String = "."; autostart::Bool = false) :: Nothing

Loads an existing Genie app from the file system, within the current Julia REPL session.

# Arguments
- `path::String`: the path to the Genie app on the file system.
- `autostart::Bool`: automatically start the app upon loading it.

# Examples
```julia-repl
shell> tree -L 1
.
├── Manifest.toml
├── Project.toml
├── bin
├── bootstrap.jl
├── config
├── env.jl
├── genie.jl
├── log
├── public
├── routes.jl
└── src

5 directories, 6 files

julia> using Genie

julia> Genie.loadapp(".")
 _____         _
|   __|___ ___|_|___
|  |  | -_|   | | -_|
|_____|___|_|_|_|___|

┌ Info:
│ Starting Genie in >> DEV << mode
└
[ Info: Logging to file at MyGenieApp/log/dev.log
```
"""
function loadapp( path::String = ".";
                  autostart::Bool = false,
                  dbadapter::Union{Nothing,Symbol,String} = nothing,
                  context = Main) :: Nothing
  if ! isnothing(dbadapter) && dbadapter != "nothing"
    Genie.Generator.autoconfdb(dbadapter)
  end

  path = normpath(path) |> abspath

  if isfile(joinpath(path, Genie.BOOTSTRAP_FILE_NAME))
    Genie.Loader.includet(context, joinpath(path, Genie.BOOTSTRAP_FILE_NAME))
    Genie.config.watch && @async Genie.Watch.watch(path)
    autostart && (Core.eval(context, :(up())))
  elseif isfile(joinpath(path, Genie.ROUTES_FILE_NAME)) || isfile(joinpath(path, Genie.APP_FILE_NAME))
    genie(context = context) # load the app
  else
    error("Couldn't find a Genie app file in $path (bootstrap.jl, routes.jl or app.jl).")
  end

  nothing
end

const go = loadapp


"""
    up(port::Int = Genie.config.server_port, host::String = Genie.config.server_host;
        ws_port::Int = Genie.config.websockets_port, async::Bool = ! Genie.config.run_as_server) :: Nothing

Starts the web server. Alias for `Server.up`

# Arguments
- `port::Int`: the port used by the web server
- `host::String`: the host used by the web server
- `ws_port::Int`: the port used by the Web Sockets server
- `async::Bool`: run the web server task asynchronously

# Examples
```julia-repl
julia> up(8000, "127.0.0.1", async = false)
[ Info: Ready!
Web Server starting at http://127.0.0.1:8000
```
"""
const up = Server.up
const down = Server.down
const isrunning = Server.isrunning
const down! = Server.down!


### PRIVATE ###

"""
    run() :: Nothing

Runs the Genie app by parsing the command line args and invoking the corresponding actions.
Used internally to parse command line arguments.
"""
function run(; server::Union{Sockets.TCPServer,Nothing} = nothing) :: Nothing
  Genie.config.app_env == "test" || Commands.execute(Genie.config, server = server)

  nothing
end


"""
    genie() :: Union{Nothing,Sockets.TCPServer}
"""
function genie(; context = @__MODULE__) :: Union{Nothing,Sockets.TCPServer}
  EARLYBINDING = Loader.loadenv(context = context)
  Secrets.load(context = context)
  Loader.load(context = context)
  Genie.config.watch && @async Watch.watch(pwd())
  run(server = EARLYBINDING)

  EARLYBINDING
end

const bootstrap = genie

function __init__()
  # 1. BACKWARDS COMPATIBILITY (Julia 1.6-1.8)
  @static if !isdefined(Base, :get_extension)
    @require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
      using Revise
      # Connect Loader
      Genie.Loader._includet[] = Revise.includet      
      # Connect Watcher
      if isdefined(Revise, :entr)
        Genie._entr[] = Revise.entr
      else
        @warn "Genie: File watching disabled. Your Revise.jl version is too old (pre-v2.6). Update Revise to enable auto-reloading."
      end
      # Connect Manual Revision
      Genie._revise[] = Revise.revise
      
      @debug "Genie: Revise.jl detected via Requires. Hot-reloading & Watcher enabled."
    end
  end

  # 2. GENERAL CONFIGURATION
  config.path_build = Genie.Configuration.buildpath()

  # 3. SECURITY WARNING (Valid for all versions)
  # If in DEV mode and loader is still Base.include (either no extension loaded or Requires didn't find Revise)
  if Genie.Configuration.isdev() && Genie.Loader._includet[] == Base.include
    @warn """
    Hot-reloading is DISABLED!
    
    Revise.jl is no longer loaded automatically to ensure production security and enable static compilation.
    
    To enable code autorefresh in DEV, run:
      julia> using Revise
      julia> using Genie
    
    Or add `using Revise` to your startup.jl for automatic loading.
    
    For more details, see: https://learn.genieframework.com/guides/Interactive_environment
    """
  end
end

end

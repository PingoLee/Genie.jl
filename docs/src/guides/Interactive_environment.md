# Using Genie in an interactive environment (Jupyter/IJulia, REPL, etc)

Genie can be used for ad-hoc exploratory programming, to quickly whip up a web server
and expose your Julia functions.

!!! warning "Important: Revise.jl is now Optional"
    Starting with Genie v6, **Revise.jl is no longer a hard dependency**. This change enables:
    - **Static compilation** of Genie apps with PackageCompiler.jl
    - **Enhanced security** in production (preventing runtime code modification)
    - **Reduced memory footprint** for production deployments
    
    **To enable hot-reloading in interactive development:**
    
    Load `Revise` **before** `Genie`:
    ```julia
    using Revise  # Must come FIRST
    using Genie
    ```
    
    ### Setting up Revise in Your startup.jl
    
    **Recommended approach:** Add Revise to your global startup file (`~/.julia/config/startup.jl`):
    ```julia
    # ~/.julia/config/startup.jl
    try
        using Revise
    catch e
        @warn "Revise.jl not found. Install it in your global env with: ] activate; add Revise"
    end
    ```
    
    This ensures hot-reloading is always available in interactive REPL sessions without affecting:
    - Project dependencies (Revise won't be added to your app's Project.toml)
    - Production deployments (startup.jl is not loaded in packaged apps)
    - Static compilation (Package Compiler ignores startup.jl)
    
    ### Production & Security Best Practices
    
    !!! danger "Disable startup.jl in Production"
        When running Genie in production environments, **disable the startup file** to prevent code injection attacks:
        ```bash
        # Run Julia without loading startup.jl
        julia --startup-file=no app.jl
        
        # Or disable it completely for that session
        julia -i --startup-file=no
        ```
    
    !!! tip "Separate Development & Production Machines"
        For maximum security and stability:
        - **Development machine**: Use your normal Julia setup with startup.jl enabled
        - **Production server**: Use a minimal, locked-down Julia configuration
        - **Never run development code in production** - always test deploys in a staging environment
    
    This separation ensures:
    - Hot-reloading only in development
    - No risk of accidental code modification in production
    - Predictable, reproducible deployments


---

## Setting up Revise for Automatic Hot-Reloading

To avoid typing `using Revise` every time you start a REPL session, add it to your global startup file.

### Step 1: Locate your startup.jl file

The startup file is located in different places depending on your OS:

=== "Linux/macOS"
    ```bash
    # The directory is: ~/.julia/config/
    # If it doesn't exist, create it:
    mkdir -p ~/.julia/config
    
    # Then edit the file:
    nano ~/.julia/config/startup.jl
    # or use your favorite editor (vim, emacs, VSCode, etc)
    ```

=== "Windows"
    ```powershell
    # The directory is: %APPDATA%\julia\config\
    # In PowerShell, navigate to:
    cd $PROFILE\..\..\
    
    # Or use the full path:
    C:\Users\YourUsername\AppData\Roaming\julia\config\
    
    # Edit with Notepad or your favorite editor
    ```

=== "Find it with Julia"
    ```julia
    julia> # In the Julia REPL, run:
    julia> joinpath(DEPOT_PATH[1], "config", "startup.jl")
    # This shows exactly where your startup.jl should be
    ```

### Step 2: Add Revise to your startup.jl

Add this content to your `~/.julia/config/startup.jl`:
```julia
# ~/.julia/config/startup.jl
try
    using Revise
catch e
    @warn "Revise.jl not found. Install it globally with: ] add Revise"
end
```

### Step 3: Test it

Start a new Julia REPL and verify Revise loads:
```julia
julia> # If you see a message like:
    # "Revise.jl: No files monitored"
    # Then Revise loaded successfully! ✅
```

### Important: Does this affect my Project.toml?

**NO!** ❌ The startup.jl is completely separate from your project:

```
startup.jl loads ONLY in interactive REPL sessions
     ↓
Code runs in a shared "global environment"
     ↓
Your project's Project.toml is NEVER modified
     ↓
When you run `julia app.jl`, startup.jl STILL loads
     ↓
But Revise doesn't get added as a dependency
```

**What happens in practice:**

=== "Interactive REPL"
    ```julia
    julia> # Revise loads from startup.jl ✅
    julia> using Genie  # Genie detects Revise and enables hot-reloading
    julia> # Hot-reloading ENABLED ✅
    ```

=== "Running a script"
    ```bash
    julia app.jl  # startup.jl loads first
    # Revise is available, Genie uses it
    # But app.jl's Project.toml is unaffected
    ```

=== "Production with --startup-file=no"
    ```bash
    julia --startup-file=no app.jl  # startup.jl is skipped
    # Revise NOT available
    # Genie runs without hot-reloading (expected behavior)
    ```

---

## Why Revise is Optional: The Justification

### Security & Production Safety

Making Revise optional is **not a breaking change** – it's a **security improvement**:

1. **Prevents Runtime Code Modification in Production**
   - With Revise as a hard dependency, production apps could accidentally modify code at runtime
   - Now, you explicitly control when this capability is available
   - Run with `--startup-file=no` in production to ensure zero runtime code changes

2. **Enables Static Compilation**
   - PackageCompiler.jl can now create truly static, compiled binaries of Genie apps
   - Zero runtime code loading overhead
   - Suitable for high-security, offline-capable deployments

3. **Reduces Memory Footprint**
   - Revise.jl has memory overhead that's unnecessary in production
   - Compiled apps can be significantly leaner

### Backward Compatibility

This change is **fully backward compatible**:

- **In Genie v5**: You could already use Revise in startup.jl
- **In Genie v6**: The same setup works, but now it's _optional_
- **Zero breaking changes**: If you have Revise loaded, Genie auto-detects and uses it
- **Graceful degradation**: Without Revise, Genie still works perfectly in production

### The Right Approach for Everyone

| Environment | Setup | Behavior |
|---|---|---|
| **Development REPL** | `startup.jl` with `using Revise` | Hot-reloading enabled ✅ |
| **Development Script** | `julia app.jl` (with startup.jl) | Hot-reloading enabled ✅ |
| **Production Server** | `julia --startup-file=no app.jl` | Fast, secure, no runtime modification ✅ |
| **Compiled Binary** | `PackageCompiler.jl` | Ultra-fast, zero overhead ✅ |

This design gives developers the **best of both worlds**: convenience in development, safety in production.

---

Once you have `Genie` into scope, you can define a new `route`.
A `route` maps a URL to a function.

```julia
julia> using Genie

julia> route("/") do
         "Hi there!"
       end
```

You can now start the web server using

```julia
julia> up()
```

Finally, now navigate to <http://localhost:8000> – you should see the message "Hi there!".

We can define more complex URIs which can also map to previously defined functions:

```julia
julia> function hello_world()
         "Hello World!"
       end
julia> route("/hello/world", hello_world)
```

The route handler functions can be defined anywhere (in any other file or module) as long as they are accessible in the current scope.

You can now visit <http://localhost:8000/hello/world> in the browser.

We can access route params that are defined as part of the URL, like `:message` in the following example:

```julia
julia> route("/echo/:message") do
         params(:message)
       end
```

Accessing <http://localhost:8000/echo/ciao> should echo "ciao".

And we can even match route params by types (and automatically convert them to the correct type):

```julia
julia> route("/sum/:x::Int/:y::Int") do
         params(:x) + params(:y)
       end
```

By default, route params are extracted as `SubString` (more exactly, `SubString{String}`).
If type constraints are added, Genie will attempt to convert the `SubString` to the indicated type.

For the above to work, we also need to tell Genie how to perform the conversion:

```julia
julia> Base.convert(::Type{Int}, s::AbstractString) = parse(Int, s)
```

Now if we access <http://localhost:8000/sum/2/3> we should see `5`

## Handling query params

Query params, which look like `...?foo=bar&baz=2` are automatically unpacked by Genie and placed into the `params` collection. For example:

```julia
julia> route("/sum/:x::Int/:y::Int") do
         params(:x) + params(:y) + parse(Int, get(params, :initial_value, "0"))
       end
```

Accessing <http://localhost:8000/sum/2/3?initial_value=10> will now output `15`.

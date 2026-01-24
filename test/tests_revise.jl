@safetestset "Genie Revise Extension Integration" begin
  using Test
  using Pkg
  using Genie

  @testset "Genie Revise.jl Integration Tests" begin

    # 1. Discover where the current Genie source code is (on your disk)
    # We need this to make the child process use THIS version of Genie, not download from the internet.
    genie_path = dirname(dirname(pathof(Genie)))

    """
        run_with_env(script_body::String; install_revise::Bool=false)

    Creates a completely isolated Julia process, creates a temporary environment,
    installs Genie locally and (optionally) installs Revise.
    """
    function run_with_env(script_body; install_revise=false)
        # Escape the path to work on Windows (backslashes)
        safe_genie_path = escape_string(genie_path)
        
        # Build a script that configures the environment from scratch
        setup_code = """
        import Pkg
        Pkg.activate(; temp=true) # Creates a temporary disposable environment
        
        # Redirect Pkg logs to devnull to avoid polluting the test output
        # io = open(devnull, "w") 
        
        # Install the local Genie (what we are testing)
        Pkg.develop(path="$safe_genie_path", io=devnull)
        """
        
        if install_revise
            setup_code *= """
            Pkg.add(name="Revise", version="3.1", io=devnull)
            """
        end

        # Join the setup with the actual test
        full_code = setup_code * "\n" * script_body

        cmd = `$(Base.julia_cmd()) --startup-file=no -e "$full_code"`
        run(cmd)
    end

    @testset "Scenario 1: Production Mode (Without Revise)" begin
        code = """
        using Genie
        using Test

        # Verify: Loader should be the standard (Base.include)
        @test Genie.Loader._includet[] == Base.include

        # Verify: Revise should not be loaded
        @test !isdefined(Main, :Revise)

        # Verify: Manual revision hook does nothing
        @test isnothing(Genie._revise[]())
        
        println("✓ Production mode verified.")
        """

        @test success(run_with_env(code, install_revise=false))
    end

    @testset "Scenario 2: Development Mode (With Revise)" begin
        code = """
        using Revise 
        using Genie
        using Test

        # Verify: Loader hook swapped to Revise
        @test Genie.Loader._includet[] == Revise.includet

        # Verify: Watcher hook swapped to Revise
        @test Genie._entr[] == Revise.entr

        # Verify: Manual revision hook swapped to Revise
        @test Genie._revise[] == Revise.revise

        println("✓ Development mode verified.")
        """

        # KEY INSIGHT: install_revise=true
        @test success(run_with_env(code, install_revise=true))
    end

  end
end
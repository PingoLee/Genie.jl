@safetestset "Genie Revise Extension" begin
  using Test
  using Pkg

  @testset "Revise Optional Dependency Tests" begin
      
      # Locate the current Genie package path to load the exact same code
      project_path = dirname(dirname(pathof(Genie)))
      
      # Helper to run code in a clean, isolated Julia process
      # This ensures we test the initialization logic from scratch
      function run_isolated(code_str)
          # We use --startup-file=no to simulate a production/clean environment
          cmd = `$(Base.julia_cmd()) --project="$project_path" --startup-file=no -e "$code_str"`
          run(cmd)
      end

      @testset "Scenario 1: Loading Genie WITHOUT Revise (Production Mode)" begin
          # Logic to verify:
          # 1. Load Genie.
          # 2. Confirm that the internal loader points to Base.include (static/fast mode).
          code = """
          using Genie
          using Test
          
          # Verify that the internal mechanism is using the standard Base.include
          @test Genie.Loader._includet[] == Base.include
          println("Success: Genie loaded in static mode (without Revise).")
          """
          
          @test success(run_isolated(code))
      end

      @testset "Scenario 2: Loading Genie WITH Revise (Development Mode)" begin
          # Logic to verify:
          # 1. Load Revise FIRST.
          # 2. Load Genie.
          # 3. Confirm that the extension/hook activated and swapped the loader to Revise.includet.
          code = """
          import Pkg
          # We need to ensure Revise is available in this isolated environment.
          # In CI/Test environments, Revise should be present in the test dependencies.
          using Revise
          using Genie
          using Test
          
          # Verify that the hook worked and swapped the pointer
          @test Genie.Loader._includet[] == Revise.includet
          println("Success: Genie loaded in development mode (Revise hook active).")
          """
          
          @test success(run_isolated(code))
      end
  end
end # safetestset
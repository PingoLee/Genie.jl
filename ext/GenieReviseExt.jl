module GenieReviseExt

using Genie
using Revise

function __init__()
    # Inject includet for hot-reloading of user code
    Genie.Loader._includet[] = Revise.includet
    
    # Inject entr for watching file changes
    Genie._entr[] = Revise.entr
    
    # Inject revise for manual code refresh
    Genie._revise[] = Revise.revise
    
    @debug "Genie: Revise.jl detected. Hot-reloading & file watching enabled."
end

end

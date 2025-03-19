
using Pkg
Pkg.activate(".")
cd("test")

ENV["GENIE_ENV"] = "prod"
ENV["PRECOMPILE"] = true


using Genie

Genie.Renderer.Html.register_elements()
Genie.Renderer.Html.include_elements()

@time Genie.Renderer.Html.raw_html(Genie.Renderer.filepath("layouts\\templates\\linkage.jl.html"), layout = Genie.Renderer.filepath("layouts\\app.jl.html"), scripts="<script src='/js/cust/linksus.js'></script>");
@time Genie.Renderer.Html.html(Genie.Renderer.filepath("layouts\\templates\\linkage.jl.html"), layout = Genie.Renderer.filepath("layouts\\app.jl.html"), scripts="<script src='/js/cust/linksus.js'></script>");


using Documenter
using GSOpt

# Push to LOAD_PATH to ensure the module can be found
push!(LOAD_PATH, "../src/")

makedocs(
    sitename = "GSOpt.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://mopg.github.io/GSOpt.jl",
    ),
    modules = [GSOpt],
    authors = "mopg",
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Overview" => ["Getting Started" => "overview/getting_started.md"],
        "Examples" => "examples.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/mopg/GSOpt.jl.git",
    push_preview = false, # don't push previews for PRs for now
)

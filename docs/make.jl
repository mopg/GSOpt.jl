using Documenter
using GSOpt

# Push to LOAD_PATH to ensure the module can be found
push!(LOAD_PATH, "../src/")

makedocs(
    sitename = "GSOpt.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://username.github.io/GSOpt.jl",
    ),
    modules = [GSOpt],
    authors = "mopg",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting_started.md",
            "Expressions" => "manual/expressions.md",
            "Models" => "manual/models.md",
            "Constraints" => "manual/constraints.md",
            "Transformations" => "manual/transformations.md",
        ],
        "Examples" => "examples.md",
        "API Reference" => "api.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/username/GSOpt.jl.git",
    devbranch = "main",
    push_preview = true,
)

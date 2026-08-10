# Execute every ```julia block of a .jmd file in order, in Main.
# Usage: julia --project=... runjmd.jl <file.jmd> <figdir>
# After each block: save any returned Plots.Plot, and dump WorkPrecisionSet data
# if the block produced a new `wp`.

function extract_blocks(path)
    lines = readlines(path)
    blocks = String[]
    inblock = false
    cur = String[]
    for l in lines
        if !inblock && startswith(l, "```julia")
            inblock = true
            cur = String[]
        elseif inblock && startswith(l, "```")
            inblock = false
            push!(blocks, join(cur, "\n"))
        elseif inblock
            push!(cur, l)
        end
    end
    return blocks
end

const jmdfile = ARGS[1]
const figdir = ARGS[2]
mkpath(figdir)
const WEAVE_ARGS = Dict(:folder => "benchmarks/SimpleHandwrittenPDE", :file => basename(jmdfile))

blocks = extract_blocks(jmdfile)
println("== $(basename(jmdfile)): $(length(blocks)) blocks ==")
flush(stdout)

last_wp_id = UInt(0)
total = @elapsed for (i, b) in enumerate(blocks)
    println("========== BLOCK $i ==========")
    flush(stdout)
    t = @elapsed res = include_string(Main, b, "block$i")
    println("---------- block $i finished in $(round(t, digits = 1)) s")
    if isdefined(Main, :Plots) && res isa Main.Plots.Plot
        f = joinpath(figdir, string(splitext(basename(jmdfile))[1], "_block", i, ".png"))
        Main.Plots.savefig(res, f)
        println("figure: $f size=$(filesize(f))")
    end
    if isdefined(Main, :wp) && Main.wp isa Main.DiffEqDevTools.WorkPrecisionSet &&
       objectid(Main.wp) != last_wp_id
        global last_wp_id = objectid(Main.wp)
        for w in Main.wp.wps
            println("WPSDATA ", w.name)
            println("  errors=", w.errors)
            println("  times=", w.times)
        end
    end
    flush(stdout)
end
println("== TOTAL for $(basename(jmdfile)): $(round(total, digits = 1)) s ==")

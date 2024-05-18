### A Pluto.jl notebook ###
# v0.19.29

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ eeba971b-c64e-4195-95ca-5cf2ae5ac590
# ╠═╡ show_logs = false
begin
  using Pkg
  Pkg.activate(".")

  using CairoMakie
  using GLMakie
  using DICOM, PlutoUI, ImageMorphology, Statistics, DataFrames
  using FileIO
  using Meshes
  using JLD2
end

# ╔═╡ 97c601e0-7f20-4112-b526-4f1509ce168f
md"""
# Rendering 3D data
"""

# ╔═╡ 21b31afd-a099-45ef-9bcd-9c61b7b293f9
md"""
**Enter 3D Data File**

Input the name of the file that needs to be 3D shown. Then click submit

$(@bind visulaztion_file confirm(PlutoUI.TextField(60; default = "/Users/harryxiong24/Code/Lab/perfusion/trajectory.log")))
"""

# ╔═╡ 412ce826-8017-4032-92ab-41d9ef1d1322
# Function to read and process the file
function read_and_process_data(file_path)
    groups = Dict{Int, Vector{Tuple{Float64, Float64, Float64}}}()

    open(file_path, "r") do file
        for line in eachline(file)
            line = strip(line)
            if isempty(line)  # Skipping empty lines
                continue
            end
            data = split(line)
            group_id = parse(Int, data[1])
            coord = (parse(Float64, data[3]), parse(Float64, data[4]), parse(Float64, data[5]))
            
            if !haskey(groups, group_id)
                groups[group_id] = [coord]
            else
                push!(groups[group_id], coord)
            end
        end
    end
    
    return groups
end

# ╔═╡ 99d9eefb-db4f-4d34-86c5-f2f052b8fd4f
# Function to create the 3D plot
function plot_groups(groups)
    fig = Figure()
    ax = GLMakie.Axis3(fig[1, 1], perspectiveness=0.5, xlabel="X", ylabel="Y", zlabel="Z")
    
    for (group_id, coords) in groups
        xs, ys, zs = getindex.(coords, 1), getindex.(coords, 2), getindex.(coords, 3)
        GLMakie.lines!(ax, xs, ys, zs, linewidth=4)
    end
    
    # Displaying the plot
    fig
	display(fig)
end

# ╔═╡ 0b318758-cc48-4f10-abf0-b73aa8ea3859
# Processing data
groups = read_and_process_data(visulaztion_file)

# ╔═╡ f3262239-bf25-480f-8ec4-13d8238bd2f4
# Creating the plot
plot = plot_groups(groups)

# ╔═╡ 0dcf9e76-1cd2-403a-b92c-a2679ed5ebf4
# let
#   # @load visulaztion_file ŷ
#   min, max = minimum(ŷ), maximum(ŷ)
#   f = Figure(resolution=(1200, 1000))

#   # control azimuth
#   Label(f[0, 1], "Azimuth", justification=:left, lineheight=1)
#   azimuth = GLMakie.Slider(f[0, 2:3], range=0:0.01:1, startvalue=0.69)
#   azimuth_slice = lift(azimuth.value) do a
#     a * pi
#   end

#   # control elevation
#   Label(f[1, 1], "Elevation", justification=:left, lineheight=1)
#   elevation = GLMakie.Slider(f[1, 2:3], range=0:0.01:1, startvalue=0.18)
#   elevation_slice = lift(elevation.value) do e
#     e * pi
#   end

#   # control elevation
#   Label(f[2, 1], "Perspectiveness", justification=:left, lineheight=1)
#   perspectiveness = GLMakie.Slider(f[2, 2:3], range=0:0.01:1, startvalue=0.5)
#   perspectiveness_slice = lift(perspectiveness.value) do p
#     p
#   end

#   # control colormap
#   Label(f[3, 1], "Color Slider", justification=:left, lineheight=1)
#   colormap = Observable(to_colormap(:jet))
#   slider = GLMakie.Slider(f[3, 2:3], range=0:1:8, startvalue=0)
#   on(slider.value) do c
#     new_colormap = to_colormap(:jet)
#     for i in 1:c
#       new_colormap[i] = RGBAf(0, 0, 0, 0)
#     end
#     colormap[] = new_colormap
#   end

#   # render picture
#   ax = GLMakie.Axis3(f[4, 1:2];
#     perspectiveness=perspectiveness_slice,
#     azimuth=azimuth_slice,
#     elevation=elevation_slice,
#     aspect=(1, 1, 1)
#   )


#   # 向 Axis3 添加 volume 绘图
#   GLMakie.volume!(ax, ŷ;
#     colormap=colormap,
#     lowclip=:transparent,
#     highclip=:transparent,
#     nan_color=:transparent,
#     transparency=true
#   )

#   Colorbar(f[4, 3], colormap=:jet, colorrange=(min, max), flipaxis=false)

#   f
#   display(f)
# end

# ╔═╡ Cell order:
# ╠═eeba971b-c64e-4195-95ca-5cf2ae5ac590
# ╠═97c601e0-7f20-4112-b526-4f1509ce168f
# ╟─21b31afd-a099-45ef-9bcd-9c61b7b293f9
# ╠═412ce826-8017-4032-92ab-41d9ef1d1322
# ╠═99d9eefb-db4f-4d34-86c5-f2f052b8fd4f
# ╠═0b318758-cc48-4f10-abf0-b73aa8ea3859
# ╠═f3262239-bf25-480f-8ec4-13d8238bd2f4
# ╠═0dcf9e76-1cd2-403a-b92c-a2679ed5ebf4

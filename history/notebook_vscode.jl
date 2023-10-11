using Pkg
Pkg.activate(".")
using GLMakie
using DICOM, ImageMorphology, Statistics, DataFrames
using FileIO
using PerfusionImaging

# Load DICOMs
root_path = "/Users/harryxiong24/Code/Lab/perfusion/limb"
dicom_path = joinpath(root_path, "DICOM")
path_v1 = joinpath(dicom_path, "01")
path_v2 = joinpath(dicom_path, "02")
surestart_path = joinpath(root_path, "SureStart");
segmentation_root = joinpath(root_path, "SEGMENT_dcm")
limb_path = joinpath(segmentation_root, "Limb_dcm")
fa_path = joinpath(segmentation_root, "FA_dcm")

# Convert DICOMs to Arrays
dcms_v1 = dcmdir_parse(path_v1)
dcms_v2 = dcmdir_parse(path_v2)
dcms_ss = dcmdir_parse(surestart_path);
dcms_limb = dcmdir_parse(limb_path)
dcms_fa = dcmdir_parse(fa_path);

v1_arr = load_dcm_array(dcms_v1)
v2_arr = load_dcm_array(dcms_v2)


# Visualize Volume Scans
let
  f = Figure(resolution=(1200, 800))
  z_vols = Slider(f[0, 1:2], range = axes(v1_arr, 3), startvalue = size(v1_arr, 3) ÷ 15)

  slice1 = lift(z_vols.value) do z
    v1_arr[:, :, z]
  end

  slice2 = lift(z_vols.value) do z
    v2_arr[:, :, z]
  end

  ax = Axis(
    f[1, 1],
    title="V1 (No Contrast)",
    titlesize=40
  )
  heatmap!(slice1, colormap=:grays)

  ax = Axis(
    f[1, 2],
    title="V2 (Contrast)",
    titlesize=40
  )
  heatmap!(slice2, colormap=:grays)
  display(f)
end



limb_arr = load_dcm_array(dcms_limb);
limb_mask = copy(limb_arr)
replace!(x -> x < -1000 ? 0 : x, limb_mask)
limb_mask = limb_mask[:, :, end:-1:1]
limb_mask = limb_mask .!= 0

let
  f = Figure(resolution=(1200, 800))
  z_vols = Slider(f[0, 1:2], range = axes(limb_mask, 3), startvalue = size(limb_mask, 3) ÷ 15)

  slice1 = lift(z_vols.value) do z
    limb_mask[:, :, z]
  end

  slice2 = lift(z_vols.value) do z
    v2_arr[:, :, z]
  end

  ax = Axis(
    f[1, 1],
    title="Limb Mask",
    titlesize=40
  )
  heatmap!(slice1, colormap=:grays)

  ax = Axis(
    f[1, 2],
    title="Limb Mask Overlayed",
    titlesize=40
  )
  heatmap!(slice2, colormap=:grays)
  heatmap!(slice1, colormap=(:jet, 0.3))
  display(f)
end

# begin
#   pts_cartesian = findall(isone, limb_mask)
#   pts_matrix = getindex.(pts_cartesian, [1 2 3])
#   pts_meshes = Array{Meshes.Point3}(undef, size(pts_matrix, 1))

#   for i in axes(pts_matrix, 1)
#     pts_meshes[i, :] .= Meshes.Point(pts_matrix[i, :]...)
#   end
# end


ss_arr = load_dcm_array(dcms_ss);
let
  f = Figure()
  z_vols = Slider(f[0, 1], range = axes(ss_arr, 3), startvalue = size(ss_arr, 3) ÷ 15)

  slice1 = lift(z_vols.value) do z
    ss_arr[:, :, z]
  end
  ax = Axis(
    f[1, 1],
    title="SureStart"
  )
  heatmap!(slice1, colormap=:grays)
  f
end

## Femoral Artery
fa_arr = load_dcm_array(dcms_fa);
begin
  fa_mask = copy(fa_arr)
  replace!(x -> x < -1000 ? 0 : x, fa_mask)
  fa_mask = fa_mask[:, :, end:-1:1]
  fa_mask = fa_mask .!= 0
end;

begin
  fa_mask_erode = zeros(size(fa_mask))
  for i in axes(fa_mask)
    fa_mask_erode[:, :, i] = erode(fa_mask[:, :, i])
  end
end

# @bind z_fa PlutoUI.Slider(axes(fa_mask, 3), show_value=true, default=size(fa_mask, 3) ÷ 15)

# # ╔═╡ 48246bdc-59e8-49aa-8785-03a064accbbd
# let
#   f = Figure(resolution=(2200, 2200))
#   ax = CairoMakie.Axis(
#     f[1, 1],
#     title="Femoral Artery Mask",
#     titlesize=40
#   )
#   heatmap!(fa_mask[:, :, z_fa], colormap=:grays)

#   ax = CairoMakie.Axis(
#     f[1, 2],
#     title="Femoral Artery Mask Eroded",
#     titlesize=40
#   )
#   heatmap!(fa_mask_erode[:, :, z_fa], colormap=:grays)

#   ax = CairoMakie.Axis(
#     f[2, 1],
#     title="Femoral Artery Mask Overlayed",
#     titlesize=40
#   )
#   heatmap!(v2_arr[:, :, z_fa], colormap=:grays)
#   heatmap!(fa_mask[:, :, z_fa], colormap=(:jet, 0.3))

#   ax = CairoMakie.Axis(
#     f[2, 2],
#     title="Femoral Artery Mask Eroded",
#     titlesize=40
#   )
#   heatmap!(v2_arr[:, :, z_fa], colormap=:grays)
#   heatmap!(fa_mask_erode[:, :, z_fa], colormap=(:jet, 0.3))
#   f
# end


## Crop Arrays via Limb Mask

bounding_box_indices = find_bounding_box(limb_mask; offset=(20, 20, 5))
begin
  v1_crop = crop_array(v1_arr, bounding_box_indices...)
  v2_crop = crop_array(v2_arr, bounding_box_indices...)
  limb_crop = crop_array(limb_mask, bounding_box_indices...)
  fa_crop = crop_array(fa_mask_erode, bounding_box_indices...)
end;


# Registration
v2_reg = register(v1_crop, v2_crop; num_iterations=10);

let
  f = Figure(resolution=(1200, 800))
  z_vols = Slider(f[0, 1:2], range = axes(v2_crop, 3), startvalue = size(v2_crop, 3) ÷ 15)

  slice1 = lift(z_vols.value) do z
    v2_crop[:, :, z] - v1_crop[:, :, z]
  end

  slice2 = lift(z_vols.value) do z
    v2_reg[:, :, z] - v1_crop[:, :, z]
  end

  ax = Axis(
    f[1, 1],
    title="Unregistered",
    titlesize=40
  )
  heatmap!(slice1)

  ax = Axis(
    f[1, 2],
    title="Registered",
    titlesize=40
  )
  heatmap!(slice2)
  display(f)
end

# Arterial Input Function (AIF)
## SureStart

# ╔═╡ 906f9427-4757-44d9-a957-2efd4b7f53f0
md"""
Select slice: $(@bind z1_aif PlutoUI.Slider(axes(ss_arr, 3), show_value = true, default = size(ss_arr, 3)))

Choose x location: $(@bind x1_aif PlutoUI.Slider(axes(ss_arr, 1), show_value = true, default = size(ss_arr, 1) ÷ 2))

Choose y location: $(@bind y1_aif PlutoUI.Slider(axes(ss_arr, 1), show_value = true, default = size(ss_arr, 1) ÷ 2))

Choose radius: $(@bind r1_aif PlutoUI.Slider(1:10, show_value = true))

Check box when ready: $(@bind aif1_ready PlutoUI.CheckBox())
"""

# ╔═╡ 5eb279b5-348f-4c00-bad2-c40f545739be
let
  f = Figure()
  ax = CairoMakie.Axis(
    f[1, 1],
    title="Sure Start AIF"
  )
  heatmap!(ss_arr[:, :, z1_aif], colormap=:grays)

  # Draw circle using parametric equations
  phi = 0:0.01:2π
  circle_x = r1_aif .* cos.(phi) .+ x1_aif
  circle_y = r1_aif .* sin.(phi) .+ y1_aif
  lines!(circle_x, circle_y, label="Aorta Mask (radius $r1_aif)", color=:red, linewidth=1)

  axislegend(ax)

  f
end

# ╔═╡ 7f1b44c5-924b-4541-8fff-e1298f9a9ef0
md"""
## V2 (AIF)
"""

# ╔═╡ 69bbc077-2523-47a1-8c48-b0dc5c8ef0c2
md"""
Select slice: $(@bind z2_aif PlutoUI.Slider(axes(v2_reg, 3), show_value = true))

Choose x location: $(@bind x2_aif PlutoUI.Slider(axes(v2_reg, 1), show_value = true, default = size(v2_reg, 1) ÷ 2))

Choose y location: $(@bind y2_aif PlutoUI.Slider(axes(v2_reg, 1), show_value = true, default = size(v2_reg, 1) ÷ 2))

Choose radius: $(@bind r2_aif PlutoUI.Slider(1:10, show_value = true))

Check box when ready: $(@bind aif2_ready PlutoUI.CheckBox())
"""

# ╔═╡ e9dad16b-07bc-4b87-be6b-959b078a5ba7
let
  f = Figure()
  ax = CairoMakie.Axis(
    f[1, 1],
    title="V2 AIF"
  )
  heatmap!(v2_reg[:, :, z2_aif], colormap=:grays)

  # Draw circle using parametric equations
  phi = 0:0.01:2π
  circle_x = r2_aif .* cos.(phi) .+ x2_aif
  circle_y = r2_aif .* sin.(phi) .+ y2_aif
  lines!(circle_x, circle_y, label="Femoral Artery Mask (radius $r2_aif)", color=:red, linewidth=0.5)

  axislegend(ax)

  f
end

# ╔═╡ 6864be65-b474-4fa2-84a6-0f8c789e669d
if aif1_ready && aif2_ready
  aif_vec_ss = compute_aif(ss_arr, x1_aif, y1_aif, r1_aif)
  aif_vec_v2 = compute_aif(v2_reg, x2_aif, y2_aif, r2_aif, z2_aif)
  aif_vec_gamma = [aif_vec_ss..., aif_vec_v2]
end

# ╔═╡ 1e21f95a-bc8a-492f-9a56-820dd3b3d066
md"""
# Time Attenuation Curve
"""

# ╔═╡ 0ba3a947-23be-49ca-ac2c-b0d295d096e9
md"""
## Extract SureStart Times
"""

# ╔═╡ 61604f83-e5f3-4aed-ac0b-1c630d7a1d67
if aif1_ready && aif2_ready
  time_vector_ss = scan_time_vector(dcms_ss)
  time_vector_ss_rel = time_vector_ss .- time_vector_ss[1]

  time_vector_v2 = scan_time_vector(dcms_v2)
  time_vector_v2_rel = time_vector_v2 .- time_vector_v2[1]

  delta_time = time_vector_v2[length(time_vector_v2)÷2] - time_vector_ss[end]

  time_vec_gamma = [time_vector_ss_rel..., delta_time + time_vector_ss_rel[end]]
end

# ╔═╡ e385d115-47e4-4a59-a6d0-6ea95455e901
md"""
## Gamma Variate
"""

# ╔═╡ e87721fa-5731-4a3e-bd8d-a17dc8fdeffc
if aif1_ready && aif2_ready
  # Upper and Lower Bounds
  lb = [-100.0, 0.0]
  ub = [100.0, 200.0]

  baseline_hu = mean(aif_vec_gamma[1:3])
  p0 = [0.0, baseline_hu]  # Initial guess (0, blood pool offset)

  time_vec_end, aif_vec_end = time_vec_gamma[end], aif_vec_gamma[end]

  fit = gamma_curve_fit(time_vec_gamma, aif_vec_gamma, time_vec_end, aif_vec_end, p0; lower_bounds=lb, upper_bounds=ub)
  opt_params = fit.param
end

# ╔═╡ fc43feee-9d9a-4af6-a76a-7dfbb927c0ae
if aif1_ready && aif2_ready
  x_fit = range(start=minimum(time_vec_gamma), stop=maximum(time_vec_gamma), length=500)
  y_fit = gamma(x_fit, opt_params, time_vec_end, aif_vec_end)
  dense_y_fit_adjusted = max.(y_fit .- baseline_hu, 0)

  area_under_curve = trapz(x_fit, dense_y_fit_adjusted)
  times = collect(range(time_vec_gamma[1], stop=time_vec_end, length=round(Int, maximum(time_vec_gamma))))

  input_conc = area_under_curve ./ (time_vec_gamma[19] - times[4])
  if length(aif_vec_gamma) > 2
    input_conc = mean([aif_vec_gamma[end], aif_vec_gamma[end-1]])
  end
end

# ╔═╡ c44b2487-bcd2-43f2-af89-2e3b0e1a54e8
if aif1_ready && aif2_ready
  let
    f = Figure()
    ax = Axis(
      f[1, 1],
      xlabel="Time Point",
      ylabel="Intensity (HU)",
      title="Fitted AIF Curve"
    )

    scatter!(time_vec_gamma, aif_vec_gamma, label="Data Points")
    lines!(x_fit, y_fit, label="Fitted Curve", color=:red)
    scatter!(time_vec_gamma[end-1], aif_vec_gamma[end-1], label="Trigger")
    scatter!(time_vec_gamma[end], aif_vec_gamma[end], label="V2")

    axislegend(ax, position=:lt)

    # Create the AUC plot
    time_temp = range(time_vec_gamma[3], stop=time_vec_gamma[end], length=round(Int, maximum(time_vec_gamma) * 1))
    auc_area = gamma(time_temp, opt_params, time_vec_end, aif_vec_end) .- baseline_hu

    # Create a denser AUC plot
    n_points = 1000  # Number of points for denser interpolation
    time_temp_dense = range(time_temp[1], stop=time_temp[end], length=n_points)
    auc_area_dense = gamma(time_temp_dense, opt_params, time_vec_end, aif_vec_end) .- baseline_hu

    for i = 1:length(auc_area_dense)
      lines!(ax, [time_temp_dense[i], time_temp_dense[i]], [baseline_hu, auc_area_dense[i] + baseline_hu], color=:cyan, linewidth=1, alpha=0.2)
    end

    f
  end
end

# ╔═╡ 5aecb6b9-a813-4cf8-8a7f-2da4a19a052e
md"""
# Whole Organ Perfusion
"""

# ╔═╡ d90057db-c68d-4b70-9247-1098bf129783
md"""
## Prepare Perfusion Details
"""

# ╔═╡ 140c1343-2a6e-4d4f-a3db-0d608d7e885c
if aif1_ready && aif2_ready
  header = dcms_v1[1].meta
  voxel_size = get_voxel_size(header)
  heart_rate = round(1 / (mean(diff(time_vec_gamma)) / 60))
  tissue_rho = 1.053 # tissue density : g/cm^2
  organ_mass = (sum(limb_crop) * tissue_rho * voxel_size[1] * voxel_size[2] * voxel_size[3]) / 1000 # g
  delta_hu = mean(v2_reg[limb_crop]) - mean(v1_crop[limb_crop])
  organ_vol_inplane = voxel_size[1] * voxel_size[2] / 1000
  v1_mass = sum(v1_crop[limb_crop]) * organ_vol_inplane
  v2_mass = sum(v2_reg[limb_crop]) * organ_vol_inplane
  flow = (1 / input_conc) * ((v2_mass - v1_mass) / (delta_time / 60)) # mL/min
  flow_map = (v2_reg - v1_crop) ./ (mean(v2_reg[limb_crop]) - mean(v1_crop[limb_crop])) .* flow # mL/min/g, voxel-by-voxel blood perfusion of organ of interest
  perf_map = flow_map ./ organ_mass
  perf = (flow / organ_mass, std(perf_map[limb_crop]))
end

# ╔═╡ a2aeaa04-3097-4dd0-8bab-5c98b74514b3
if aif1_ready && aif2_ready
  @bind z_flow PlutoUI.Slider(axes(flow_map, 3), show_value=true, default=size(flow_map, 3) ÷ 2)
end

# ╔═╡ 283c0ee5-0321-4f5d-9792-d593f49cafc1
if aif1_ready && aif2_ready
  let
    f = Figure()
    ax = CairoMakie.Axis(
      f[1, 1],
      title="Flow Map"
    )
    heatmap!(v2_reg[:, :, z_flow], colormap=:grays)
    heatmap!(flow_map[:, :, z_flow], colormap=(:jet, 0.6))

    Colorbar(f[1, 2], limits=(-10, 300), colormap=:jet,
      flipaxis=false)
    f
  end
end

# ╔═╡ c740d05c-d00a-42c0-a957-7b5fd1b14d4c
heatmap(flow_map[:, :, z_flow], colormap=:jet)

# ╔═╡ 89b921b6-5aa1-46dc-9e08-e2fe92a93543
flow_map[limb_crop]

# ╔═╡ 832c5505-00bf-4f0b-850f-3af8dd0a1558
flow_map[limb_crop.==0] .= NaN

# ╔═╡ ff014ee8-6811-4087-b367-fd7337c56f87
heatmap(v2_reg[:, :, z_flow], colormap=:grays)

# ╔═╡ 1befeeba-40bb-4310-8441-6609fc82dc21
md"""
## Results
"""

# ╔═╡ c0dcbc56-be6e-47ba-b3e8-9f12ec469e4b
col_names = [
  "perfusion",
  "perfusion_std",
  "perfusion_ref",
  "flow",
  "flow_std",
  "delta_time",
  "mass",
  "delta_hu",
  "heart_rate"
]

# ╔═╡ e79e2a10-78d0-4571-b601-daf9d164b0c9
if aif1_ready && aif2_ready
  col_vals = [
    perf[1],
    perf[2],
    length(perf) == 3 ? perf[3] : missing,
    perf[1] * organ_mass,
    perf[2] * organ_mass,
    delta_time,
    organ_mass,
    delta_hu,
    heart_rate
  ]
end

# ╔═╡ a861ded4-dbcf-4f06-a1b4-17d8f8ddf214
if aif1_ready && aif2_ready
  df = DataFrame(parameters=col_names, values=col_vals)
end

# ╔═╡ 2c8c49dc-b1f5-4f55-ab8d-d3331d4ec23d
md"""
# Visualiazation
"""

# ╔═╡ aebc8d11-9072-425b-9cb7-9ea9c704c9ba
typeof(pts_meshes), pts_meshes

# ╔═╡ d0f7c3e3-8ed1-4f33-aac5-267d182ec020
# rand(pts_meshes, 10000) |> viz

# ╔═╡ a00f1e1b-12fa-430e-b737-1333d9e0ae31
begin
  pts_tuple = Tuple{Int64,Int64,Int64}[]

  for i in axes(pts_matrix, 1)
    row = pts_matrix[i, :]
    row_tuple = tuple(row[1], row[2], row[3])
    push!(pts_tuple, row_tuple)
  end

  pts_tuple = vec(pts_tuple)
end

# ╔═╡ 31a5d171-e789-4705-8c24-d103f87a2d06
typeof(pts_tuple)

# ╔═╡ 18d1ecae-9475-413d-aff4-6dad8136e4a5
md"""
Select azimuth: $(@bind azimuth PlutoUI.Slider(0:0.01:1, show_value=true, default=0.69))

Select elevation: $(@bind elevation PlutoUI.Slider(0:0.01:1, show_value=true, default=0.18))

Select perspectiveness: $(@bind perspectiveness PlutoUI.Slider(0:0.01:1, show_value=true, default=0.5))
"""

# ╔═╡ b08690b4-7a7c-421d-a683-6fb2494f73bc
begin

  # x = y = z = 1:10
  # f(x, y, z) = x^2 + y^2 + z^2
  # vals = [f(ix, iy, iz) for ix in x, iy in y, iz in z]

  render_data = [pts_tuple[i] for i in 1:1:length(pts_tuple)]

  fig, ax, obj = mesh(render_data;
    color=[tri[3] for tri in render_data for i in 1:2],
    colormap=:jet1,
    colorrange=(100, 200),
    transparency=false,
    shading=true,
    figure=(;
      resolution=(1200, 1000)
    ),
    axis=(;
      type=Axis3,
      perspectiveness=perspectiveness,
      azimuth=azimuth * pi,
      elevation=elevation * pi,
      xlabel="x label",
      ylabel="y label",
      zlabel="z label",
      aspect=(1, 1, 1))
  )

  Colorbar(fig[1, 2], obj;
    flipaxis=false, label="color", height=Relative(0.5))
  colsize!(fig.layout, 1, Aspect(1, 1.0))
  fig

end

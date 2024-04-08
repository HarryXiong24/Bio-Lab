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

# ╔═╡ fbd1393c-8d72-4d95-b4d7-23e59a014368
# ╠═╡ show_logs = false
begin
    using Pkg; Pkg.activate(; temp = true)

    Pkg.add("DICOM")
    Pkg.add("CairoMakie")
    Pkg.add("PlutoUI")
    Pkg.add("ImageMorphology")
    Pkg.add("Statistics")
    Pkg.add("DataFrames")
	Pkg.add("CSV")
	Pkg.add(url = "https://github.com/Dale-Black/PerfusionImaging.jl")

    using DICOM, CairoMakie, PlutoUI, ImageMorphology, Statistics, CSV, DataFrames
	using PerfusionImaging
end

# ╔═╡ 24e7db28-507b-46ee-8bd6-e4bda794d4f3
# ╠═╡ show_logs = false
begin
	Pkg.add("Dierckx")
	using Dierckx
end

# ╔═╡ 9ce12616-27aa-4161-bce0-599935ee6e9b
TableOfContents()

# ╔═╡ dd1d95d3-960f-4e47-b3c8-54b77eb1323f
md"""
# Load DICOMs
"""

# ╔═╡ c33cd910-a3c3-40b0-83b8-0ecfaf011355
md"""
## Choose Main Path
"""

# ╔═╡ 53bf8d77-2aa0-4f9b-a2a6-393a2bd48de6
md"""
**Enter Root Directory**

Provide the path to the main folder containing the raw DICOM files and segmentations. Then click submit.

$(@bind root_path confirm(PlutoUI.TextField(60; default = raw"Z:\Patient_UT\CTP001")))
"""

# ╔═╡ fb0efec0-8345-4e89-a551-8b5cb13366c1
md"""
## Volumes
"""

# ╔═╡ a9205e02-0e0e-4508-a2c8-bff4efb60a1d
function volume_paths(dcm)
	
	return PlutoUI.combine() do Child
		
		inputs = [
			md""" $(dcm): $(
				Child(PlutoUI.TextField(60; default = "DICOM"))
			)"""
		]
		
		md"""
		**Upload Volume Scans**

		Provide the folder names for the necessary files. Input the name of the folder containing the DICOM scans (default is `DICOM`)
		
		$(inputs)
		"""
	end
end

# ╔═╡ 424f14d2-b100-4e46-a9b2-46a089b9f388
@bind volume_files confirm(volume_paths("Enter DICOM folder name"))

# ╔═╡ 71929f05-8713-4971-81f2-7b8ef78a46aa
volume_files

# ╔═╡ 05f2eb3e-ca9c-4c70-8f7f-4848f391dfa7
dicom_path = joinpath(root_path, volume_files[1])

# ╔═╡ 3cd36dc0-4021-4deb-9fcf-1095fd755a28
begin
	dcms = []
	for folder in readdir(dicom_path)
		dcm_dir = joinpath(dicom_path, folder)
		if isdir(dcm_dir)
			dcm = dcmdir_parse(dcm_dir)
			push!(dcms, dcm)
		end
	end

	sort!(dcms, by=dcm -> parse(Float64, dcm[1].meta[tag"Acquisition Time"]))
end

# ╔═╡ bfb2fc31-4f6f-470a-a33c-530f080a7615
dcms

# ╔═╡ 127a5453-1841-4997-a627-762dc361cfe3
begin
	dcm_arrays = []
	for dcm in dcms
		dcm_array = load_dcm_array(dcm)
		push!(dcm_arrays, dcm_array)
	end
end

# ╔═╡ 875afd8a-9872-4781-be02-dc74281677a9
dcm_arrays

# ╔═╡ 91439da3-0c6d-4373-b8ea-4c514788cb04
md"""
### Visualize V1 & V2
"""

# ╔═╡ 4da472f0-6a86-4649-b7d0-0b2f6bc18840
begin
	v1_arr = dcm_arrays[1]
	v2_arr = dcm_arrays[2]
end;

# ╔═╡ 49e76445-a328-467f-94bb-7eb579929525
@bind z_vols PlutoUI.Slider(axes(v1_arr, 3), show_value = true, default = size(v1_arr, 3) ÷ 15)

# ╔═╡ 39aa1ce3-f48c-4ae0-bae0-3a3ef836571f
let
    f = Figure(resolution = (2200, 1400))
    ax = CairoMakie.Axis(
        f[1, 1],
        title = "V1",
        titlesize = 40
    )
    heatmap!(v1_arr[:, :, z_vols], colormap = :grays)

    ax = CairoMakie.Axis(
        f[1, 2],
        title = "V2",
        titlesize = 40
    )
    heatmap!(v2_arr[:, :, z_vols], colormap = :grays)
    f
end

# ╔═╡ d3c72183-1a83-4cab-b840-7d387afda2be
md"""
## Crop Arrays via Mask
"""

# ╔═╡ 0da24164-57a5-49bc-896e-ccc618e3d769
function create_mask(array::AbstractArray{T, 3}, offset::Tuple{Int, Int, Int}) where T
    # Initialize a mask array filled with zeros
    mask = falses(size(array))

    # Get the dimensions
    x_dim, y_dim, z_dim = size(array)

    # Extract individual offsets
    x_offset, y_offset, z_offset = offset

    # Validate the offsets
    if x_offset >= x_dim || y_offset >= y_dim || z_offset >= z_dim
        println("At least one offset is too large for the given array dimensions.")
        return mask
    end

    # Loop through the array and set the mask elements away from the borders
    for x in (1 + x_offset):(x_dim - x_offset)
        for y in (1 + y_offset):(y_dim - y_offset)
            for z in (1 + z_offset):(z_dim - z_offset)
                mask[x, y, z] = true
            end
        end
    end
    
    return mask
end

# ╔═╡ 9f82d73f-ed2c-4723-9c68-6e935f28ba3c
mask = create_mask(v1_arr, (100, 100, 40));

# ╔═╡ 219aac61-5e03-4993-9c05-fa2d4a2629a2
bounding_box_indices = find_bounding_box(mask)

# ╔═╡ 0d568fc5-e69c-434d-b0f2-8b998adfb21c
begin
	volumes_cropped = []
	for dcm in dcm_arrays
		volume_cropped = crop_array(dcm, bounding_box_indices...)
		push!(volumes_cropped, volume_cropped)
	end
end

# ╔═╡ ba8ddf80-8cf6-49cb-8f51-ffe10de85914
md"""
# Registration
"""

# ╔═╡ a30ec56d-e4c9-4dfa-b2f0-c427574e2eee
begin
	volume_regs = []
	push!(volume_regs, volumes_cropped[1])
	for dcm in volumes_cropped[2:end]
		v_reg = register(volumes_cropped[1], dcm; num_iterations = 10)
		push!(volume_regs, v_reg)
	end
end

# ╔═╡ c1a35cbf-8dae-4218-b806-9b0661929fa8
@bind z_reg PlutoUI.Slider(axes(volume_regs[1], 3), show_value = true, default = size(volume_regs[1], 3) ÷ 2)

# ╔═╡ 294b2a3b-f169-46ee-bdd0-815bf85e7d93
let
    f = Figure(resolution = (2200, 1400))
    ax = CairoMakie.Axis(
        f[1, 1],
        title = "Unregistered",
        titlesize = 40
    )
    heatmap!(volumes_cropped[2][:, :, z_reg] - volumes_cropped[1][:, :, z_reg])

    ax = CairoMakie.Axis(
        f[1, 2],
        title = "Registered",
        titlesize = 40
    )
	heatmap!(volume_regs[2][:, :, z_reg] - volume_regs[1][:, :, z_reg])
    f
end

# ╔═╡ 956d2e21-43ed-4c99-850c-c2750a4ee5c1
md"""
# Arterial Input Function (AIF)
"""

# ╔═╡ 906388ed-14e5-43a6-99b9-9e87e9d6af2c
md"""
Select volume number: $(@bind v_num1 PlutoUI.Slider(eachindex(volume_regs), show_value = true, default = length(volume_regs)))

Select slice: $(@bind z1_aif PlutoUI.Slider(axes(volume_regs[end], 3), show_value = true, default = size(volume_regs[end], 3) ÷ 2))

Choose x location: $(@bind x1_aif PlutoUI.Slider(axes(volume_regs[end], 1), show_value = true, default = size(volume_regs[end], 1) ÷ 2))

Choose y location: $(@bind y1_aif PlutoUI.Slider(axes(volume_regs[end], 1), show_value = true, default = size(volume_regs[end], 1) ÷ 2))

Choose radius: $(@bind r1_aif PlutoUI.Slider(1:10, show_value = true))

Check box when ready: $(@bind aif1_ready PlutoUI.CheckBox())
"""

# ╔═╡ 985b6149-cab1-4ca1-9134-0ff94581f4a1
let
	f = Figure()
	ax = CairoMakie.Axis(
		f[1, 1],
		title = "Sure Start AIF"
	)
	heatmap!(volume_regs[v_num1][:, :, z1_aif], colormap = :grays)

	# Draw circle using parametric equations
	phi = 0:0.01:2π
	circle_x = r1_aif .* cos.(phi) .+ x1_aif
	circle_y = r1_aif .* sin.(phi) .+ y1_aif
	lines!(circle_x, circle_y, label="Aorta Mask (radius $r1_aif)", color=:red, linewidth = 1)

	axislegend(ax)
	
	f
end

# ╔═╡ 58f97016-3d8f-4a9d-8dc3-f96f15cb16d4
begin
	aif_array = zeros(size(volume_regs[1])[1:2]..., length(volume_regs))
	for (idx, vol) in enumerate(volume_regs)
		aif_array[:, :, idx] = vol[:, :, z1_aif]
	end
end

# ╔═╡ 1009066d-6683-4fa8-9784-135b1d0dac34
if aif1_ready
	aif_vec_gamma = compute_aif(aif_array, x1_aif, y1_aif, r1_aif)
end

# ╔═╡ 1207c7d6-4a7e-4144-991f-a1bf9ab7388b
peak, peak_idx = findmax(aif_vec_gamma)

# ╔═╡ 3b3324bd-439f-4045-875f-e478e4644137
md"""
# Time Attenuation Curve
"""

# ╔═╡ 349887ab-0a6e-4ada-ad8b-8beb06771a57
md"""
## Extract Scan Times
"""

# ╔═╡ eeabf856-c19a-452d-9f47-fb10337c63de
begin
	# Initialize an empty array to store scan times
	scan_times = []
	
	# Iterate through each sub-vector in dcms
	for dcm in dcms
	    # Extract the "Acquisition Time" from the meta field of the first element in the sub-vector
	    acquisition_time = dcm_time_2sec(dcm[1].meta[tag"Acquisition Time"])
	    
	    # Convert the acquisition_time to Float64 (or keep as is, depending on the actual type)
	    # acquisition_time = parse(Float64, acquisition_time)
	    
	    # Store the extracted time into the scan_times array
	    push!(scan_times, acquisition_time)
	end
end

# ╔═╡ ca5bf3ce-f5ad-4a5a-9b0a-f49efc996c9a
scan_times

# ╔═╡ b44e28ad-e10a-48b7-ba8a-617db019413a
if aif1_ready
	time_vector_ss = scan_times
	time_vector_ss_rel = time_vector_ss .- time_vector_ss[1]
	time_vec_gamma = copy(time_vector_ss_rel)
end

# ╔═╡ 45578dd1-efa2-465d-ab8a-f25fbf5ddd7c
md"""
## Gamma Variate
"""

# ╔═╡ 21d1ae53-6ca0-47b3-9c8d-f6846fbdc10e
if aif1_ready
	# Upper and Lower Bounds
	lb = [-100.0, 0.0]
	ub = [100.0, 200.0]

	baseline_hu = mean(aif_vec_gamma[1:3])
	p0 = [0.0, baseline_hu]  # Initial guess (0, blood pool offset)

	# time_vec_end, aif_vec_end = time_vec_gamma[end], aif_vec_gamma[end]
	time_vec_end, aif_vec_end = time_vec_gamma[peak_idx], aif_vec_gamma[peak_idx]

	fit = gamma_curve_fit(time_vec_gamma, aif_vec_gamma, time_vec_end, aif_vec_end, p0; lower_bounds = lb, upper_bounds = ub)
	opt_params = fit.param
end

# ╔═╡ f4071716-14fc-4a81-9b5a-8664ca6ad5f7
if aif1_ready
	x_fit = range(start = minimum(time_vec_gamma), stop = maximum(time_vec_gamma), length=500)
	y_fit = gamma(x_fit, opt_params, time_vec_end, aif_vec_end)
	dense_y_fit_adjusted = max.(y_fit .- baseline_hu, 0)

	area_under_curve = trapz(x_fit, dense_y_fit_adjusted)
	times = collect(range(time_vec_gamma[1], stop=time_vec_end, length=round(Int, maximum(time_vec_gamma))))
	
	input_conc = area_under_curve ./ (time_vec_gamma[end-4] - times[1])
	if length(aif_vec_gamma) > 2
		input_conc = mean([aif_vec_gamma[end], aif_vec_gamma[end-1]])
	end
end

# ╔═╡ a20eee68-1d51-4692-8e07-c2c9a707138b
md"""
## Time to Peak
"""

# ╔═╡ 4b58580f-27c1-4542-9687-709d2f5b56ed
# Fit a spline to the data
spline = Spline1D(x_fit, y_fit, k=5, s=0)

# ╔═╡ 15edff0e-08c3-4f2e-a1dc-a9d4f1dd49b6
# Compute the second derivative
second_derivative = derivative(spline, x_fit, 2)

# ╔═╡ 2634df11-5f10-4c62-931c-4ad4d3117e7e
begin
	# Find the x value of maximum upward concavity
	max_upward_concavity_idx = argmax(second_derivative)
	max_upward_concavity_x = x_fit[max_upward_concavity_idx]
end

# ╔═╡ 9d27b15d-7d64-40b0-9920-dbfaf7a26471
begin
    # Find the nearest data point to this x value
    trigger_idx = findmin(abs.(time_vec_gamma .- max_upward_concavity_x))[2]
    trigger_time = Int(round(time_vec_gamma[trigger_idx]))
end

# ╔═╡ 81bb4411-782f-41aa-836c-800a2c7244c8
time_to_peak = time_vector_ss_rel[peak_idx] - trigger_time

# ╔═╡ ce9eaf15-954c-4993-b187-00fcce1a29aa
if aif1_ready
    let
        f = Figure()
        ax = Axis(
            f[1, 1],
            xlabel = "Time Point (s)",
            ylabel = "Intensity (HU)",
            title = "Fitted AIF Curve ($(basename(root_path)))"
        )

        scatter!(time_vec_gamma, aif_vec_gamma, label="Data Points")
        lines!(x_fit, y_fit, label="Fitted Curve", color = :red)
        scatter!(time_vec_gamma[trigger_idx], aif_vec_gamma[trigger_idx], label = "Trigger")
        scatter!(time_vec_gamma[peak_idx], aif_vec_gamma[peak_idx], label = "Peak")

        axislegend(ax, position=:lt)

        # # Create the AUC plot
        # time_temp = range(time_vec_gamma[3], stop=time_vec_gamma[end], length=round(Int, maximum(time_vec_gamma) * 1))
        # auc_area = gamma(time_temp, opt_params, time_vec_end, aif_vec_end) .- baseline_hu

        # # Create a denser AUC plot
        # n_points = 1000  # Number of points for denser interpolation
        # time_temp_dense = range(time_temp[1], stop=time_temp[end], length=n_points)
        # auc_area_dense = gamma(time_temp_dense, opt_params, time_vec_end, aif_vec_end) .- baseline_hu

        # for i = 1:length(auc_area_dense)
        #     lines!(ax, [time_temp_dense[i], time_temp_dense[i]], [baseline_hu, auc_area_dense[i] + baseline_hu], color=:cyan, linewidth=1, alpha=0.2)
        # end
        save(joinpath(dirname(root_path), "output", "$(basename(root_path)).png"), f)

        f
    end
end

# ╔═╡ ac190a28-bdca-4f7b-b071-ee7ef22509ed
df = DataFrame(
    "Patient ID" => basename(root_path),
    "TTP (s)" => time_to_peak
)

# ╔═╡ 103209b1-4b7a-48ee-91d0-fc7d929489e7
CSV.write(joinpath(dirname(root_path), "output", "$(basename(root_path)).csv"), df)

# ╔═╡ Cell order:
# ╠═fbd1393c-8d72-4d95-b4d7-23e59a014368
# ╠═9ce12616-27aa-4161-bce0-599935ee6e9b
# ╟─dd1d95d3-960f-4e47-b3c8-54b77eb1323f
# ╟─c33cd910-a3c3-40b0-83b8-0ecfaf011355
# ╟─53bf8d77-2aa0-4f9b-a2a6-393a2bd48de6
# ╟─fb0efec0-8345-4e89-a551-8b5cb13366c1
# ╟─424f14d2-b100-4e46-a9b2-46a089b9f388
# ╟─a9205e02-0e0e-4508-a2c8-bff4efb60a1d
# ╠═71929f05-8713-4971-81f2-7b8ef78a46aa
# ╠═05f2eb3e-ca9c-4c70-8f7f-4848f391dfa7
# ╠═3cd36dc0-4021-4deb-9fcf-1095fd755a28
# ╠═bfb2fc31-4f6f-470a-a33c-530f080a7615
# ╠═127a5453-1841-4997-a627-762dc361cfe3
# ╠═875afd8a-9872-4781-be02-dc74281677a9
# ╟─91439da3-0c6d-4373-b8ea-4c514788cb04
# ╠═4da472f0-6a86-4649-b7d0-0b2f6bc18840
# ╟─49e76445-a328-467f-94bb-7eb579929525
# ╟─39aa1ce3-f48c-4ae0-bae0-3a3ef836571f
# ╟─d3c72183-1a83-4cab-b840-7d387afda2be
# ╠═0da24164-57a5-49bc-896e-ccc618e3d769
# ╠═9f82d73f-ed2c-4723-9c68-6e935f28ba3c
# ╠═219aac61-5e03-4993-9c05-fa2d4a2629a2
# ╠═0d568fc5-e69c-434d-b0f2-8b998adfb21c
# ╟─ba8ddf80-8cf6-49cb-8f51-ffe10de85914
# ╠═a30ec56d-e4c9-4dfa-b2f0-c427574e2eee
# ╟─c1a35cbf-8dae-4218-b806-9b0661929fa8
# ╟─294b2a3b-f169-46ee-bdd0-815bf85e7d93
# ╟─956d2e21-43ed-4c99-850c-c2750a4ee5c1
# ╟─906388ed-14e5-43a6-99b9-9e87e9d6af2c
# ╟─985b6149-cab1-4ca1-9134-0ff94581f4a1
# ╠═58f97016-3d8f-4a9d-8dc3-f96f15cb16d4
# ╠═1009066d-6683-4fa8-9784-135b1d0dac34
# ╠═1207c7d6-4a7e-4144-991f-a1bf9ab7388b
# ╟─3b3324bd-439f-4045-875f-e478e4644137
# ╟─349887ab-0a6e-4ada-ad8b-8beb06771a57
# ╠═eeabf856-c19a-452d-9f47-fb10337c63de
# ╠═ca5bf3ce-f5ad-4a5a-9b0a-f49efc996c9a
# ╠═b44e28ad-e10a-48b7-ba8a-617db019413a
# ╟─45578dd1-efa2-465d-ab8a-f25fbf5ddd7c
# ╠═21d1ae53-6ca0-47b3-9c8d-f6846fbdc10e
# ╠═f4071716-14fc-4a81-9b5a-8664ca6ad5f7
# ╟─a20eee68-1d51-4692-8e07-c2c9a707138b
# ╠═24e7db28-507b-46ee-8bd6-e4bda794d4f3
# ╠═4b58580f-27c1-4542-9687-709d2f5b56ed
# ╠═15edff0e-08c3-4f2e-a1dc-a9d4f1dd49b6
# ╠═2634df11-5f10-4c62-931c-4ad4d3117e7e
# ╠═9d27b15d-7d64-40b0-9920-dbfaf7a26471
# ╠═81bb4411-782f-41aa-836c-800a2c7244c8
# ╟─ce9eaf15-954c-4993-b187-00fcce1a29aa
# ╠═ac190a28-bdca-4f7b-b071-ee7ef22509ed
# ╠═103209b1-4b7a-48ee-91d0-fc7d929489e7

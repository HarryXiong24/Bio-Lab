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

# ╔═╡ d5a90ce4-8f7d-46a0-8cc6-aecb3728c894
# ╠═╡ show_logs = false
using Pkg; Pkg.activate("."); Pkg.instantiate()

# ╔═╡ 322de146-6d93-455b-b1d7-c53e0b1c43a4
using PlutoUI: TableOfContents, bind, TextField, Slider, confirm, combine, CheckBox

# ╔═╡ c46fc2df-5a2c-4076-9002-89288a723895
using CairoMakie: Figure, Axis, heatmap, heatmap!, lines!, scatter!, axislegend, Colorbar

# ╔═╡ 09a5239b-5534-4923-aa25-538cee392392
using DICOM: dcmdir_parse

# ╔═╡ c92a9261-47c0-4dc1-a7d0-df25a84f7613
using ImageMorphology: erode

# ╔═╡ 2ad6d64d-d3d8-4d78-84fd-91786d3e1cb6
using Statistics: mean, std

# ╔═╡ 8ed90773-464e-408f-9a65-10a2587b0c60
using DataFrames: DataFrame

# ╔═╡ e78b9d34-94dd-494b-a8ef-1c4af86187b6
# ╠═╡ show_logs = false
using PerfusionImaging: load_dcm_array, find_bounding_box, crop_array, register, compute_aif, scan_time_vector, gamma_curve_fit, gamma, trapz, get_voxel_size, make_volume_uniform, calculate_flow

# ╔═╡ 0aff8608-44d1-498c-9ba8-568fd8df9ac2
md"""
!!! info "Installing packages"
	If you aren't in a proper Julia environment with all of the below packages already installed you will need to add each package before importing it. If you plan on using this notebook over and over again, then set up a [proper environment](https://modernjuliaworkflows.github.io/pages/writing/writing/#:~:text=julia%3E%20Pluto.run()-,Environments,-TLDR%3A%20Julia%20environments). If you are only using this once, then you can make a temporary environment with the steps below:

	```julia
    using Pkg; Pkg.activate(; temp = true)

    Pkg.add("DICOM")
    Pkg.add("CairoMakie")
    Pkg.add("PlutoUI")
    Pkg.add("ImageMorphology")
    Pkg.add("Statistics")
    Pkg.add("DataFrames")
	Pkg.add(url = "https://github.com/Dale-Black/PerfusionImaging.jl")
	```
"""

# ╔═╡ 8d3f6904-99a7-4bbb-9ef9-89139319c15e
import GLMakie

# ╔═╡ 8b50aaf5-e083-4ddc-a19a-b2e8d2d9c369
TableOfContents()

# ╔═╡ 3c6dbe47-c343-4d17-b653-74a26bec7092
md"""
# Load DICOMs
"""

# ╔═╡ db7a894b-9b7a-4924-bd8b-b02f46bf6629
md"""
## Choose Main Path
"""

# ╔═╡ 103a11a0-fb1e-4ffe-9881-9e3d863f00ab
md"""
**Enter Root Directory**

Provide the path to the main folder containing the raw DICOM files and segmentations. Then click submit.

$(@bind root_path confirm(TextField(60; default = raw"\\polaris.radsci.uci.edu\Data4\bpziemer\animal_perfusion_data\12_02_20_data\CardiacPerfusion\Cardiac_set_1\Acq_02_Baseline")))
"""

# ╔═╡ 7be21dd4-b5d4-4c90-9d8d-38597dbf1fda
md"""
## V1 & V2
"""

# ╔═╡ 5007245d-2faa-4e9b-af3f-4eb73b1b4fea
function volume_paths(dcm, v1, v2)
	
	return combine() do Child
		
		inputs = [
			md""" $(dcm): $(
				Child(TextField(60; default = "DICOM"))
			)""",
			md""" $(v1): $(
				Child(TextField(60; default = "01"))
			)""",
			md""" $(v2): $(
				Child(TextField(60; default = "02"))
			)"""
		]
		
		md"""
		**Upload Volume Scans**

		Provide the folder names for the necessary files. First input the name of the folder containing the DICOM scans (default is `DICOM`) and then enter the names of the v1 and v2 scans (default is `01` and `02`, respectively). Then click submit.
		
		$(inputs)
		"""
	end
end

# ╔═╡ dbcc0552-8975-4b2e-8008-cefe67d7ffe6
@bind volume_files confirm(volume_paths("Enter DICOM folder name", "Enter volume scan 1 folder name", "Enter volume scan 2 folder name"))

# ╔═╡ 1552936a-1f0a-492a-96d9-785fae6ea7b6
volume_files

# ╔═╡ 7e0d6528-5b97-40fd-b240-493892bb326f
dicom_path = joinpath(root_path, volume_files[1])

# ╔═╡ 1f24e288-6627-4363-8f23-dd063058ba64
path_v1 = joinpath(dicom_path, volume_files[2])

# ╔═╡ 3418eae3-b912-4d18-a218-f020258716b7
path_v2 = joinpath(dicom_path, volume_files[3])

# ╔═╡ f383d83c-563a-4660-829d-d997d2943930
dcms_v1 = dcmdir_parse(path_v1)

# ╔═╡ e2615e9a-4209-481a-ac1e-ab81ddc8c66d
dcms_v2 = dcmdir_parse(path_v2)

# ╔═╡ e7088b2c-15a1-4ceb-9a3c-c5df239cd95d
md"""
## SureStart
"""

# ╔═╡ 15c8373a-efed-4d74-92b4-124aec7557f7
md"""
**Enter SureStart Folder**

Input the name of the folder containing the SureStart scans (default is `SureStart`). Then click submit

$(@bind surestart_folder confirm(TextField(60; default = "SureStart")))
"""

# ╔═╡ 7ebead3c-7779-49f1-b8ae-3f51a8bcb17b
surestart_path = joinpath(root_path, surestart_folder);

# ╔═╡ a3d5c629-d16f-4a1f-9072-bfe87c8cccde
dcms_ss = dcmdir_parse(surestart_path);

# ╔═╡ 1d2520fe-ad71-483d-87ad-7b0ab2a417c1
md"""
## Segmentations
"""

# ╔═╡ ddfde220-1b0d-4ae5-97cc-232df7b95bc8
md"""
**Enter Segmentation Root Folder**

Input the name of the folder containing the segmentation(s) (default is `SEGMENT_dcm`). Then click submit

$(@bind segment_folder confirm(TextField(60; default = "SEGMENT_dcm")))
"""

# ╔═╡ fc37db24-ba08-495a-897a-6c230c7ac24e
segmentation_root = joinpath(root_path, "SEGMENT_dcm")

# ╔═╡ 1416804f-54af-4a04-9a65-e668f94b564a
md"""
### Left Myocardium
"""

# ╔═╡ 2e96e18d-14da-4cfc-b42e-7fc55a5bdebb
md"""
**Enter Left Myocardium Segmentation Folder**

Input the name of the folder containing the SureStart scans (default is `LEFT_MYOCARDIUM_dcm`). Then click submit

$(@bind lm_folder confirm(TextField(60; default = "LEFT_MYOCARDIUM_dcm")))
"""

# ╔═╡ 436f2b81-549d-4787-ac19-b9792714cc5b
lm_path = joinpath(segmentation_root, lm_folder)

# ╔═╡ 39964974-7b83-4ec7-956e-1f023b9eff19
dcms_lm = dcmdir_parse(lm_path)

# ╔═╡ 2a409a59-1ec3-4b87-b75e-e059717195e6
md"""
### Right Myocardium
"""

# ╔═╡ aed40a87-9028-4ad2-a553-a12251958139
md"""
**Enter Right Myocardium Segmentation Folder**

Input the name of the folder containing the SureStart scans (default is `RIGHT_MYOCARDIUM_dcm`). Then click submit

$(@bind rm_folder confirm(TextField(60; default = "RIGHT_MYOCARDIUM_dcm")))
"""

# ╔═╡ 10d6ddfe-6018-4432-b382-1783f5f0ab38
rm_path = joinpath(segmentation_root, rm_folder)

# ╔═╡ 3d221a76-4a1c-446d-b0e0-04b4093d1e64
dcms_rm = dcmdir_parse(rm_path)

# ╔═╡ f7473163-4c31-440f-8be5-ba9336d89a14
md"""
### Aorta
"""

# ╔═╡ 8e7790bf-aa93-4c65-925c-f29a4b1579ef
md"""
**Enter Aorta Segmentation Folder**

Input the name of the folder containing the SureStart scans (default is `AORTA_dcm`). Then click submit

$(@bind aorta_folder confirm(TextField(60; default = "AORTA_dcm")))
"""

# ╔═╡ a07761af-05c6-443c-9272-646b19e5a7cf
aorta_path = joinpath(segmentation_root, aorta_folder)

# ╔═╡ 4860509d-3067-4e0d-bf7b-91f8e25f1c5a
dcms_aorta = dcmdir_parse(aorta_path);

# ╔═╡ f129d1e0-43be-4ac5-bfe2-b901da8e80d0
md"""
# Convert DICOMs to Arrays
"""

# ╔═╡ 5749d046-e946-4889-8f88-43130598a472
md"""
## V1 & V2
"""

# ╔═╡ 16c123cd-3f8f-4163-8028-63a5f52dae3d
begin
	v1_arr = load_dcm_array(dcms_v1)
	v2_arr = load_dcm_array(dcms_v2)
end;

# ╔═╡ 2b803e51-91bb-4165-9341-944c08e09398
@bind z_vols Slider(axes(v1_arr, 3), show_value = true, default = size(v1_arr, 3) ÷ 15)

# ╔═╡ 87d3268a-e5cf-4c60-b8c1-6921373daa34
let
    f = Figure(size = (800, 500))
    ax = Axis(
        f[1, 1],
        title = "V1 (No Contrast)",
        titlesize = 20
    )
    heatmap!(v1_arr[:, :, z_vols], colormap = :grays)

    ax = Axis(
        f[1, 2],
        title = "V2 (Contrast)",
        titlesize = 20
    )
    heatmap!(v2_arr[:, :, z_vols], colormap = :grays)
    f
end

# ╔═╡ f14623fd-94bc-4742-9c32-357552052ad7
md"""
## Left Myocardium
"""

# ╔═╡ 3eafac3e-0756-485f-949e-6a5d49b761b7
lm_arr = load_dcm_array(dcms_lm);

# ╔═╡ 2f5a80bb-eebd-4f68-98cb-77a1cb69ab1a
begin
    lm_mask = copy(lm_arr)
    replace!(x -> x < -1000 ? 0 : x, lm_mask)
    lm_mask = lm_mask[:, :, end:-1:1]
	lm_mask = lm_mask .!= 0;
end;

# ╔═╡ 1d27ebad-017c-410a-bacc-481aa94ef23a
@bind z_lm Slider(axes(lm_mask, 3), show_value = true, default = size(lm_mask, 3) ÷ 2)

# ╔═╡ 4c7b7f87-6b3a-45df-996f-3d4bb1b55938
let
    f = Figure(size = (800, 500))
    ax = Axis(
        f[1, 1],
        title = "LM Mask",
		titlesize = 30
    )
    heatmap!(lm_mask[:, :, z_lm], colormap = :grays)

    ax = Axis(
        f[1, 2],
        title = "LM Mask Overlayed",
		titlesize = 30
    )
    heatmap!(v2_arr[:, :, z_lm], colormap = :grays)
    heatmap!(lm_mask[:, :, z_lm], colormap = (:jet, 0.3))
    f
end

# ╔═╡ 03cf3563-c4a0-47cc-80b8-d33ab98fcaa5
md"""
## Right Myocardium
"""

# ╔═╡ 014d6ab9-ee84-41ee-8af8-34833fe7060c
rm_arr = load_dcm_array(dcms_rm);

# ╔═╡ f8c4d8cf-eb63-4ab3-88ba-b848c522d71a
begin
    rm_mask = copy(rm_arr)
    replace!(x -> x < -1000 ? 0 : x, rm_mask)
    rm_mask = rm_mask[:, :, end:-1:1]
	rm_mask = rm_mask .!= 0;
end;

# ╔═╡ cc431ca3-f3d1-4775-bb8f-a2a92db2943b
@bind z_rm Slider(axes(rm_mask, 3), show_value = true, default = size(rm_mask, 3) ÷ 2)

# ╔═╡ 854e1357-2b2a-471b-b753-4243eee998ae
let
    f = Figure(size = (800, 500))
    ax = Axis(
        f[1, 1],
        title = "RM Mask",
		titlesize = 30
    )
    heatmap!(rm_mask[:, :, z_rm], colormap = :grays)

    ax = Axis(
        f[1, 2],
        title = "RM Mask Overlayed",
		titlesize = 30
    )
    heatmap!(v2_arr[:, :, z_rm], colormap = :grays)
    heatmap!(rm_mask[:, :, z_rm], colormap = (:jet, 0.3))
    f
end

# ╔═╡ 162e0ad5-8052-42c5-a614-aade444e4e1b
md"""
## SureStart
"""

# ╔═╡ 9c507eee-2072-4425-bc10-1edae0c77444
ss_arr = load_dcm_array(dcms_ss);

# ╔═╡ 65980c6e-99f9-4fd1-8960-068cdb8f7c4a
@bind z_ss Slider(axes(ss_arr, 3), show_value = true, default = size(ss_arr, 3))

# ╔═╡ 91b8e411-5e81-4020-b54e-c49ab46259e7
let
    f = Figure()
    ax = Axis(
        f[1, 1],
        title = "SureStart"
    )
    heatmap!(ss_arr[:, :, z_ss], colormap = :grays)
    f
end

# ╔═╡ 96fc9801-0874-430c-9abc-f096b694c52e
md"""
## Aorta
"""

# ╔═╡ f5c26bf6-b90e-4fe4-874c-f0097e5c2bb2
aorta_arr = load_dcm_array(dcms_aorta);

# ╔═╡ 5fc5f085-7053-4555-a441-5e01780a1700
begin
    aorta_mask = copy(aorta_arr)
    replace!(x -> x < -1000 ? 0 : x, aorta_mask)
    aorta_mask = aorta_mask[:, :, end:-1:1]
	aorta_mask = aorta_mask .!= 0;
end;

# ╔═╡ 68a515c8-f4a1-41d5-bf11-9515bf86cac8
begin
    aorta_mask_erode = zeros(size(aorta_mask));
    for i in axes(aorta_mask, 3)
        aorta_mask_erode[:, :, i] = erode(aorta_mask[:, :, i])
    end
end

# ╔═╡ a173eedd-1d7b-4f5e-8952-0ab9002ec00d
@bind z_aorta Slider(axes(aorta_mask, 3), show_value = true, default = size(aorta_mask, 3) ÷ 2)

# ╔═╡ 682beda6-0849-4848-9330-970379004b10
let
    f = Figure(size = (800, 800))
    ax = Axis(
        f[1, 1],
        title = "Aorta Mask",
        titlesize = 20
    )
    heatmap!(aorta_mask[:, :, z_aorta], colormap = :grays)

    ax = Axis(
        f[1, 2],
        title = "Aorta Mask Eroded",
        titlesize = 20
    )
    heatmap!(aorta_mask_erode[:, :, z_aorta], colormap = :grays)

	ax = Axis(
        f[2, 1],
        title = "Aorta Mask Overlayed",
        titlesize = 20
    )
    heatmap!(v2_arr[:, :, z_aorta], colormap = :grays)
    heatmap!(aorta_mask[:, :, z_aorta], colormap = (:jet, 0.3))

    ax = Axis(
        f[2, 2],
        title = "Aorta Mask Eroded",
        titlesize = 20
    )
    heatmap!(v2_arr[:, :, z_aorta], colormap = :grays)
    heatmap!(aorta_mask_erode[:, :, z_aorta], colormap = (:jet, 0.3))
    f
end

# ╔═╡ 1a3d7bd7-6ea7-4566-8fec-60ae735322ff
md"""
## Crop Arrays via LM & RM Mask
"""

# ╔═╡ c64fcf8a-a2cc-447a-bb94-2c6905177bba
full_mask = lm_mask .| rm_mask;

# ╔═╡ de4716aa-028c-4112-8cc6-37c86ee2f0db
bounding_box_indices = find_bounding_box(full_mask; offset = (40, 40, 20))

# ╔═╡ f3514317-c5fb-483f-8500-9278b8a657a8
begin
	v1_crop = crop_array(v1_arr, bounding_box_indices...)
	v2_crop = crop_array(v2_arr, bounding_box_indices...)
	lm_crop = crop_array(lm_mask, bounding_box_indices...)
	rm_crop = crop_array(rm_mask, bounding_box_indices...)
	aorta_crop = crop_array(aorta_mask_erode, bounding_box_indices...)
end;

# ╔═╡ 9bef729f-fec8-417a-b302-afe75f83ff82
full_crop = lm_crop .| rm_crop;

# ╔═╡ 12948a68-3ff3-4e3d-8fa1-f467c82cc940
md"""
# Registration
"""

# ╔═╡ a04745e3-386e-4d76-8b3e-e797fc5c038a
v2_reg = register(v1_crop, v2_crop; num_iterations = 0);
# v2_reg = copy(v2_crop);

# ╔═╡ 771fd41e-cb6f-4123-9077-e9b2b26e663f
@bind z_reg Slider(axes(v1_crop, 3), show_value = true, default = 100)

# ╔═╡ b3bc44f6-4cda-42f8-99d0-0703b5f90942
let
    f = Figure(size = (800, 500))
    ax = Axis(
        f[1, 1],
        title = "Unregistered",
        titlesize = 20
    )
    heatmap!(v2_crop[:, :, z_reg] - v1_crop[:, :, z_reg])

    ax = Axis(
        f[1, 2],
        title = "Registered",
        titlesize = 20
    )
	heatmap!(v2_reg[:, :, z_reg] - v1_crop[:, :, z_reg])
    f
end

# ╔═╡ 06f2a525-4442-447a-a18a-c6bc9d73ea51
@bind z_full Slider(axes(full_crop, 3), show_value = true, default = size(full_crop, 3) ÷ 2)

# ╔═╡ 70af5388-b3c9-4abd-94eb-34390f582ed0
let
    f = Figure(size = (800, 500))
    ax = Axis(
        f[1, 1],
        title = "V1 Registered Overlay",
		titlesize = 20
    )
    heatmap!(v1_crop[:, :, z_full], colormap = :grays)
    heatmap!(full_crop[:, :, z_full], colormap = (:jet, 0.3))

    ax = Axis(
        f[1, 2],
        title = "V2 Registered Overlay",
		titlesize = 20
    )
    heatmap!(v2_reg[:, :, z_full], colormap = :grays)
    heatmap!(full_crop[:, :, z_full], colormap = (:jet, 0.3))
    f
end

# ╔═╡ ecbcbaf4-d649-4c62-bc89-bca62c7afb43
md"""
!!! warning
	The code below shows that there is a potential issue with the data. The LM mask, when overlayed on top of V1, has a mean intensity of ~ -110 HU. I verified this on ImageJ. Maybe this is a problem with beam hardening? Not sure. But this might be why the group decided to distribute a uniform V1 intensity of V1. We will follow that protocol here.
"""

# ╔═╡ 46fc2650-7766-420e-b56a-f38747b23af6
mean(v1_crop[lm_crop])

# ╔═╡ 49d15613-f77f-4e60-a199-6589d7332a06
md"""
# Arterial Input Function (AIF)
"""

# ╔═╡ 42482099-1175-4ae6-bbf2-03d7cca3fb77
md"""
## SureStart
"""

# ╔═╡ 9c224143-3d99-4a89-a48c-12afc7cc6cea
md"""
Select slice: $(@bind z1_aif Slider(axes(ss_arr, 3), show_value = true, default = size(ss_arr, 3)))

Choose x location: $(@bind x1_aif Slider(axes(ss_arr, 1), show_value = true, default = size(ss_arr, 1) ÷ 2))

Choose y location: $(@bind y1_aif Slider(axes(ss_arr, 1), show_value = true, default = size(ss_arr, 1) ÷ 2))

Choose radius: $(@bind r1_aif Slider(1:10, show_value = true))

Check box when ready: $(@bind aif1_ready CheckBox())
"""

# ╔═╡ da08cf24-82d4-46aa-b2ec-60762ddd4219
let
	f = Figure()
	ax = Axis(
		f[1, 1],
		title = "Sure Start AIF"
	)
	heatmap!(ss_arr[:, :, z1_aif], colormap = :grays)

	# Draw circle using parametric equations
	phi = 0:0.01:2π
	circle_x = r1_aif .* cos.(phi) .+ x1_aif
	circle_y = r1_aif .* sin.(phi) .+ y1_aif
	lines!(circle_x, circle_y, label="Aorta Mask (radius $r1_aif)", color=:red, linewidth = 1)

	axislegend(ax)
	
	f
end

# ╔═╡ a9e78216-a0ca-4290-b811-f65c6552869a
if aif1_ready
	aif_surestart = compute_aif(ss_arr, x1_aif, y1_aif, r1_aif)
	aif_v2 = mean(v2_arr[aorta_mask])
	aif_vec_gamma = [aif_surestart..., aif_v2]
end

# ╔═╡ 2725a5bd-495a-4c0e-85ec-1510f86f3bf6
md"""
# Time Attenuation Curve
"""

# ╔═╡ 2bb870d0-8dc5-4179-ac62-750c5b203375
md"""
## Extract SureStart Times
"""

# ╔═╡ 4ea44e82-3f98-41c4-b494-7f2035c3f436
if aif1_ready
	time_vector_ss = scan_time_vector(dcms_ss)
	time_vector_ss_rel = time_vector_ss .- time_vector_ss[1]

	time_vector_v2 = scan_time_vector(dcms_v2)
	time_vector_v2_rel = time_vector_v2 .- time_vector_v2[1]

	delta_time = time_vector_v2[length(time_vector_v2) ÷ 2] - time_vector_ss[end]

	time_vec_gamma = [time_vector_ss_rel..., delta_time + time_vector_ss_rel[end]]
end

# ╔═╡ dd5657f3-87d9-4008-8b2c-2487a138c6f6
md"""
## Gamma Variate
"""

# ╔═╡ e5adb264-14b4-429f-a52f-a1ec4a268e53
if aif1_ready
	# Upper and Lower Bounds
	lb = [-100.0, 0.0]
	ub = [100.0, 200.0]

	baseline_hu = mean(aif_vec_gamma[1:3])
	p0 = [0.0, baseline_hu]  # Initial guess (0, blood pool offset)

	time_vec_end, aif_vec_end = time_vec_gamma[end], aif_vec_gamma[end]

	fit = gamma_curve_fit(time_vec_gamma, aif_vec_gamma, time_vec_end, aif_vec_end, p0; lower_bounds = lb, upper_bounds = ub)
	opt_params = fit.param
end

# ╔═╡ b7cb52bb-6cd1-4275-a417-ca84ed241cba
if aif1_ready
	x_fit = range(start = minimum(time_vec_gamma), stop = maximum(time_vec_gamma), length=500)
	y_fit = gamma(x_fit, opt_params, time_vec_end, aif_vec_end)
	dense_y_fit_adjusted = max.(y_fit .- baseline_hu, 0)

	area_under_curve = trapz(x_fit, dense_y_fit_adjusted)
	times = collect(range(time_vec_gamma[1], stop=time_vec_end, length=round(Int, maximum(time_vec_gamma))))
	
	input_conc = area_under_curve ./ (time_vec_gamma[19] - times[4])
	if length(aif_vec_gamma) > 2
		input_conc = mean([aif_vec_gamma[end], aif_vec_gamma[end-1]])
	end
end

# ╔═╡ 15d5a917-a565-4157-a92f-907976520cfc
if aif1_ready
	let
		f = Figure()
		ax = Axis(
			f[1, 1],
			xlabel = "Time Point (s)",
			ylabel = "Intensity (HU)",
			title = "Fitted AIF Curve"
		)
		
		scatter!(time_vec_gamma, aif_vec_gamma, label="Data Points")
		lines!(x_fit, y_fit, label="Fitted Curve", color = :red)
		scatter!(time_vec_gamma[end-1], aif_vec_gamma[end-1], label = "Trigger")
		scatter!(time_vec_gamma[end], aif_vec_gamma[end], label = "V2")
		
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

# ╔═╡ 793078f2-42a9-42c6-b943-0efecc5d2f09
md"""
# Whole Organ Perfusion
"""

# ╔═╡ 9edfe954-be66-40bb-9cf6-70660e678fff
md"""
## Prepare Perfusion Details
"""

# ╔═╡ 7d50db75-074c-4b15-b131-b09560899bb3
if aif1_ready
	header = dcms_v1[1].meta
	voxel_size = get_voxel_size(header)
	heart_rate = round(1 / (mean(diff(time_vec_gamma)) / 60))
	tissue_rho = 1.053 # tissue density : g/cm^2
end

# ╔═╡ 501f004d-6858-45fe-b74c-9536389e19ba
if aif1_ready
	v1_uniform = make_volume_uniform(v1_crop, full_crop, 47, 0)
	flow, organ_mass = calculate_flow(v1_uniform, v2_reg, full_crop, voxel_size, delta_time, input_conc)
	perf = flow / organ_mass
end

# ╔═╡ 252b6f9f-00cd-44b3-93c5-1cd217ebc6ae
if aif1_ready
	flow_map = (v2_reg - v1_uniform) ./ (mean(v2_reg[full_crop]) - mean(v1_uniform[full_crop])) .* flow
	perf_map = flow_map ./ organ_mass
	perf_std = std(perf_map[full_crop])
end

# ╔═╡ 139e558a-722c-432f-bb87-15806f0aff0a
if aif1_ready
	@bind z_flow Slider(axes(flow_map, 3), show_value = true, default = size(flow_map, 3) ÷ 2)
end

# ╔═╡ b2183d00-876c-4861-8add-9987d6cdf51c
if aif1_ready
	let
		f = Figure(size = (700, 900))
		ax = Axis(
			f[1, 1],
			title = "Flow Map"
		)

		masked_flow_map = flow_map .* full_crop
		heatmap!(v2_reg[:, :, z_flow], colormap = :grays)
		hm2 = heatmap!(masked_flow_map[:, :, z_flow], colormap = (:jet, 0.5))

		Colorbar(f[1,2], hm2)

		ax = Axis(
			f[2, 1],
			title = "Perfusion Map"
		)

		masked_perf_map = perf_map .* full_crop
		heatmap!(v2_reg[:, :, z_flow], colormap = :grays)
		hm2 = heatmap!(masked_perf_map[:, :, z_flow], colormap = (:jet, 0.5))

		Colorbar(f[2,2], hm2)
		# Colorbar(f[1, 2], limits = (-10, 300), colormap = :jet,
  #   flipaxis = false)
		f
	end
end

# ╔═╡ 771d0e87-2174-4704-a16b-cd8b8a688541
md"""
## Results
"""

# ╔═╡ 64ed69ee-987f-4e32-8507-c8d977a585a9
col_names = [
    "perfusion",
    "perfusion_std",
    "perfusion_ref",
    "flow",
    "flow_std",
    "delta_time",
    "mass",
    "heart_rate"
]

# ╔═╡ 053863f7-4607-4c16-b8e2-bfd0cf5b0535
if aif1_ready
	col_vals = [
	    perf,
	    perf_std,
	    length(perf) == 3 ? perf[3] : missing,
	    perf * organ_mass,
	    perf_std * organ_mass,  
	    delta_time,
	    organ_mass,
	    heart_rate
	]
end

# ╔═╡ 2e8dea82-636c-43d4-b2ef-0aba7e15191e
if aif1_ready
	df = DataFrame(parameters = col_names, values = col_vals)
end

# ╔═╡ Cell order:
# ╟─0aff8608-44d1-498c-9ba8-568fd8df9ac2
# ╠═d5a90ce4-8f7d-46a0-8cc6-aecb3728c894
# ╠═8d3f6904-99a7-4bbb-9ef9-89139319c15e
# ╠═322de146-6d93-455b-b1d7-c53e0b1c43a4
# ╠═c46fc2df-5a2c-4076-9002-89288a723895
# ╠═09a5239b-5534-4923-aa25-538cee392392
# ╠═c92a9261-47c0-4dc1-a7d0-df25a84f7613
# ╠═2ad6d64d-d3d8-4d78-84fd-91786d3e1cb6
# ╠═8ed90773-464e-408f-9a65-10a2587b0c60
# ╠═e78b9d34-94dd-494b-a8ef-1c4af86187b6
# ╠═8b50aaf5-e083-4ddc-a19a-b2e8d2d9c369
# ╟─3c6dbe47-c343-4d17-b653-74a26bec7092
# ╟─db7a894b-9b7a-4924-bd8b-b02f46bf6629
# ╟─103a11a0-fb1e-4ffe-9881-9e3d863f00ab
# ╟─7be21dd4-b5d4-4c90-9d8d-38597dbf1fda
# ╟─dbcc0552-8975-4b2e-8008-cefe67d7ffe6
# ╟─5007245d-2faa-4e9b-af3f-4eb73b1b4fea
# ╠═1552936a-1f0a-492a-96d9-785fae6ea7b6
# ╠═7e0d6528-5b97-40fd-b240-493892bb326f
# ╠═1f24e288-6627-4363-8f23-dd063058ba64
# ╠═3418eae3-b912-4d18-a218-f020258716b7
# ╠═f383d83c-563a-4660-829d-d997d2943930
# ╠═e2615e9a-4209-481a-ac1e-ab81ddc8c66d
# ╟─e7088b2c-15a1-4ceb-9a3c-c5df239cd95d
# ╟─15c8373a-efed-4d74-92b4-124aec7557f7
# ╠═7ebead3c-7779-49f1-b8ae-3f51a8bcb17b
# ╠═a3d5c629-d16f-4a1f-9072-bfe87c8cccde
# ╟─1d2520fe-ad71-483d-87ad-7b0ab2a417c1
# ╟─ddfde220-1b0d-4ae5-97cc-232df7b95bc8
# ╠═fc37db24-ba08-495a-897a-6c230c7ac24e
# ╟─1416804f-54af-4a04-9a65-e668f94b564a
# ╟─2e96e18d-14da-4cfc-b42e-7fc55a5bdebb
# ╠═436f2b81-549d-4787-ac19-b9792714cc5b
# ╠═39964974-7b83-4ec7-956e-1f023b9eff19
# ╟─2a409a59-1ec3-4b87-b75e-e059717195e6
# ╟─aed40a87-9028-4ad2-a553-a12251958139
# ╠═10d6ddfe-6018-4432-b382-1783f5f0ab38
# ╠═3d221a76-4a1c-446d-b0e0-04b4093d1e64
# ╟─f7473163-4c31-440f-8be5-ba9336d89a14
# ╟─8e7790bf-aa93-4c65-925c-f29a4b1579ef
# ╠═a07761af-05c6-443c-9272-646b19e5a7cf
# ╠═4860509d-3067-4e0d-bf7b-91f8e25f1c5a
# ╟─f129d1e0-43be-4ac5-bfe2-b901da8e80d0
# ╟─5749d046-e946-4889-8f88-43130598a472
# ╠═16c123cd-3f8f-4163-8028-63a5f52dae3d
# ╟─2b803e51-91bb-4165-9341-944c08e09398
# ╟─87d3268a-e5cf-4c60-b8c1-6921373daa34
# ╟─f14623fd-94bc-4742-9c32-357552052ad7
# ╠═3eafac3e-0756-485f-949e-6a5d49b761b7
# ╠═2f5a80bb-eebd-4f68-98cb-77a1cb69ab1a
# ╟─1d27ebad-017c-410a-bacc-481aa94ef23a
# ╟─4c7b7f87-6b3a-45df-996f-3d4bb1b55938
# ╟─03cf3563-c4a0-47cc-80b8-d33ab98fcaa5
# ╠═014d6ab9-ee84-41ee-8af8-34833fe7060c
# ╠═f8c4d8cf-eb63-4ab3-88ba-b848c522d71a
# ╟─cc431ca3-f3d1-4775-bb8f-a2a92db2943b
# ╟─854e1357-2b2a-471b-b753-4243eee998ae
# ╟─162e0ad5-8052-42c5-a614-aade444e4e1b
# ╠═9c507eee-2072-4425-bc10-1edae0c77444
# ╟─65980c6e-99f9-4fd1-8960-068cdb8f7c4a
# ╟─91b8e411-5e81-4020-b54e-c49ab46259e7
# ╟─96fc9801-0874-430c-9abc-f096b694c52e
# ╠═f5c26bf6-b90e-4fe4-874c-f0097e5c2bb2
# ╠═5fc5f085-7053-4555-a441-5e01780a1700
# ╠═68a515c8-f4a1-41d5-bf11-9515bf86cac8
# ╟─a173eedd-1d7b-4f5e-8952-0ab9002ec00d
# ╟─682beda6-0849-4848-9330-970379004b10
# ╟─1a3d7bd7-6ea7-4566-8fec-60ae735322ff
# ╠═c64fcf8a-a2cc-447a-bb94-2c6905177bba
# ╠═de4716aa-028c-4112-8cc6-37c86ee2f0db
# ╠═f3514317-c5fb-483f-8500-9278b8a657a8
# ╠═9bef729f-fec8-417a-b302-afe75f83ff82
# ╟─12948a68-3ff3-4e3d-8fa1-f467c82cc940
# ╠═a04745e3-386e-4d76-8b3e-e797fc5c038a
# ╟─771fd41e-cb6f-4123-9077-e9b2b26e663f
# ╟─b3bc44f6-4cda-42f8-99d0-0703b5f90942
# ╟─06f2a525-4442-447a-a18a-c6bc9d73ea51
# ╟─70af5388-b3c9-4abd-94eb-34390f582ed0
# ╟─ecbcbaf4-d649-4c62-bc89-bca62c7afb43
# ╠═46fc2650-7766-420e-b56a-f38747b23af6
# ╟─49d15613-f77f-4e60-a199-6589d7332a06
# ╟─42482099-1175-4ae6-bbf2-03d7cca3fb77
# ╟─9c224143-3d99-4a89-a48c-12afc7cc6cea
# ╟─da08cf24-82d4-46aa-b2ec-60762ddd4219
# ╠═a9e78216-a0ca-4290-b811-f65c6552869a
# ╟─2725a5bd-495a-4c0e-85ec-1510f86f3bf6
# ╟─2bb870d0-8dc5-4179-ac62-750c5b203375
# ╠═4ea44e82-3f98-41c4-b494-7f2035c3f436
# ╟─dd5657f3-87d9-4008-8b2c-2487a138c6f6
# ╠═e5adb264-14b4-429f-a52f-a1ec4a268e53
# ╠═b7cb52bb-6cd1-4275-a417-ca84ed241cba
# ╟─15d5a917-a565-4157-a92f-907976520cfc
# ╟─793078f2-42a9-42c6-b943-0efecc5d2f09
# ╟─9edfe954-be66-40bb-9cf6-70660e678fff
# ╠═7d50db75-074c-4b15-b131-b09560899bb3
# ╠═501f004d-6858-45fe-b74c-9536389e19ba
# ╠═252b6f9f-00cd-44b3-93c5-1cd217ebc6ae
# ╟─139e558a-722c-432f-bb87-15806f0aff0a
# ╟─b2183d00-876c-4861-8add-9987d6cdf51c
# ╟─771d0e87-2174-4704-a16b-cd8b8a688541
# ╠═64ed69ee-987f-4e32-8507-c8d977a585a9
# ╠═053863f7-4607-4c16-b8e2-bfd0cf5b0535
# ╠═2e8dea82-636c-43d4-b2ef-0aba7e15191e

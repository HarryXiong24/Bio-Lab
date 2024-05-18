using DICOM

export load_dcm_array, scan_time_vector, dcm_time_2sec, trapz, get_voxel_size, make_volume_uniform

load_dcm_array(dcm_data::Vector{DICOM.DICOMData}) = cat([dcm_data[i][tag"Pixel Data"] for i in eachindex(dcm_data)]...; dims=3)

function scan_time_vector(dcms)
	scan_times = Float64[]
	for i in eachindex(dcms)
		scan_time = dcm_time_2sec(dcms[i].meta[tag"Content Time"])
		push!(scan_times, scan_time)
	end
	sort!(scan_times)
	return scan_times
end

"""
	dcm_time2sec(dcm_time)

DICOM time tags are saved in the following format:
hr, h2, min, min, sec, sec. ms, ms
120010.00 would equate to => hr 12 min 0 sec 10 ms 00
"""
function dcm_time_2sec(dcm_time)
	hr = parse(Float64, dcm_time[1:2])
	min = parse(Float64, dcm_time[3:4])
	sec = parse(Float64, dcm_time[5:6])
	ms = parse(Float64, dcm_time[7:end])

	return hr * 60^2 + min * 60 + sec + ms
end

"""
	trapz(x, y)

Given a time series, compute the area under the curve using the trapezoidal rule
"""
function trapz(x, y)
    return 0.5 * sum(diff(x) .* (y[1:end-1] + y[2:end]))
end

"""
    get_voxel_size(header)

Get the pixel information of the DICOM image given the `header` info.
Returns the x, y, and z values, where `z` corresponds to slice thickness

"""
function get_voxel_size(header)
	head = copy(header)
	voxel_size = [head[tag"Pixel Spacing"]..., head[tag"Slice Thickness"]]
    return voxel_size
end

function make_volume_uniform(volume, mask, val_inside_mask = 47, val_outside_mask = 0)
	volume_uniform = copy(volume)
	volume_uniform[mask] .= 47  # Set all values inside the mask to 47
	volume_uniform[.!mask] .= 0  # Set all values outside the mask to 0
	return volume_uniform
end

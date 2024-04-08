export calculate_flow

using Statistics: mean

function calculate_flow(
	v1, v2, mask, pixel_spacing, delta_time, input_conc;
	tissue_rho = 1.053)
	
	voxel_size = prod(pixel_spacing)
	organ_mass = (sum(mask) * tissue_rho * voxel_size) / 1000 # g
	organ_vol_inplane = pixel_spacing[1] * pixel_spacing[2] / 1000
	delta_hu = mean(v2[mask]) - mean(v1[mask])

	v1_mass = sum(v1[mask]) * organ_vol_inplane
	v2_mass = sum(v2[mask]) * organ_vol_inplane

	flow  = (1 / input_conc) * ((v2_mass - v1_mass) / (delta_time / 60)) # mL/min
	return flow, organ_mass
end

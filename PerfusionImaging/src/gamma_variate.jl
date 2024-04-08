using LsqFit: curve_fit

function gamma(x, p, time_vec_end, aif_vec_end)
    p1, p2 = p
    r1 = (aif_vec_end - p2) / (((time_vec_end / (time_vec_end + eps()))^p1) * exp(p1 * (1 - time_vec_end / (time_vec_end + eps()))))
    r2 = ifelse.(x .== 0, 0, (x / (time_vec_end + eps())).^p1 .* exp.(p1 .* (1 .- x / (time_vec_end + eps()))))
    return r1 .* r2 .+ p2
end

function gamma_curve_fit(time_vec_gamma, aif_vec_gamma, time_vec_end, aif_vec_end, p0; lower_bounds = [-100.0, 0.0], upper_bounds = [100.0, 200.0])
    function _gamma(x, p, time_vec_end, aif_vec_end)
        p1, p2 = p
        r1 = (aif_vec_end - p2) / (((time_vec_end / (time_vec_end + eps()))^p1) * exp(p1 * (1 - time_vec_end / (time_vec_end + eps()))))
        r2 = ifelse.(x .== 0, 0, (x / (time_vec_end + eps())).^p1 .* exp.(p1 .* (1 .- x / (time_vec_end + eps()))))
        return r1 .* r2 .+ p2
    end
    
    function gamma_model(x, p)
        return _gamma(x, p, time_vec_end, aif_vec_end)
    end

	fit = curve_fit(gamma_model, time_vec_gamma, aif_vec_gamma, p0; lower = lower_bounds, upper = upper_bounds)
	return fit
end

export gamma, gamma_curve_fit
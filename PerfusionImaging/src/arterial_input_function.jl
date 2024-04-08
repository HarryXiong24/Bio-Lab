"""
compute_aif(dcm::Array{T, 3}, x::Int, y::Int, r::Int) where T
compute_aif(dcm::Array{T, 3}, x::Int, y::Int, r::Int, z::Int) where T

Compute the mean pixel values within a circular region for a 3D DICOM array. The function is overloaded to work either for all slices or for a specific slice.

# Arguments
- `dcm::Array{T, 3}`: The 3D DICOM array where each slice is a 2D image.
- `x::Int`: The x-coordinate of the circle's center.
- `y::Int`: The y-coordinate of the circle's center.
- `r::Int`: The radius of the circle.
- `z::Int` (Optional): The specific slice index. If provided, the function will compute the mean for this slice only.

# Returns
- `Vector{Float64}`: A vector containing the mean pixel values for each slice within the circle (first method).
- `Float64`: The mean pixel value for the specified slice within the circle (second method).

# Examples
```julia
mean_values = compute_aif(dcm, 42, 42, 10)  # For all slices
mean_value_single_slice = compute_aif(dcm, 42, 42, 10, 5)  # For a single slice
```
"""
function compute_aif(dcm, x, y, r)
    # Initialize an array to store the mean values for each slice
    mean_values = Float64[]

    # Loop through each slice
    for z in axes(dcm, 3)
        # Initialize a boolean mask with the same dimensions as the slice
        mask = zeros(Bool, size(dcm, 1), size(dcm, 2))

        # Populate the mask based on the circle's equation
        for ix in axes(dcm, 1)
            for iy in axes(dcm, 2)
                if (ix - x)^2 + (iy - y)^2 <= r^2
                    mask[ix, iy] = true
                end
            end
        end

        # Extract the pixel values inside the circle
        pixel_values = dcm[:, :, z] .* mask

        # Compute the mean value for this slice inside the circle
        mean_value = sum(pixel_values) / sum(mask)

        # Store the computed mean value
        push!(mean_values, mean_value)
    end

    return mean_values
end

function compute_aif(dcm, x, y, r, z)
    # Initialize a boolean mask with the same dimensions as the slice
    mask = zeros(Bool, size(dcm, 1), size(dcm, 2))

    # Populate the mask based on the circle's equation
    for ix in axes(dcm, 1)
        for iy in axes(dcm, 2)
            if (ix - x)^2 + (iy - y)^2 <= r^2
                mask[ix, iy] = true
            end
        end
    end

    # Extract the pixel values inside the circle for the selected slice
    pixel_values = dcm[:, :, z] .* mask

    # Compute the mean value for this slice inside the circle
    mean_value = sum(pixel_values) / sum(mask)

    return mean_value
end

export compute_aif
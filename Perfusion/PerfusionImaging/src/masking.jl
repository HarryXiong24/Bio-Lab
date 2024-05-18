function find_bounding_box(mask::BitArray{3}; offset=(0, 0, 0))
    dims = size(mask)
    
    non_zero_indices = findall(x -> x != 0, mask)
    
    if isempty(non_zero_indices)
        return nothing  # Return nothing if the mask is empty
    end
    
    min_x = max(1, minimum(i[1] for i in non_zero_indices) - offset[1])
    max_x = min(dims[1], maximum(i[1] for i in non_zero_indices) + offset[1])
    
    min_y = max(1, minimum(i[2] for i in non_zero_indices) - offset[2])
    max_y = min(dims[2], maximum(i[2] for i in non_zero_indices) + offset[2])
    
    min_z = max(1, minimum(i[3] for i in non_zero_indices) - offset[3])
    max_z = min(dims[3], maximum(i[3] for i in non_zero_indices) + offset[3])
    
    if min_x > dims[1] || max_x < 1 || min_y > dims[2] || max_y < 1 || min_z > dims[3] || max_z < 1
        error("Offset is too large, resulting in an invalid bounding box.")
    end
    
    return min_x, max_x, min_y, max_y, min_z, max_z
end

function crop_array(array::AbstractArray{T, 3}, min_x, max_x, min_y, max_y, min_z, max_z) where T
    return array[min_x:max_x, min_y:max_y, min_z:max_z]
end

export find_bounding_box, crop_array
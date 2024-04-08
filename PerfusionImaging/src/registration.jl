using PythonCall

function register(fixed_image::AbstractArray, moving_image::AbstractArray; num_iterations = 10)
    fixed_image_pyarr = PyArray(fixed_image)
	fixed_image_sitk= sitk.GetImageFromArray(fixed_image_pyarr)
	fixed_image_sitk = sitk.Cast(fixed_image_sitk, sitk.sitkFloat32)

	moving_image_pyarr = PyArray(moving_image)
	moving_image_sitk = sitk.GetImageFromArray(moving_image_pyarr)
	moving_image_sitk = sitk.Cast(moving_image_sitk, sitk.sitkFloat32)

    # Perform Demons registration
    demons_filter = sitk.DemonsRegistrationFilter()
    demons_filter.SetNumberOfIterations(num_iterations)
    displacement_field = demons_filter.Execute(fixed_image_sitk, moving_image_sitk)

	# Create a displacement field transform and apply it to the entire moving image
    displacement_transform = sitk.DisplacementFieldTransform(displacement_field)
    moving_registered_sitk = sitk.Resample(moving_image_sitk, fixed_image_sitk, displacement_transform, sitk.sitkLinear, 0.0, moving_image_sitk.GetPixelID())
    moving_registered_pyarr = sitk.GetArrayFromImage(moving_registered_sitk)
	return pyconvert(Array, moving_registered_pyarr)
end

export register

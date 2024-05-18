module PerfusionImaging

using PythonCall

const sitk = PythonCall.pynew()
const np = PythonCall.pynew()

function __init__()
    PythonCall.pycopy!(sitk, pyimport("SimpleITK"))
    PythonCall.pycopy!(np, pyimport("numpy"))
end

export sitk, np

include("arterial_input_function.jl")
include("flow.jl")
include("gamma_variate.jl")
include("masking.jl")
include("registration.jl")
include("utils.jl")

end

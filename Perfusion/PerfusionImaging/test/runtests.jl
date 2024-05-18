using PerfusionImaging
using Test

@testset "registration" begin
    fixed_image, moving_image = rand([0, 1], 10, 10, 10), rand([0, 1], 10, 10, 10)
    registered_image = register(fixed_image, moving_image; num_iterations = 2)
    @test size(fixed_image) == size(registered_image)
end

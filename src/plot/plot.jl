include("plot_domain.jl")
# include("plot_moments.jl")

# Plot the result across angular frequency for a specific position (x)
@recipe function plot(simres::SimulationResult;
        x = simres.x,
        x_indices = [findmin(norm(z - y) for z in simres.x)[2] for y in x],
        ω_indices = Colon())

    for x_ind in x_indices

        complex_field = field(simres)[x_ind, ω_indices]

        @series begin
            label --> "Real x=$(simres.x[x_ind])"
            (transpose(getfield(simres, 3)[ω_indices]), real.(complex_field))
        end

        @series begin
            label --> "Imag x=$(simres.x[x_ind])"
            (transpose(getfield(simres, 3)[ω_indices]), imag.(complex_field))
        end
    end
end

# Plot the result in space (across all x) for a specific angular frequency
@recipe function plot(simres::SimulationResult, ω_or_t::AbstractFloat;
        x_indices = indices(simres.x,1),
        ω_or_t_index = findmin(abs.(getfield(simres, 3) .- ω_or_t))[2],
        field_apply = real, seriestype = :surface)

    x = [x[1] for x in simres.x[x_indices]]
    y = [x[2] for x in simres.x[x_indices]]
    ω_or_t = getfield(simres, 3)[ω_or_t_index]

    fillcolor --> :pu_or
    title --> "Field at $(fieldnames(simres)[end])=$ω_or_t"
    seriestype --> seriestype
    aspect_ratio --> 1.0

    if seriestype == :contour

        # We should really check here to see if x and y have the right structure
        x = unique(x)
        y = unique(y)

        n_x = length(x)
        n_y = length(y)

        fill --> true
        x, y, field_apply.(transpose(reshape(field(simres)[x_indices,ω_index],n_y,n_x)))

    else

        (x, y, field_apply.(field(simres)[x_indices,ω_index]))

    end

end

"Plot just the particles"
@recipe function plot(sim::FrequencySimulation; bounds = :auto)

    println("Plotting a simulation on its own")

    if bounds == :auto
        bounds = bounding_rectangle(sim.particles)
    end

    @series begin
        xlims --> (bottomleft(bounds)[1], topright(bounds)[1])
        ylims --> (bottomleft(bounds)[2], topright(bounds)[2])
        sim.particles
    end

end

"Plot the field for a particular wavenumber"
@recipe function plot(sim::FrequencySimulation, ω::Number; res=10, xres=res, yres=res,
                         field_apply=real, bounds = :auto, drawparticles=false)

    # If user wants us to, generate bounding rectangle around particles
    if bounds == :auto
        bounding_rect = bounding_rectangle(sim.particles)
    end

    # If user has not set xlims and ylims, set them to the rectangle
    xlims --> (bottomleft(bounding_rect)[1], topright(bounding_rect)[1])
    ylims --> (bottomleft(bounding_rect)[2], topright(bounding_rect)[2])

    # Incase the user did set the xlims and ylims, generate a new bounding
    # rectangle with them
    p_xlims = plotattributes[:xlims]
    p_ylims = plotattributes[:ylims]
    bounding_rect = Rectangle([p_xlims[1],p_ylims[1]], [p_xlims[2],p_ylims[2]])

    @series begin

        field_sim = run(sim, bounding_rect, [ω]; xres=xres, yres=yres)

        xy_mat = reshape(field_sim.x, (xres+1, yres+1))

        x_pixels = [x[1] for x in xy_mat[:,1]]
        y_pixels = [x[2] for x in xy_mat[1,:]]

        # Turn the responses (a big long vector) into a matrix, so that the heatmap will understand us
        response_mat = transpose(reshape(field(field_sim), (xres+1, yres+1)))
        seriestype --> :contour
        fill --> true
        aspect_ratio := 1.0
        fillcolor --> :pu_or
        title --> "Field at ω=$ω"

        (x_pixels, y_pixels, field_apply.(response_mat))
    end
    if drawparticles
        @series begin
            sim.particles
        end
    end
end

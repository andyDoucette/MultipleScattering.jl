
@recipe function plot(particles::Vector{Particle})
    grid --> false
    legend --> nothing
    xlab --> "x"
    ylab --> "y"
    aspect_ratio := 1.0
    fill --> (0, :grey)
    line --> 0

    x = map(p -> (t -> p.r*cos(t) + p.x[1]), particles)
    y = map(p -> (t -> p.r*sin(t) + p.x[2]), particles)

    (x, y, 0, 2π)
end

@recipe function plot(particle::Particle)
    grid --> false
    legend --> nothing
    xlab --> "x"
    ylab --> "y"
    aspect_ratio := 1.0
    fillalpha = 0.7/(1.0 + abs(particle.ρ*particle.c)) # darker fill the larger the impendence
    fill --> (0, fillalpha, :grey)
    linecolor --> :grey
    linealpha --> 0.7

    x = t -> particle.r*cos(t) + particle.x[1]
    y = t -> particle.r*sin(t) + particle.x[2]

    (x, y, 0, 2π)
end

@recipe function plot(shape::Shape)
    grid --> false
    legend --> nothing
    xlab --> "x"
    ylab --> "y"
    aspect_ratio := 1.0
    label --> name(shape)
    fill --> (0, :transparent)
    line --> (1, :red)

    x, y = boundary_functions(shape)

    (x, y, 0, 1)
end

"""
Build a 'field model' with lots of listeners using the same domain as model
you pass in. This 'field model' can then be used to plot the whole field for
this wavenumber.
"""
function build_field_model{T}(model::FrequencyModel{T}, bounds::Rectangle{T},
                              k_arr::Vector{T}=model.k_arr; res=10,xres=res,yres=res)
    # Create deep copy of model so that we can add lots of new listener positions and rerun the model
    field_model = deepcopy(model)

    # Build the listeners or pixels
    box_size = bounds.topright - bounds.bottomleft
    box_width = box_size[1]
    box_height = box_size[2]

    # Build up the pixels and all the framework for the plotting
    num_pixels = (xres+1)*(yres+1)
    listener_positions = Matrix{T}(2,num_pixels)

    #Size of the step in x and y direction
    step_size = [box_width / xres, box_height / yres]

    iterator = 1
    for j=0:yres
        for i=0:xres
            listener_positions[:,iterator] = bounds.bottomleft + step_size.*[i,j]
            iterator += 1
        end
    end

    field_model.listener_positions = listener_positions
    generate_responses!(field_model,k_arr)

    return field_model
end

"Plot the field for a particular wavenumber"
@recipe function plot{T}(model::FrequencyModel{T},k::T;res=10, xres=res, yres=res,
                         resp_fnc=real, drawshape = false)

    @series begin
        # find a box which covers everything
        shape_bounds = bounding_box(model.shape)
        listeners_as_particles = map(
            l -> Particle(model.listener_positions[:,l],mean_radius(model)/2),
            1:size(model.listener_positions,2)
        )
        particle_bounds = bounding_box([model.particles; listeners_as_particles])
        bounds = bounding_box(shape_bounds, particle_bounds)
        field_model = build_field_model(model, bounds, [k]; xres=xres, yres=yres)

        # For this we sample at the centre of each pixel
        x_pixels = linspace(bounds.bottomleft[1], bounds.topright[1], xres+1)
        y_pixels = linspace(bounds.bottomleft[2], bounds.topright[2], yres+1)

        # Turn the responses (a big long vector) into a matrix, so that the heatmap will understand us
        response_mat = transpose(reshape(field_model.response, (xres+1, yres+1)))
        linetype --> :contour
        fill --> true
        fillcolor --> :pu_or
        title --> "Field at k=$k"

        (x_pixels, y_pixels, resp_fnc.(response_mat))
    end
    if drawshape
      @series begin
          model.shape
      end
    end
    for i=1:length(model.particles) @series model.particles[i] end

    @series begin
        line --> 0
        fill --> (0, :lightgreen)
        legend --> false
        grid --> false
        colorbar --> true
        aspect_ratio := 1.0

        r = mean_radius(model.particles)/2
        x(t) = r * cos(t) + model.listener_positions[1, 1]
        y(t) = r * sin(t) + model.listener_positions[2, 1]

        (x, y, -2π/3, 2π/3)
    end

end

"Plot the response across all wavenumbers"
@recipe function plot(model::FrequencyModel)
    label --> ["real" "imaginary"]
    xlabel --> "Wavenumber (k)"
    ylabel --> "Response"
    grid --> false
    title --> "Response from particles of radius $(signif(model.particles[1].r,2)) contained in a $(lowercase(name(model.shape)))\n with volfrac=$(signif(calculate_volfrac(model),2)) measured at ($(model.listener_positions[1,1]), $(model.listener_positions[2,1]))"

    (model.k_arr, [real(model.response) imag(model.response)])
end

"Plot the response across time"
@recipe function plot(model::TimeModel)
    label --> ["real" "imaginary"]
    xlabel --> "Time (t)"
    ylabel --> "Response"
    grid --> false
    title --> "Response from particles of radius $(signif(model.frequency_model.particles[1].r,2)) contained in a $(lowercase(name(model.frequency_model.shape)))\n with volfrac=$(signif(calculate_volfrac(model.frequency_model),2)) measured at ($(model.frequency_model.listener_positions[1,1]), $(model.frequency_model.listener_positions[2,1]))"

    (model.time_arr, [real(model.response) imag(model.response)])
end

"Plot the field for a particular an array of time"
@recipe function plot{T}(timemodel::TimeModel{T}, t_arr;
                        res=10, xres=res, yres=res, resp_fnc=real, drawshape = false)
    model = timemodel.frequency_model

    @series begin
        # find a box which covers everything
        shape_bounds = bounding_box(model.shape)
        listeners_as_particles = map(
            l -> Particle(model.listener_positions[:,l],mean_radius(model)/2),
            1:size(model.listener_positions,2)
        )
        particle_bounds = bounding_box([model.particles; listeners_as_particles])
        bounds = bounding_box(shape_bounds, particle_bounds)

        field_model = build_field_model(model, bounds; xres=xres, yres=yres)
        field_timemodel = deepcopy(timemodel) # to use all the same options/fields as timemodel
        field_timemodel.frequency_model = field_model
        generate_responses!(field_timemodel, t_arr)

        # For this we sample at the centre of each pixel
        x_pixels = linspace(bounds.bottomleft[1], bounds.topright[1], xres+1)
        y_pixels = linspace(bounds.bottomleft[2], bounds.topright[2], yres+1)

        # NOTE only plots the first time plot for now...
        response_mat = transpose(reshape(field_timemodel.response[1,:], (xres+1, yres+1)))
        linetype --> :contour
        fill --> true
        fillcolor --> :pu_or
        title --> "Field at time=$(t_arr[1])"

        (x_pixels, y_pixels, resp_fnc.(response_mat))
    end
    if drawshape
      @series begin
          model.shape
      end
    end
    for i=1:length(model.particles) @series model.particles[i] end

    @series begin
        line --> 0
        fill --> (0, :lightgreen)
        legend --> false
        grid --> false
        colorbar --> true
        aspect_ratio := 1.0

        r = mean_radius(model.particles)/2
        x(t) = r * cos(t) + model.listener_positions[1, 1]
        y(t) = r * sin(t) + model.listener_positions[2, 1]

        (x, y, -2π/3, 2π/3)
    end

end

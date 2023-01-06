using NeuralPDE, Lux, Optimization, OptimizationOptimJL
import ModelingToolkit: Interval
using ModelingToolkit
using IntervalSets
using Makie  # great package
using GLMakie  # great package
using MeshIO  # good package
using FileIO  # good package
using Meshes
using GeometryBasics  # great package
using Statistics
using LinearAlgebra


GLMakie.activate!()
GLMakie.set_window_config!(
    framerate = 10,
    title = "Confined active particles"
)


UpFolder = pwd();

# import an STL mesh, returning a PATCH-compatible face-vertex structure
namestructure = "ellipsoid_x4"
mesh_loaded = FileIO.load("assets/ellipsoid_x4.stl")

# % Define folder structure and pre-process meshes:
# % -----------------------------------------------
folder_plots = joinpath(UpFolder, "images", namestructure)
folder_particle_simula = joinpath(UpFolder, "simulation_structure")

##############################################################
# create folder for plots
##############################################################

if !isdir(folder_plots)
    mkdir(folder_plots)
end
# create folder for particle simulation
if !isdir(folder_particle_simula)
    mkdir(folder_particle_simula)
end


##############################################################
# Define Model Parameters
##############################################################

num_part = 200; # number particles
v0 = 0.1; # velocity of particles
v0_next = 0.1; # if velocity is to be changed after a certain number of timesteps

num_step = 300; # Number of timesteps

sigma_n = 5/12; # particle radius


# Define parameters for the force calculations:
# ---------------------------------------------
r_adh = 1; # Cut off radius for adhesive forces
k = 10.; # Elastic constant for repulsive forces
k_next = 10.; # value of elastic constant after a certain number of timesteps
k_adh = 0.75; # Adhesive forces

mu = 1.; # arbitrary mass of particle
tau = 1; #time of relaxation of collision between 2 particles

dt = 0.01*tau; # Step size
plotstep = 0.1/dt; # Number of calculation between plot

b = v0_next/(2*sigma_n*mu*k_next); # for calculating coupling constant
J = b/tau; # Coupling constant of orientation vectors
noise=0.002/tau;  #value of the noise amplitude
hi=noise/(2*sqrt(dt)); # Amplitude of the noise on orientation

# Parameters for making movies:
#------------------------------
rho = 6; # arbitrary value for scaling the vector on plotting. To automatize, maybe from file name value
scale=0.1*rho; # Scale the vector for making movies


##############################################################


# TODO: implement this: https://docs.makie.org/v0.19.1/documentation/nodes/index.html#the_observable_structure
# TODO
"""
    simulate_on_mesh(mesh_surf, form_particle, n_particle)

The goal is to create a package where I can overgive a mesh surface and the particle form and then simply simulate the particle behaviour on the mesh surface.
"""
function simulate_on_mesh(mesh_surf, form_particle, n_particle)

end


# TODO: implement this correctly
# # # % Plot the particles
# using GLMakie, Random
# GLMakie.activate!()
# num_part = 200
# initms = 8 * rand(num_part)
# particles = Makie.Observable(initms) # this is the variable that will change
# # first frame, initial plot
# fig, ax = scatter(2 * rand(num_part), rand(num_part), markersize = particles,
#     color = initms, colormap = (:Greek, 0.75), strokewidth = 0.5,
#     strokecolor = :white,
#     figure = (resolution = (1200, 800), fontsize = 22),
#     axis = (xlabel = "x", ylabel = "y",))
# limits!(ax, 0, 2, 0, 1)



"""
    clip11(x)

"""
function clip11(x)
    if x < -1
        return -1
    elseif x > 1
        return 1
    else
        return x
    end
end


"""
    calculate_order_parameter(v_order, tt, v_tp)

"""
function calculate_order_parameter(v_order, tt, v_tp)
    for i=1:n
        v_norm[i,:]=v_tp[i,:]/norm(v_tp[i,:])
    end
    v_order[tt]=(1/n)*norm(sum(v_norm))

    return v_order
end


"""
    find_nonzero_index(c::Array)

"""
function find_nonzero_index(c::Array)
    a = similar(c, Int)
    count = 1
    @inbounds for i in eachindex(c)
        a[count] = i
        count += (c[i] != zero(eltype(c)))
    end
    return resize!(a, count-1)
end


"""
    dim_data(V::Array{Float32, 2}, F, dim::Int)

"""
function dim_data(V::Array{Float32, 2}, F, dim::Int)
    return reduce(vcat,transpose.([V[F[:,1],dim],V[F[:,2],dim],V[F[:,3],dim]]))'
end


"""
    vec_of_vec_to_array(V::Array{Float32, 2})

transform vector of vectors to matrix
"""
function vec_of_vec_to_array(V)
    reduce(vcat,transpose.(V))
end


"""
    array_to_vec_of_vec(A::Array)

transform matrix to vector of vectors 
"""
function array_to_vec_of_vec(A::Array)
    return [A[i,:] for i in 1:size(A,1)]
    # return vec(Point3f0.(r[:,1],r[:,2],r[:,3])) # TODO: check which is faster
end


"""
    get_index_binary(Dist2faces::Array)

Faces with closest point to r(i,:) and associated normal vectors
Finds the neighbour faces of the particle i
"""
function get_index_binary(_Dist2faces::Array)
    return first.(Tuple.(sum(findall(x->x==minimum(_Dist2faces), _Dist2faces), dims=2)))
end


"""
    spread_particles_random_on_mesh(Vertex)

Randomly position of particles on the mesh
"""
function spread_particles_random_on_mesh(Vertex)
    return[(maximum(Vertex[:,1])-minimum(Vertex[:,1]))*rand(1)[1]+minimum(Vertex[:,1]),
        (maximum(Vertex[:,2])-minimum(Vertex[:,2]))*rand(1)[1]+minimum(Vertex[:,2]),
        (maximum(Vertex[:,3])-minimum(Vertex[:,3]))*rand(1)[1]+minimum(Vertex[:,3])
        ]
end


"""
    get_particle(_face_coord_temp::Array, i::Int)

Getestete Funktion, 05 JAN 2023
"""
function get_particle(_face_coord_temp::Array, r, i::Int)
    particle = cat(dims=2,ones(size(_face_coord_temp[:,1,3]))*r[i,1],
        ones(size(_face_coord_temp[:,1,3]))*r[i,2],
        ones(size(_face_coord_temp[:,1,3]))*r[i,3]
        )
    return particle
end


"""
    get_particle_position(_face_coord_temp::Array, N_temp, r, i::Int)

Getestete Funktion, 05 JAN 2023
"""
function get_particle_position(_face_coord_temp::Array, N_temp, r, i::Int)
    particle = get_particle(_face_coord_temp, r, i)
    len_face_coord = length(_face_coord_temp[:,1,1])
    reshape_it = reshape(_face_coord_temp[:,1,:],len_face_coord,3)
    placeholder = sum((particle-reshape_it).*N_temp,dims=2)
    p0s = particle - cat(placeholder, placeholder, placeholder, dims=2).*N_temp
    return p0s
end


"""
    simulate_next_step(tt, r, num_part, n, Norm_vect)

calculate force, displacement and reorientation for all particles. In the second
part, for each particle project them on closest face. In the third part,
we sometimes plot the position and orientation of the cells
"""
function simulate_next_step(tt, particles_observ, F_neighbourg, num_part, n, Norm_vect, io)
    r = particles_observ[] |> vec_of_vec_to_array

    # ! TODO: remove the constants
    v0 = 0.1; # velocity of particles
    v0_next = 0.1; # if velocity is to be changed after a certain number of timesteps

    sigma_n = 5/12; # particle radius


    # Define parameters for the force calculations:
    # ---------------------------------------------
    r_adh = 1; # Cut off radius for adhesive forces
    k = 10.; # Elastic constant for repulsive forces
    k_next = 10.; # value of elastic constant after a certain number of timesteps
    k_adh = 0.75; # Adhesive forces

    mu = 1.; # arbitrary mass of particle
    tau = 1; #time of relaxation of collision between 2 particles

    dt = 0.01*tau; # Step size
    plotstep = 0.1/dt; # Number of calculation between plot


    # Parameters for making movies:
    #------------------------------
    rho = 6; # arbitrary value for scaling the vector on plotting. To automatize, maybe from file name value
    scale=0.1*rho; # Scale the vector for making movies


    # if loop to change forces and velocity after some time because in
    # first time steps, just repulsive force for homogeneisation of
    # particle repartition
    if tt > 500
        v0 = v0_next;
        k = k_next;
    end

    ##############################################################
    # Part 1 of for loop
    ##############################################################
    
    # % Vector between all particles (1->2; 1->3; 1->4;... 641->1; 641->2;
    # % 641->3; 641->4;...641->640...)
    # % Vect is a 3D matrix for vector between particles, e.g. below
    # % Vect(1,2,1) = r(1,1) - r(2,1)
    # % Vect(1,2,2) = r(1,2) - r(2,2)
    # % Vect(1,2,3) = r(1,3) - r(2,3)
    Vect = cat(dims=3,
        r[:,1]*ones(1,num_part)-ones(num_part,1)*r[:,1]',
        r[:,2]*ones(1,num_part)-ones(num_part,1)*r[:,2]',
        r[:,3]*ones(1,num_part)-ones(num_part,1)*r[:,3]'
        )

    # % cross_Nij is the cross product between orientation vectors
    # % cross_Nij(1,2,1) = n(1,2)*n(2,3)-(n(1,3)*n(2,2))
    # % cross_Nij(1,2,2) = -(n(1,1)*n(2,3))+n(1,3)*n(2,1)
    # % cross_Nij(1,2,3) = n(1,1)*n(2,2)-(n(1,2)*n(2,1))
    cross_Nij = cat(dims=3,
        (n[:,2]*ones(1,num_part)).*(ones(num_part,1)*n[:,3]')-
        (n[:,3]*ones(1,num_part)).*(ones(num_part,1)*n[:,2]'),
        -(n[:,1]*ones(1,num_part)).*(ones(num_part,1)*n[:,3]')+
        (n[:,3]*ones(1,num_part)).*(ones(num_part,1)*n[:,1]'),
        (n[:,1]*ones(1,num_part)).*(ones(num_part,1)*n[:,2]')-
        (n[:,2]*ones(1,num_part)).*(ones(num_part,1)*n[:,1]')
        )

    Distmat = sqrt.(sum(Vect.^2,dims=3))[:,:,1]  # distance of each point with the others
    
    Fij_rep = (-k*(2*sigma_n.-Distmat))./(2*sigma_n)
    Fij_adh = (k_adh*(2*sigma_n.-Distmat))./(2*sigma_n-r_adh)

    # No force if particles too far from each other or if particle itself
    Fij_rep[(Distmat .>= 2*sigma_n) .| (Distmat .== 0)] .= 0 
    Fij_adh[(Distmat .< 2*sigma_n) .| (Distmat .> r_adh) .| (Distmat .== 0)] .= 0

    # Fij is the force between particles
    # Fij(1,2,1) = -k(2sigma_n - norm(r(2,:)-r(1,:))) * (r(1,1)-r(2,1)) / norm(r(2,:)-r(1,:))
    # Fij(1,2,2) = -k(2sigma_n - norm(r(2,:)-r(1,:))) * (r(2,2)-r(2,2)) / norm(r(2,:)-r(1,:))
    # Fij(1,2,3) = -k(2sigma_n - norm(r(2,:)-r(1,:))) * (r(2,3)-r(2,3)) / norm(r(2,:)-r(1,:))
    # if 0 < norm(r(2,:)-r(1,:)) < 2*sigma_n
    Fij = Fij_rep .+ Fij_adh
    Fij = cat(dims=3,Fij,Fij,Fij).*(Vect./(cat(dims=3,Distmat,Distmat,Distmat)))
    
    # % Actual force felt by each particle
    F_track = reshape(sum(replace!(Fij, NaN=>0), dims=1),: ,size(Fij,3)) 
    # % Velocity of each particle
    r_dot = P_perp(Norm_vect,v0.*n+mu.*F_track)

    r = r+r_dot*dt; # % calculate next position


    ##############################################################
    # Visceck-type n correction adapted from "Phys. Rev. E 74, 061908"
    ##############################################################

    ncross = cat(dims=2,n[:,2].*r_dot[:,3]-n[:,3].*r_dot[:,2],
        -(n[:,1].*r_dot[:,3]-n[:,3].*r_dot[:,1]),
        n[:,1].*r_dot[:,2]-n[:,2].*r_dot[:,1]) ./
        (sqrt.(sum(r_dot.^2,dims=2))*ones(1,3))

    n_cross_correction = (1/tau)*ncross*dt

    new_n = n-cat(dims=2,n[:,2].*n_cross_correction[:,3]-n[:,3].*n_cross_correction[:,2],
        -(n[:,1].*n_cross_correction[:,3]-n[:,3].*n_cross_correction[:,1]),
        n[:,1].*n_cross_correction[:,2]-n[:,2].*n_cross_correction[:,1])

    n = new_n./(sqrt.(sum(new_n.^2,dims=2))*ones(1,3))

    ##############################################################
    # End Visceck-type n correction
    ##############################################################

    Norm_vect = ones(num_part,3);

    for i = 1:length(r[:,1])
        # Search for faces around the particle before displacement in wich the
        # cell could migrate. Only face with at least one vertex within the
        # zone defined by the particle at its center and of radius r_dot*dt are
        # candidates for projection
        radius_search = sqrt.(sum(r_dot[i,:].^2))*dt

        number_faces = replace!(num_face[i,:], NaN=>0)'
        number_faces = Int.(number_faces)
        number_faces = number_faces[number_faces .!= 0]

        if length(number_faces) == 1
            Faces_numbers1 = F_neighbourg[number_faces,:]
            Faces_numbers1 = replace!(Faces_numbers1, NaN=>0)
            full_number_faces = Faces_numbers1[Faces_numbers1 .!= 0]'  # remove the 0 values
        else
            full_number_faces = number_faces'
            num_face_i = 1
            for num_face_i = 1:length(number_faces)
                Faces_numbers1 = F_neighbourg[Int(number_faces[num_face_i]),:]'
                Faces_numbers1 = replace!(Faces_numbers1, NaN=>0)
                Faces_numbers1 = Int.(Faces_numbers1)
                Faces_numbers1 = Faces_numbers1[Faces_numbers1 .!= 0]'  # remove the 0 values
                full_number_faces = cat(dims=2,full_number_faces,Faces_numbers1)
             end
        end
        full_number_faces = unique(full_number_faces)

        # Faces coordinates
        Faces_coord_temp = Faces_coord[full_number_faces,:,:]
        # % Normal vectors of faces
        NV = N[full_number_faces,:] |> vec_of_vec_to_array
        # % Vector of particle to faces
        face_coord_temp = Faces_coord_temp .- cat(dims=3,ones(size(Faces_coord_temp[:,:,3]))*r[i,1],
            ones(size(Faces_coord_temp[:,:,3]))*r[i,2],
            ones(size(Faces_coord_temp[:,:,3]))*r[i,3])

        # % Distance of particle to faces
        Dist2faces = sqrt.(sum(face_coord_temp.^2,dims=3))[:,:,1]

        # TODO: this could all maybe be a function or class
        # % Faces with closest point to r(i,:) and associated normal vectors
        index_binary = get_index_binary(Dist2faces)
        face_coord_temp = Faces_coord_temp[index_binary,:,:]
        N_temp = NV[index_binary,:]

        p0s = get_particle_position(face_coord_temp, N_temp, r, i)  # get the position of the particle on the face

        # Check what face in which the projection is
        p1p2 = reshape(face_coord_temp[:,2,:]-face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
        p1p3 = reshape(face_coord_temp[:,3,:]-face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
        p1p0 = p0s-reshape(face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
        p1p3crossp1p2 = [p1p3[:,2].*p1p2[:,3]-p1p3[:,3].*p1p2[:,2],-p1p3[:,1].*p1p2[:,3]+p1p3[:,3].*p1p2[:,1],p1p3[:,1].*p1p2[:,2]-p1p3[:,2].*p1p2[:,1]] |> vec_of_vec_to_array |> Transpose
        p1p3crossp1p0 = [p1p3[:,2].*p1p0[:,3]-p1p3[:,3].*p1p0[:,2],-p1p3[:,1].*p1p0[:,3]+p1p3[:,3].*p1p0[:,1],p1p3[:,1].*p1p0[:,2]-p1p3[:,2].*p1p0[:,1]] |> vec_of_vec_to_array |> Transpose
        p1p2crossp1p0 = [p1p2[:,2].*p1p0[:,3]-p1p2[:,3].*p1p0[:,2],-p1p2[:,1].*p1p0[:,3]+p1p2[:,3].*p1p0[:,1],p1p2[:,1].*p1p0[:,2]-p1p2[:,2].*p1p0[:,1]] |> vec_of_vec_to_array |> Transpose
        p1p2crossp1p3 = [p1p2[:,2].*p1p3[:,3]-p1p2[:,3].*p1p3[:,2],-p1p2[:,1].*p1p3[:,3]+p1p2[:,3].*p1p3[:,1],p1p2[:,1].*p1p3[:,2]-p1p2[:,2].*p1p3[:,1]] |> vec_of_vec_to_array |> Transpose
    
        len_p1p3crossp1p2 = length(p1p3crossp1p2[:,1])

        # "index_face_out" are the row index(es) of face_coord_temp in which a
        # particle cannot be projected. 
        # "index_binary(index_face_in)" are the faces number(s) in which the 
        # particle cannot be projected
        index_face_out = (sum(p1p3crossp1p0.*p1p3crossp1p2,dims=2).<0) .|
            (sum(p1p2crossp1p0.*p1p2crossp1p3,dims=2).<0) .|
            ((sqrt.(sum(p1p3crossp1p0.^2,dims=2))+sqrt.(sum(p1p2crossp1p0.^2,dims=2)))./
            sqrt.(sum(p1p2crossp1p3.^2,dims=2)) .> 1) |> Array |> findall 
        index_face_out= first.(Tuple.(index_face_out))
    
        # % "index_face_in" are the row index(es) of face_coord_temp in which a
        # % particle can be projected. 
        # "index_binary(index_face_in)" are the faces number(s) in which the 
        # particle can be projected
        index_face_in = setdiff(reshape([1:len_p1p3crossp1p2;], :, 1), index_face_out)  # Note: links muss die vollständige Liste stehen!

        # % If the projections are in no face, take the average projection and
        # % normal vectors. Save the faces number used
        if isempty(index_face_in) == 1
            Norm_vect[i,:] = mean(N_temp[index_face_out,:],dims=1)
            r[i,:] = mean(p0s[index_face_out,:],dims=1)
            num_face[i,1:length(index_face_out)] = full_number_faces[index_binary[index_face_out]]'

        # % If the projections are in a face, save its number, normal vector and
        # % projected point
        else
            if length(index_face_in) > 1
                Norm_vect[i,:] = mean(N_temp[index_face_in,:],dims=1)
                r[i,:] = mean(p0s[index_face_in,:],dims=1)
                num_face[i,1:length(index_face_in)] = full_number_faces[index_binary[index_face_in]]'
            else
                Norm_vect[i,:] = N_temp[index_face_in,:]
                num_face[i,1] = full_number_faces[index_binary[index_face_in]][1]
                r[i,:] = p0s[index_face_in,:]
            end
        end
    end

    # % find faces closer to each points and associated normal vector
    # %%%%%%%%%%%%
    # %Project the orientation of the corresponding faces using normal vectors
    n = P_perp(Norm_vect,n)
    n = n./(sqrt.(sum(n.^2,dims=2))*ones(1,3)) # And normalise orientation vector

    t=(tt-1)*dt;


    ##############################################################
    # Part 3 of for loop%
    ##############################################################

    # %Graphic output if plotstep is a multiple of tt
    if rem(tt,plotstep)==0

        # normalize r_dot for visualization
        nr_dot = zeros(num_part,3);
        for i=1:num_part
            nr_dot[i,:] = r_dot[i,:]/norm(r_dot[i,:]);
        end

        nr_dot_cross = zeros(num_part,3);
        for i=1:num_part
            cross_Nrdot=cross(n[i,:],Norm_vect[i,:])
            nr_dot_cross[i,:] =cross_Nrdot./norm(cross_Nrdot)
        end

        # %evaluate number of neighbourgs within 2.4 sigma cut off
        num_partic = ones(size(Distmat));
        num_partic[(Distmat .== 0) .| (Distmat .> 2.4*sigma_n)] .= 0;
        # %list of nearest neighbour to each particle
        number_neighbours=sum(num_partic,dims=2);

        # % specify colorvalue "c" according to neighbours for particles to plot
        N_color=[];
        for i=1:num_part
            append!(N_color, Int.(number_neighbours[i,:]))
        end


        ##############################################################
        # Definition of the order parameter:
        ##############################################################

        # Define a vector normal to position vector and velocity vector
        v_tp=[r[:,2].*r_dot[:,3]-r[:,3].*r_dot[:,2],-r[:,1].*r_dot[:,3]+r[:,3].*r_dot[:,1],r[:,1].*r_dot[:,2]-r[:,2].*r_dot[:,1]];
        v_tp = v_tp |> vec_of_vec_to_array |> transpose
        # Normalize v_tp
        v_norm=v_tp./(sqrt.(sum(v_tp.^2,dims=2))*ones(1,3));
        # Sum v_tp vectors and devide by number of particle to obtain order
        # parameter of collective motion for spheroids
        v_order[Int(tt/plotstep)]=(1/num_part)*norm(sum(v_norm,dims=1))

        # #Calculate angles for equirectangular map projection
        # phi1 = asin(r[:,3]/sqrt.(sum(r.^2,dims=2)));   # elevation angle
        # thet1 = atan2(r[:,2],r[:,1]); # azimuth

        ##############################################################
        # ! TODO: Der folgende Teil ist für die Visualisierung der Zellen
        ##############################################################

        # LScene It's just a wrapper around the normal Scene that makes it block. 
        # The underlying Scene is accessible via the scene field. 
        # You can plot into the LScene directly, though.
        # lscene = Makie.LScene(fig[1, 1])
        # cam = Makie.cameracontrols(lscene.scene)
        # cam.lookat[] = [0, 0, 200]
        # cam.eyeposition[] = [3000, 200, 2000]
        # scene = Makie.Scene(resolution = (400,400));
        # update_cam!(lscene.scene, cam) # not sure if there is a method without cam

        particles_observ[] = array_to_vec_of_vec(r)
        recordframe!(io)   # record a new frame
        println("Hey, I'm recording a frame")
        # particles_positions = vec(Point3f0.(r[:,1],r[:,2],r[:,3]))   # TODO: transform it into a Observable
        # plot the particles 

        # meshscatter!(particles, color = :black, markersize = 0.05)   # ! if you use Makie.Observable

        # meshscatter!(particles_positions, color = :black, markersize = 0.05)
        # meshscatter!(r[:,1],r[:,2],r[:,3], color = :black, markersize = 0.05)
        
        # TODO: uncomment the following line if the particle simulation is working
        # arrow_directions = vec(Point3f0.(scale*nr_dot[:,1],scale*nr_dot[:,2],scale*nr_dot[:,3]))   # TODO: transform it into a Observable 

        # # plot the vector orientation of the particles in black
        # arr = Makie.arrows!(r[:,1],r[:,2],r[:,3],scale*n[:,1],scale*n[:,2],scale*n[:,3],
        #     arrowsize = 0.05, linecolor = (:black, 0.7), linewidth = 0.02, lengthscale = 0.1
        # )

        # # plot the normalized velocity vector in red
        # arr = Makie.arrows!(
        #     particles_positions, arrow_directions,
        #     arrowsize = 0.05, linecolor = (:red, 0.7), linewidth = 0.02, lengthscale = 0.1
        # )

        # # Binormal vector
        # arr = Makie.arrows!(r[:,1],r[:,2],r[:,3],scale*nr_dot_cross[:,1],scale*nr_dot_cross[:,2],scale*nr_dot_cross[:,3],
        #     arrowsize = 0.05, linecolor = (:blue, 0.7), linewidth = 0.02, lengthscale = 0.1
        # )




        # update_cam!(scene, FRect3D(Vec3f0(0), Vec3f0(1)))
        # N = 1000
        # record(scene, "assets/test.mp4", 1:N) do iter
        #     ! TODO: run here the simulation
        #     isodd(iter) && addparticle!(particles, colors, nparticles)
        #     repel(particles, nparticles[])
        #     for i in 1:0.1:8
        #         particles[] = i * initms
        #         recordframe!(io)  
        #     end
        # end
    end
end


##############################################################
# Define perpendicular projection functions, adapted from "PhysRevE 91 022306"
##############################################################

# P_perp does a normal projection of the vector b on the plane normal to a
P_perp(a, b) = (b-(sum(b.*a,dims=2)./(sqrt.(sum(a.^2,dims=2)).^2)*ones(1,3)).*a)

# P_plan does a projection of the vector b on vector normal to a1 in the plane normal to a
P_plan(a,b,a1) = ((sum(b.*a,dims=2)./(sqrt.(sum(a.^2,dims=2)))*ones(1,3)).*[
    a[:,2].*a1[:,3]-a[:,3].*a1[:,2],-a[:,1].*a1[:,3]+a[:,3].*a1[:,1],a[:,1].*a1[:,2]-a[:,2].*a1[:,1]
    ])


##############################################################
# PLOTTING DONE BY MAKIE.jl
##############################################################

scene = Makie.Scene(resolution = (400,400));
# mesh!(scene, mesh_loaded, color = :gray)
f, ax, pl = Makie.mesh(mesh_loaded, axis=(type=Axis3,))  # plot the mesh

# wireframe!(ax, mesh_loaded, color=(:black, 0.2), linewidth=2, transparency=true)  # only for the asthetic


##############################################################
# Get the data from the mesh
##############################################################

N = mesh_loaded.normals
# faces = GeometryBasics.decompose(TriangleFace{Int}, mesh_loaded)  # return the faces of the mesh
vertices = GeometryBasics.coordinates(mesh_loaded)  # return the vertices of the mesh
faces = reshape(1:length(vertices), 3, :)'  # return the faces of the mesh
vertices = vec_of_vec_to_array(vertices)

Vertex = vertices
Faces = faces


##############################################################
# When we plot surfaces, we are interested only in some part of the
# geometry, so we select the faces which have at least one vertex in the
# area of interest
V_plot = ones(length(Faces[:,1]),1); # Will store the num of the faces in the ROI
face_num_plot=[];


Faces_coord = cat(dim_data(Vertex, Faces, 1), dim_data(Vertex, Faces, 2), dim_data(Vertex, Faces, 3), dims=3)

time_points = Int(num_step/plotstep)
v_order = zeros(time_points, 1)


##############################################################
# Initialize the Observables
##############################################################


r = zeros(num_part,3); # Position of particles
n = zeros(num_part,3); # Orientation of particles

# function repel(particles_node, N)
#     particles = particles_node[]
#     @inbounds for i in 1:N
#         ftot = Vec3f0(0)
#         p1 = particles[i]
#         for j in 1:N
#             if i != j
#                 p2 = particles[j]
#                 Δσ = acos(clip11(dot(p1, p2))) # great circle distance
#                 ftot += (p1 - p2)/max(1e-3, Δσ^2)
#             end
#         end
#         particles[i] = normalize(p1 + 0.001 * ftot)
#     end
#     particles_node[] = particles
# end




# scene = Makie.Scene(resolution = (400,400), show_axis = false);
# mesh!(scene, Sphere(Point3f0(0), 1f0), color = :gray)

# max_particles = 5000
# # An `Observable` is a mutable container of an object of type `T`.
# # `T` can be any type.
# particles = Makie.Observable(fill(Point3f0(NaN), max_particles))
# colors = Makie.Observable(fill(RGBAf(0, 0, 0, 0), max_particles))
# meshscatter!(scene, particles, color = colors, markersize = 0.05)
# nparticles = Makie.Observable(0)
# for i=1:10
#     addparticle!(particles, colors, nparticles)
# end
# update_cam!(scene, FRect3D(Vec3f0(0), Vec3f0(1)))
# # scene.center = false # don't reset the camera by display




# # the animation is done by updating the Observable values
# record(fig, joinpath("assets", "confined_active_particles.mp4"),
#     framerate = 24, profile = "main") do io
#     for i in 1:0.1:8
#         particles[] = i * initms
#         recordframe!(io)  # record a new frame
#     end
# end

particles_observ = Makie.Observable(fill(Point3f0(NaN), num_part))

# particles = particles_observ[]
# # @inbounds for i in 1:N   # ! Performance boost by using @inbounds
# #     ftot = Vec3f0(0)
# #     p1 = particles[i]
# #     # for j in 1:N
# #     #     if i != j
# #     #         p2 = particles[j]
# #     #         Δσ = acos(clip11(dot(p1, p2))) # great circle distance
# #     #         ftot += (p1 - p2)/max(1e-3, Δσ^2)
# #     #     end
# #     # end
# #     particles[i] = normalize(p1 + 0.001 * ftot)
# # end
# particles_observ[] = particles

##############################################################


# particle_info = struct;  # TODO: habe ich rausgenommen, weil ich nicht weiß, was das macht

"""
    get_face_neighbors(Faces)

Create index matrix of neighbourg faces to each face
"""
function get_face_neighbors(Faces)
    
    F_neighbourg = fill(NaN, length(Faces[:,1]), 100)  # matrix of neighbourg faces

    maximum_neighbour = 0  # maximumimum number of neighbourg faces
    # % Loop for to search all neighbours for each faces within a radius 
    # % "radius_search" centered around the isobarycenter of the face. 
    # % The face are considered within the radius if at least one of the
    # % vertex is within. radius_search = displacement of particle + distance
    # % between isobarcenter and verteces of face considered
    for i = 1:length(Faces[:,1])
        center_faces = [Faces_coord[i,1,1]+Faces_coord[i,2,1]+Faces_coord[i,3,1],
            Faces_coord[i,1,2]+Faces_coord[i,2,2]+Faces_coord[i,3,2],
            Faces_coord[i,1,3]+Faces_coord[i,2,3]+Faces_coord[i,3,3]
            ]/3

        extra_dist = sqrt((center_faces[1]-Faces_coord[i,1,1])^2+(center_faces[2]-Faces_coord[i,1,2])^2+(center_faces[3]-Faces_coord[i,1,3])^2)

        radius_search = extra_dist # +dist_motion  # TODO: warum ist in dieser Gleichung dist_motion nicht definiert?
        Faces2center = Faces_coord - cat(center_faces[1]*ones(size(Faces)),
            center_faces[2]*ones(size(Faces)),center_faces[3]*
            ones(size(Faces)), dims=3)

        # % Norm^2 vector all faces verteces to vertex 1 of this face
        Faces2center = Faces2center[:,:,1].*Faces2center[:,:,1] + Faces2center[:,:,2].*Faces2center[:,:,2] + Faces2center[:,:,3].*Faces2center[:,:,3]
        # assign the value zero if vertex too far form center
        Faces2center[Faces2center.>radius_search^2] .= 0
        # % Sum the distance of vertices for each faces
        Faces2center = Faces2center[:,1]+Faces2center[:,2]+Faces2center[:,3]
        # % Create coefficient matrix for neighbourg of center of considered face.
        # % Only faces with non zero distances are valid.
        index_row = find_nonzero_index(Faces2center)

        F_neighbourg[i,1:length(index_row)] = index_row'
        F_neighbourg[i,1+length(index_row)] = i

        if length(index_row)+1 > maximum_neighbour
            maximum_neighbour = length(index_row)+1
        end

    end
    F_neighbourg[F_neighbourg .== 0] .= NaN
    F_neighbourg = [isnan(val) ? NaN : Int(val) for val in F_neighbourg]
    F_neighbourg = F_neighbourg[:,1:maximum_neighbour]  # create a subset of the matrix
    return F_neighbourg
end


F_neighbourg = get_face_neighbors(Faces)

##############################################################
# % Begin - Initialize particles with random initial orientation
##############################################################



p1 = Vertex[Faces[:,1],:] # Vertex number 1 of each faces
p2 = Vertex[Faces[:,2],:] # Vertex number 2 of each faces
p3 = Vertex[Faces[:,3],:] # Vertex number 3 of each faces
Norm_vect = ones(num_part,3); # Initialisation of normal vector of each faces
num_face = fill(NaN, num_part, length(F_neighbourg[1,:])^2)   # Initialisation of face on which is the particle


# NOTE: transform the Observable vector to our used Matrix notation
r = particles_observ[] |> vec_of_vec_to_array


# for-loop where particle are randomly positioned and orientated in a 3D
# box, then projected on the closest face. The normal vector of that face
# is then also saved
for i=1:num_part

    r[i,:] = spread_particles_random_on_mesh(Vertex)
    #random particle orientation
    n[i,:] = [-1+2*rand(1)[1],-1+2*rand(1)[1],-1+2*rand(1)[1]]

    # Initialize number faces candidates
    face_candi = fill(NaN, 1, length(num_face[i,:]))
    candi_num = 0
    # Vector of particle to faces
    face_coord_temp = Faces_coord - cat(ones(size(Faces_coord[:,:,3]))*
        r[i,1],ones(size(Faces_coord[:,:,3]))*
        r[i,2],ones(size(Faces_coord[:,:,3]))*
        r[i,3], dims=3)

    # Distance of particle to faces
    Dist2faces = sqrt.(sum(face_coord_temp.^2,dims=3)[:,:,1])

    # Faces with closest point to r[i,:] and associated normal vectors
    index_binary = get_index_binary(Dist2faces)
    face_coord_temp = Faces_coord[index_binary,:,:]
    N_temp = N[index_binary,:] |> vec_of_vec_to_array  # transform the vec of vec into array

    p0s = get_particle_position(face_coord_temp, N_temp, r, i)

    # Check what face in which the projection is
    p1p2 = reshape(face_coord_temp[:,2,:]-face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
    p1p3 = reshape(face_coord_temp[:,3,:]-face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
    p1p0 = p0s-reshape(face_coord_temp[:,1,:],length(face_coord_temp[:,1,1]),3);
    p1p3crossp1p2 = [p1p3[:,2].*p1p2[:,3]-p1p3[:,3].*p1p2[:,2],-p1p3[:,1].*p1p2[:,3]+p1p3[:,3].*p1p2[:,1],p1p3[:,1].*p1p2[:,2]-p1p3[:,2].*p1p2[:,1]] |> vec_of_vec_to_array |> Transpose
    p1p3crossp1p0 = [p1p3[:,2].*p1p0[:,3]-p1p3[:,3].*p1p0[:,2],-p1p3[:,1].*p1p0[:,3]+p1p3[:,3].*p1p0[:,1],p1p3[:,1].*p1p0[:,2]-p1p3[:,2].*p1p0[:,1]] |> vec_of_vec_to_array |> Transpose
    p1p2crossp1p0 = [p1p2[:,2].*p1p0[:,3]-p1p2[:,3].*p1p0[:,2],-p1p2[:,1].*p1p0[:,3]+p1p2[:,3].*p1p0[:,1],p1p2[:,1].*p1p0[:,2]-p1p2[:,2].*p1p0[:,1]] |> vec_of_vec_to_array |> Transpose
    p1p2crossp1p3 = [p1p2[:,2].*p1p3[:,3]-p1p2[:,3].*p1p3[:,2],-p1p2[:,1].*p1p3[:,3]+p1p2[:,3].*p1p3[:,1],p1p2[:,1].*p1p3[:,2]-p1p2[:,2].*p1p3[:,1]] |> vec_of_vec_to_array |> Transpose

    len_p1p3crossp1p2 = length(p1p3crossp1p2[:,1])

    # "index_face_out" are the row index(es) of face_coord_temp in which a
    # particle cannot be projected. 
    # "index_binary(index_face_in)" are the faces number(s) in which the 
    # particle cannot be projected
    index_face_out = (sum(p1p3crossp1p0.*p1p3crossp1p2,dims=2).<0) .|
        (sum(p1p2crossp1p0.*p1p2crossp1p3,dims=2).<0) .|
        ((sqrt.(sum(p1p3crossp1p0.^2,dims=2))+sqrt.(sum(p1p2crossp1p0.^2,dims=2)))./
        sqrt.(sum(p1p2crossp1p3.^2,dims=2)) .> 1) |> Array |> findall 
    index_face_out= first.(Tuple.(index_face_out))

    # % "index_face_in" are the row index(es) of face_coord_temp in which a
    # % particle can be projected. 
    # "index_binary(index_face_in)" are the faces number(s) in which the 
    # particle can be projected
    index_face_in = setdiff(reshape([1:len_p1p3crossp1p2;], :, 1), index_face_out)  # Note: links muss die vollständige Liste stehen!

    # If the projections are in no face, take the average projection and
    # normal vectors. Save the faces number used
    if isempty(index_face_in) == 1
        Norm_vect[i,:] = mean(N_temp[index_face_out,:],dims=1)
        r[i,:] = mean(p0s[index_face_out,:],dims=1)
        num_face[i,1:length(index_face_out)] = index_binary[index_face_out]'

    # If the projections are in a face, save its number, normal vector and
    # projected point
    else
        index_face_in = index_face_in[1]  # because first particle can be
        # projected in different faces in this initial projection
        Norm_vect[i,:] = N_temp[index_face_in,:]
        num_face[i,1] = index_binary[index_face_in]
        r[i,:] = p0s[index_face_in,:]
    end
end


particles_observ[] = array_to_vec_of_vec(r)
meshscatter!(particles_observ, color = :black, markersize = 0.05)  # ! overgive the Observable the plotting function to TRACK it


num_face = [isnan(val) ? NaN : Int(val) for val in num_face]   # ! TODO: check if this line is necessary 

# % find faces closer to each points and associated normal vector
# %%%%%%%%%%%%

# %Project the orientation of the corresponding faces using normal vectors
n = P_perp(Norm_vect,n)
n = n./(sqrt.(sum(n.^2,dims=2))*ones(1,3)) # And normalise orientation vector

# particle_info[Symbol("t",0)] = [r,n]
#particle_info = setfield(particle_info,num2str(0),[r,n]);

##############################################################
# End - Initialize particles with random initial orientation
##############################################################


# ! record the simulation
record(scene, joinpath("assets", "confined_active_particles.mp4"),
    framerate = 24, profile = "main") do io
    for tt=1:num_step #number of time steps
        simulate_next_step(tt, particles_observ, F_neighbourg, num_part, n, Norm_vect, io)
    end
end 

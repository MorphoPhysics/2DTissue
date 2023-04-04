// author: @Jan-Piotraschke
// date: 2023-02-17
// license: Apache License 2.0
// version: 0.1.0

/*
Shortest paths on a terrain using one source point 
The heat method package returns an Approximation of the Geodesic Distance for all vertices of a triangle mesh to the closest vertex in a given set of source vertices.
As a rule of thumb, the method works well on triangle meshes, which are Delaunay.

Disclaimer: The heat method solver is the bottle neck of the algorithm.
*/

#include <CGAL/Simple_cartesian.h>
#include <CGAL/Surface_mesh.h>
#include <CGAL/Heat_method_3/Surface_mesh_geodesic_distances_3.h>
#define EIGEN_DONT_PARALLELIZE
#define EIGEN_USE_THREADS
#include <Eigen/Core>
#include <Eigen/Sparse>
#include <Eigen/Geometry>

#include <iostream>
#include <fstream>
#include <algorithm>
#include <sstream>
#include <cstddef>
#include <vector>
#include <thread>
#include <atomic>
#include <ctime>
#include <omp.h>

#include "jlcxx/jlcxx.hpp"
#include "jlcxx/array.hpp"
#include "jlcxx/functions.hpp"


using Kernel = CGAL::Simple_cartesian<double>;
using Point_3 = Kernel::Point_3;
using Triangle_mesh = CGAL::Surface_mesh<Point_3>;

using vertex_descriptor = boost::graph_traits<Triangle_mesh>::vertex_descriptor;
using Vertex_distance_map = Triangle_mesh::Property_map<vertex_descriptor, double>;

//  The Intrinsic Delaunay Triangulation algorithm is switched off by the template parameter Heat_method_3::Direct.
using Heat_method_idt = CGAL::Heat_method_3::Surface_mesh_geodesic_distances_3<Triangle_mesh, CGAL::Heat_method_3::Direct>;
using Heat_method = CGAL::Heat_method_3::Surface_mesh_geodesic_distances_3<Triangle_mesh>;

using JuliaArray = jlcxx::ArrayRef<int64_t, 1>;
using JuliaArray2D = jlcxx::ArrayRef<double, 2>;


template<typename M>
M load_csv (const std::string & path) {
    std::ifstream indata;
    indata.open(path);
    std::string line;
    std::vector<double> values;
    uint rows = 0;
    while (std::getline(indata, line)) {
        std::stringstream lineStream(line);
        std::string cell;
        while (std::getline(lineStream, cell, ',')) {
            values.push_back(std::stod(cell));
        }
        ++rows;
    }
    return Eigen::Map<const Eigen::Matrix<typename M::Scalar, M::RowsAtCompileTime, M::ColsAtCompileTime, Eigen::RowMajor>>(values.data(), rows, values.size()/rows);
}


std::vector<double> geo_distance(
    int32_t start_node
){
    std::ifstream filename(CGAL::data_file_path("/Users/jan-piotraschke/git_repos/Confined_active_particles/meshes/ellipsoid_x4.off"));
    Triangle_mesh tm;
    filename >> tm;

    //property map for the distance values to the source set
    Vertex_distance_map vertex_distance = tm.add_property_map<vertex_descriptor, double>("v:distance", 0).first;

    //pass in the idt object and its vertex_distance_map
    Heat_method hm_idt(tm);

    //add the first vertex as the source set
    vertex_descriptor source = *(vertices(tm).first + start_node);
    hm_idt.add_source(source);
    hm_idt.estimate_geodesic_distances(vertex_distance);

    std::vector<double> distances_list;
    for(vertex_descriptor vd : vertices(tm)){
        distances_list.push_back(get(vertex_distance, vd));
    }

    return distances_list;
}


Eigen::MatrixXd get_distances_between_particles(Eigen::MatrixXd r, Eigen::MatrixXd distance_matrix, std::vector<int> vertice_3D_id) {
    int num_part = r.rows();

    // Get the distances from the distance matrix
    Eigen::MatrixXd dist_length = Eigen::MatrixXd::Zero(num_part, num_part);

    // Use the #pragma omp parallel for directive to parallelize the outer loop
    // The directive tells the compiler to create multiple threads to execute the loop in parallel, splitting the iterations among them
    for (int i = 0; i < num_part; i++) {
        for (int j = 0; j < num_part; j++) {
            dist_length(i, j) = distance_matrix(vertice_3D_id[i], vertice_3D_id[j]);
        }
    }

    dist_length.diagonal().array() = 0.0;

    return dist_length;
}


/*
Reminder: if you access the input variable with the '&' sign, you can change the variable in the function, without to return the new value.
The variable is Changed In the Memory and with that also in the main function
*/
void transform_into_symmetric_matrix(Eigen::MatrixXd &A) {
    int n = A.rows();

    for (int i = 0; i < n; i++) {
        for (int j = i+1; j < n; j++) {
            if (A(i, j) != 0 && A(j, i) != 0) {
                A(i, j) = A(j, i) = std::min(A(i, j), A(j, i));
            } else if (A(i, j) == 0) {
                A(i, j) = A(j, i);
            } else {
                A(j, i) = A(i, j);
            }
        }
    }
}


void parallel_fill_distance_matrix(
    Eigen::MatrixXd& distance_matrix,
    int closest_vertice,
    std::vector<double>& vertices_3D_distance_map,
    std::atomic<int>& current_index
){
    while (true) {
        int i = current_index.fetch_add(1);
        if (i >= vertices_3D_distance_map.size()) {
            break;
        }

        distance_matrix.coeffRef(closest_vertice, i) = vertices_3D_distance_map[i];
    }
}


/*
atomic variable to keep track of the current index of the vector of distances, and each thread processes a
different index until all the distances have been added to the distance matrix.
*/
void fill_distance_matrix(
    Eigen::MatrixXd &distance_matrix,
    int closest_vertice
){
    if (distance_matrix.row(closest_vertice).head(2).isZero()) {
        // get the distance of all vertices to all other vertices
        std::vector<double> vertices_3D_distance_map = geo_distance(closest_vertice);
        distance_matrix.row(closest_vertice) = Eigen::Map<Eigen::VectorXd>(vertices_3D_distance_map.data(), vertices_3D_distance_map.size());
    }
}


std::vector<Eigen::MatrixXd> get_dist_vect(const Eigen::MatrixXd& r) {
    Eigen::VectorXd dist_x = r.col(0);
    Eigen::VectorXd dist_y = r.col(1);
    Eigen::VectorXd dist_z = r.col(2);

    // Replicate each column into a square matrix
    Eigen::MatrixXd square_x = dist_x.replicate(1, r.rows());
    Eigen::MatrixXd square_y = dist_y.replicate(1, r.rows());
    Eigen::MatrixXd square_z = dist_z.replicate(1, r.rows());

    // Compute the difference between each pair of rows
    Eigen::MatrixXd diff_x = square_x.array().rowwise() - dist_x.transpose().array();
    Eigen::MatrixXd diff_y = square_y.array().rowwise() - dist_y.transpose().array();
    Eigen::MatrixXd diff_z = square_z.array().rowwise() - dist_z.transpose().array();

    // Store the difference matrices in a vector
    std::vector<Eigen::MatrixXd> dist_vect;
    dist_vect.push_back(diff_x);
    dist_vect.push_back(diff_y);
    dist_vect.push_back(diff_z);

    return dist_vect;
}


Eigen::MatrixXd calculate_forces_between_particles(
    const std::vector<Eigen::MatrixXd>& dist_vect,
    const Eigen::MatrixXd& dist_length,
    double k,
    double σ,
    double r_adh,
    double k_adh
){
    // Get the number of particles
    int num_part = dist_vect[0].rows();

    // Initialize force matrix with zeros
    Eigen::MatrixXd F(num_part, 3);
    F.setZero();

    // Loop over all particle pairs
    for (int i = 0; i < num_part; i++) {
        for (int j = 0; j < num_part; j++) {

            // Skip if particle itself
            if (i == j) continue;

            // Distance between particles A and B
            double dist = dist_length(i, j);

            // No force if particles too far from each other 
            if (dist >= 2 * σ) continue;

            // Add a small value if the distance is zero or you get Inf forces
            // ∀F: Inf ∉ F_track
            if (dist == 0) {
                dist += 0.0001;
            }

            // Eigen::Vector3d for the 3D distance vector
            Eigen::Vector3d dist_v(dist_vect[0](i, j), dist_vect[1](i, j), dist_vect[2](i, j));

            double Fij_rep = (-k * (2 * σ - dist)) / (2 * σ);
            double Fij_adh = (dist > r_adh) ? 0 : (k_adh * (2 * σ - dist)) / (2 * σ - r_adh);
            double Fij = Fij_rep + Fij_adh;

            F.row(i) += Fij * (dist_v / dist);
        }
    }

    // Actual force felt by each particle
    return F;
}


Eigen::MatrixXd calculate_velocity(
    std::vector<Eigen::MatrixXd>& dist_vect,
    Eigen::MatrixXd& dist_length,
    Eigen::MatrixXd& n,
    double v0,
    double k,
    double σ,
    double μ,
    double r_adh,
    double k_adh
) {
    // Calculate force between particles
    Eigen::MatrixXd F_track = calculate_forces_between_particles(dist_vect, dist_length, k, σ, r_adh, k_adh);

    // Velocity of each particle
    Eigen::MatrixXd r_dot = v0 * n + μ * F_track;  // TODO: this isn't correct yet
    r_dot.col(2).setZero();

    return r_dot;
}


Eigen::MatrixXd calculate_next_position(
    Eigen::MatrixXd& r,
    Eigen::MatrixXd& r_dot,
    double dt
){
    Eigen::MatrixXd r_new = r + r_dot * dt;
    r_new.col(2).setZero();
    return r_new;
}


Eigen::VectorXd count_particle_neighbours(const Eigen::VectorXd& dist_length, double σ) {
    Eigen::VectorXd num_partic(dist_length.size()); // create an empty vector
    num_partic.setZero(); // initialize to zero

    for (int i = 0; i < dist_length.size(); i++) {
        if (dist_length(i) == 0 || dist_length(i) > 2.4 * σ) {
            num_partic(i) = 0;
        }
    }
    Eigen::VectorXd num_neighbors = num_partic.colwise().sum();
    return num_neighbors;
}


Eigen::VectorXd dye_particles(const Eigen::VectorXd& dist_length, double σ) {
    // Count the number of neighbours for each particle
    Eigen::VectorXd number_neighbours = count_particle_neighbours(dist_length, σ);
    int num_part = number_neighbours.size();
    std::vector<int> N_color_temp;
    // #pragma omp parallel for
    for (int i = 0; i < num_part; i++) {
        for (int j = 0; j < number_neighbours(i); j++) {
            N_color_temp.push_back(number_neighbours(i));
        }
    }

    // Convert std::vector<int> to Eigen::VectorXd
    Eigen::VectorXd N_color(N_color_temp.size());
    for (size_t i = 0; i < N_color_temp.size(); ++i) {
        N_color(i) = N_color_temp[i];
    }

    return N_color;
}


/*
normalize a 3D matrix A
*/
Eigen::MatrixXd normalize_3D_matrix(const Eigen::MatrixXd &A) {
    Eigen::VectorXd row_norms_t = A.rowwise().norm(); // Compute row-wise Euclidean norms
    Eigen::MatrixXd row_norms = row_norms_t.replicate(1, 3); // Repeat each norm for each column

    return row_norms; // Normalize each row
}


/**
 * Calculate the cross product of two 3D matrices A and B.
 *
 * @param A The first input matrix.
 * @param B The second input matrix.
 *
 * @return The cross product of A and B, computed for each row of the matrices.
 */
Eigen::MatrixXd calculate_3D_cross_product(
    const Eigen::MatrixXd &A,
    const Eigen::MatrixXd &B
){ 
    // Ensure that A and B have the correct size
    assert(A.cols() == 3 && B.cols() == 3 && A.rows() == B.rows());

    // Preallocate output matrix with the same size and type as A
    const int num_rows = A.rows();
    Eigen::MatrixXd new_A = Eigen::MatrixXd::Zero(num_rows, 3);

    // Compute cross product for each row and directly assign the result to the output matrix
    for (int i = 0; i < num_rows; ++i) {
        // Get the i-th row of matrices A and B
        Eigen::Vector3d A_row = A.row(i);
        Eigen::Vector3d B_row = B.row(i);

        // Compute the cross product of the i-th rows of A and B
        new_A.row(i) = A_row.cross(B_row);
    }

    return new_A;
}


void calculate_order_parameter(
    Eigen::VectorXd& v_order, 
    Eigen::MatrixXd r, 
    Eigen::MatrixXd r_dot, 
    double tt,
    double plotstep
) {
    int num_part = r.rows();
    // Define a vector normal to position vector and velocity vector
    Eigen::MatrixXd v_tp = calculate_3D_cross_product(r, r_dot);

    // Normalize v_tp
    Eigen::MatrixXd v_norm = v_tp.rowwise().normalized();

    // Sum v_tp vectors and divide by number of particle to obtain order parameter of collective motion for spheroids
    v_order((int)(tt / plotstep)) = (1.0 / num_part) * v_norm.colwise().sum().norm();
}


/*

Visceck-type n correction adapted from "Phys. Rev. E 74, 061908"
*/
Eigen::MatrixXd correct_n(
    const Eigen::MatrixXd& r_dot,
    const Eigen::MatrixXd& n,
    double τ,
    double dt
){
    // cross product of n and r_dot
    auto ncross = calculate_3D_cross_product(n, r_dot).cwiseQuotient(normalize_3D_matrix(r_dot));

    Eigen::MatrixXd n_cross_correction = (1.0 / τ) * ncross * dt;

    Eigen::MatrixXd new_n = n - calculate_3D_cross_product(n, n_cross_correction);

    return new_n.rowwise().normalized();
}


std::pair<Eigen::MatrixXd, Eigen::MatrixXd> calculate_particle_vectors(
    Eigen::MatrixXd &r_dot,
    Eigen::MatrixXd &n
){
    // make a small correct for n according to Vicsek
    n = correct_n(r_dot, n, 1, 1);

    // Project the orientation of the corresponding faces using normal vectors
    n = n.rowwise().normalized();
    Eigen::MatrixXd nr_dot = r_dot.rowwise().normalized();

    return std::pair(n, nr_dot);
}


Eigen::MatrixXd reshape_vertices_array(
    const JuliaArray2D& vertices_stl,
    int num_rows,
    int num_cols
) {
    Eigen::MatrixXd vertices(num_rows, num_cols);

    for (int i = 0; i < num_rows; ++i) {
        for (int j = 0; j < num_cols; ++j) {
            vertices(i, j) = vertices_stl[j * num_rows + i];
        }
    }

    return vertices;
}


Eigen::VectorXd jlcxxArrayRefToEigenVectorXd(
    const jlcxx::ArrayRef<int64_t, 1>& inputArray
){
    int arraySize = inputArray.size();
    Eigen::VectorXd outputVector(arraySize);

    for (int i = 0; i < arraySize; i++) {
        outputVector(i) = static_cast<double>(inputArray[i]);
    }

    return outputVector;
}


int get_all_distances(

){
    std::ifstream filename(CGAL::data_file_path("/Users/jan-piotraschke/git_repos/Confined_active_particles/meshes/ellipsoid_x4.off"));
    Triangle_mesh tm;
    filename >> tm;
    Eigen::MatrixXd distance_matrix_v(num_vertices(tm), num_vertices(tm));
    // ! dieser Schritt ist der Bottleneck der Simulation!
    // ! wir müssen nämlich n mal die geo distance ausrechnen und die kostet jeweils min 25ms pro Start Vertex
    // loop over all vertices and fill the distance matrix
    for (auto vi = vertices(tm).first; vi != vertices(tm).second; ++vi) {
        fill_distance_matrix(distance_matrix_v, *vi);
    }

    // save the distance matrix to a csv file using comma as delimiter
    const static Eigen::IOFormat CSVFormat(Eigen::StreamPrecision, Eigen::DontAlignCols, ", ", "\n");
    std::ofstream file("/Users/jan-piotraschke/git_repos/Confined_active_particles/meshes/data/ellipsoid_x4_distance_matrix_static.csv");
    file << distance_matrix_v.format(CSVFormat);
    file.close();

    return 0;
}


std::tuple<Eigen::MatrixXd, Eigen::MatrixXd, Eigen::MatrixXd, Eigen::MatrixXd, Eigen::MatrixXd, Eigen::VectorXd, Eigen::MatrixXd> perform_particle_simulation(
    Eigen::MatrixXd& r,
    Eigen::MatrixXd& n,
    std::vector<int>& vertices_3D_active,
    Eigen::MatrixXd distance_matrix_v,
    double v0,
    double k,
    double k_next,
    double v0_next,
    double σ,
    double μ,
    double r_adh,
    double k_adh,
    double dt,
    double tt,
    int num_part = 10,
    double plotstep = 0.1
){

    // Get distance vectors and calculate distances between particles
    auto dist_vect = get_dist_vect(r);
    auto dist_length = get_distances_between_particles(r, distance_matrix_v, vertices_3D_active);
    transform_into_symmetric_matrix(dist_length);

    // Calculate force between particles
    Eigen::MatrixXd F_track = calculate_forces_between_particles(dist_vect, dist_length, k, σ, r_adh, k_adh);

    // Velocity of each particle
    Eigen::MatrixXd r_dot = v0 * n + μ * F_track;  // TODO: this isn't correct yet
    r_dot.col(2).setZero();

    // Calculate the new position of each particle
    Eigen::MatrixXd r_new = r + r_dot * dt;
    r_new.col(2).setZero();

    // Dye the particles based on distance
    Eigen::VectorXd particles_color = dye_particles(dist_length, σ);

    // Calculate the particle vectors
    auto [ntest, nr_dot] = calculate_particle_vectors(r_dot, n);

    // Define the output vector v_order
    Eigen::VectorXd v_order((int)(tt / plotstep) + 1);
    calculate_order_parameter(v_order, r, r_dot, tt, plotstep);


    return std::make_tuple(r_new, r_dot, dist_length, ntest, nr_dot, particles_color, v_order);
}


void particle_simulation(
    jl_function_t* f,
    JuliaArray2D r_v,
    JuliaArray2D n_v,
    JuliaArray vertices_3D_active_id,
    JuliaArray2D distance_matrix_v,
    int& mesh_id,
    double v0,
    double k,
    double k_next,
    double v0_next,
    double σ,
    double μ,
    double r_adh,
    double k_adh,
    double dt,
    double tt
){

    int num_entry = r_v.size();
    int num_rows = num_entry / 3;
    int num_rows_dist = sqrt(distance_matrix_v.size());
    Eigen::MatrixXd r = reshape_vertices_array(r_v, num_rows, 3);
    Eigen::MatrixXd n = reshape_vertices_array(n_v, num_rows, 3);
    Eigen::MatrixXd distance_matrix = reshape_vertices_array(distance_matrix_v, num_rows_dist, num_rows_dist);
    Eigen::VectorXd vertices_3D_active_eigen = jlcxxArrayRefToEigenVectorXd(vertices_3D_active_id);

    // convert the active vertices to a vector -> only neccessary as long as the other functions of this script depend von std::vector
    std::vector<int> vertices_3D_active(vertices_3D_active_eigen.data(), vertices_3D_active_eigen.data() + vertices_3D_active_eigen.size());

    double plotstep = 0.1;

    // Simulate the particles
    auto [r_new, r_dot, dist_length, ntest, nr_dot, particles_color, v_order] = perform_particle_simulation(r, n, vertices_3D_active, distance_matrix, v0, k, k_next, v0_next, σ, μ, r_adh, k_adh, dt, tt, plotstep);

    // transform the data into a Julia array
    auto r_julia = jlcxx::ArrayRef<double, 2>(r_new.data(), r_new.rows(), r_new.cols());
    auto r_dot_julia = jlcxx::ArrayRef<double, 2>(r_dot.data(), r_dot.rows(), r_dot.cols());
    auto dist_length_julia = jlcxx::ArrayRef<double, 2>(dist_length.data(), dist_length.rows(), dist_length.cols());
    auto ntest_julia = jlcxx::ArrayRef<double, 2>(ntest.data(), ntest.rows(), ntest.cols());
    auto nr_dot_julia = jlcxx::ArrayRef<double, 2>(nr_dot.data(), nr_dot.rows(), nr_dot.cols());
    auto particles_color_julia = jlcxx::ArrayRef<double, 1>(particles_color.data(), particles_color.size());
    auto v_order_julia = jlcxx::ArrayRef<double, 1>(v_order.data(), v_order.size());

    // Prepare to call the function defined in Julia
    jlcxx::JuliaFunction fnClb(f);

    // Fill the Julia Function with the inputs
    fnClb((jl_value_t*)r_julia.wrapped(), (jl_value_t*)r_dot_julia.wrapped(), (jl_value_t*)dist_length_julia.wrapped(), mesh_id);
}


int main()
{
    // For testing purposes
    auto v0 = 0.1;
    auto k = 10;
    auto k_next = 10;
    auto v0_next = 0.1;
    auto σ = 0.4166666666666667;
    auto μ = 1;
    auto r_adh = 1;
    auto k_adh = 0.75;
    auto dt = 0.01;
    auto tt = 10;

    Eigen::MatrixXd r = load_csv<Eigen::MatrixXd>("/Users/jan-piotraschke/git_repos/Confined_active_particles/r_data.csv");
    Eigen::MatrixXd n = load_csv<Eigen::MatrixXd>("/Users/jan-piotraschke/git_repos/Confined_active_particles/n_data.csv");
    Eigen::MatrixXd distance_matrix = load_csv<Eigen::MatrixXd>("/Users/jan-piotraschke/git_repos/Confined_active_particles/meshes/data/ellipsoid_x4_distance_matrix_static.csv");
    Eigen::MatrixXd vertices_3D_active_eigen = load_csv<Eigen::MatrixXd>("/Users/jan-piotraschke/git_repos/Confined_active_particles/vertices_3D_active_id_data.csv");
    std::vector<int> vertices_3D_active(vertices_3D_active_eigen.data(), vertices_3D_active_eigen.data() + vertices_3D_active_eigen.size());

    // get_all_distances();

    std::clock_t start = std::clock();
    // Time taken (30 MAR 2023): 1.15709 seconds
    auto [r_new, r_dot, dist_length, ntest, nr_dot, particles_color, v_order] = perform_particle_simulation(r, n, vertices_3D_active, distance_matrix, v0, k, k_next, v0_next, σ, μ, r_adh, k_adh, dt, tt);

    std::clock_t end = std::clock();
    double duration = (end - start) / (double) CLOCKS_PER_SEC;
    std::cout << "Time taken: " << duration << " seconds" << std::endl;

    return 0;
}


JLCXX_MODULE define_julia_module(jlcxx::Module& mod)
{
    // Register a standard C++ function
    mod.method("particle_simulation", particle_simulation);
    mod.method("get_all_distances", get_all_distances);
}

// author: @Jan-Piotraschke
// date: 2023-04-14
// license: Apache License 2.0
// version: 0.1.0

#include <Eigen/Dense>
#include <vector>
#include <iostream>

#include <io/mesh_loader.h>
#include <utilities/2D_3D_mapping.h>
#include <utilities/nearest_map.h>
#include <utilities/sim_structs.h>
#include <utilities/splay_state.h>
#include <utilities/update.h>
#include <utilities/boundary_check.h>
#include <utilities/2D_surface.h>
#include <utilities/validity_check.h>

#include <particle_simulation/motion.h>
#include <utilities/process_invalid_particle.h>


void process_invalid_particle(
    std::unordered_map<int, Mesh_UV_Struct>& vertices_2DTissue_map,
    std::vector<VertexData>& vertex_data,
    const VertexData& particle,
    int num_part,
    const Eigen::MatrixXd& distance_matrix,
    Eigen::MatrixXd& n,
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
) {
    int old_id = particle.old_id;

    auto [halfedges_uv, h_v_mapping] = find_nearest_vertice_map(old_id, distance_matrix, vertices_2DTissue_map);

    std::vector<int64_t> old_ids(vertex_data.size());
    for (size_t i = 0; i < vertex_data.size(); ++i) {
        old_ids[i] = vertex_data[i].old_id;
    }

    // ! TEMPORARY SOLUTION
    // Create a new vector of int and copy the elements from old_ids
    std::vector<int> old_ids_int(old_ids.size());
    for (size_t i = 0; i < old_ids.size(); ++i) {
        old_ids_int[i] = static_cast<int>(old_ids[i]);
    }

    // Get the halfedges based on the choosen h-v mapping
    std::vector<int64_t> halfedge_id = get_first_uv_halfedge_from_3D_vertice_id(old_ids, h_v_mapping);

    // Get the coordinates of the halfedges
    auto r_active = get_r_from_halfedge_id(halfedge_id, halfedges_uv);

    // Simulate the flight of the particle
    auto [r_new_virtual, r_dot, dist_length] = simulate_flight(r_active, n, old_ids_int, distance_matrix, v0, k, σ, μ, r_adh, k_adh, dt);

    // Get the new vertice id
    Eigen::VectorXd vertice_3D_id = get_vertice_id(r_new_virtual, halfedges_uv, h_v_mapping);

    update_if_valid(vertex_data, r_new_virtual, vertice_3D_id, old_id);
}


void process_if_not_valid(
    std::unordered_map<int, Mesh_UV_Struct>& vertices_2DTissue_map,
    std::vector<VertexData>& vertex_data,
    int num_part,
    Eigen::MatrixXd& distance_matrix_v,
    Eigen::MatrixXd& n,
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
) {
    std::vector<int> invalid_ids;

    for (int i = 0; i < vertex_data.size(); ++i) {
        if (!vertex_data[i].valid) {
            invalid_ids.push_back(i);
        }
    }

    for (int invalid_id : invalid_ids) {
        process_invalid_particle(vertices_2DTissue_map, vertex_data, vertex_data[invalid_id], num_part, distance_matrix_v, n, v0, k, v0_next, k_next, σ, μ, r_adh, k_adh, dt, tt);

        if (are_all_valid(vertex_data)) {
            break;
        }
    }

    // NOTE: hope that this is a good safety net
    std::vector<int> still_invalid_ids;

    for (int i = 0; i < vertex_data.size(); ++i) {
        if (!vertex_data[i].valid) {
            still_invalid_ids.push_back(i);
        }
    }
    if (still_invalid_ids.size() > 0) {

        // Create new 2D surfaces for the still invalid ids
        for (int i = 0; i < still_invalid_ids.size(); ++i) {
            std::cout << "Creating new 2D surface for particle " << i << std::endl;
            auto result = create_uv_surface_intern("Ellipsoid", i);
            std::vector<int64_t> h_v_mapping_vector = std::get<0>(result);  // halfedge-vertice mapping
            std::string mesh_file_path = std::get<1>(result);
            Eigen::MatrixXd halfedge_uv = loadMeshVertices(mesh_file_path);

            // Store the new meshes
            vertices_2DTissue_map[i] = Mesh_UV_Struct{i, halfedge_uv, h_v_mapping_vector};
            process_invalid_particle(vertices_2DTissue_map, vertex_data, vertex_data[i], num_part, distance_matrix_v, n, v0, k, v0_next, k_next, σ, μ, r_adh, k_adh, dt, tt);

            if (are_all_valid(vertex_data)) {
                break;
            }
        }
    
    }
}
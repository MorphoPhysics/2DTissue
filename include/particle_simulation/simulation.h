// simulation.h
#pragma once

#include <vector>
#include <Eigen/Dense>
#include <tuple>
#include <unordered_map>
#include <utilities/sim_structs.h>


std::tuple<Eigen::Matrix<double, Eigen::Dynamic, 2>, Eigen::MatrixXd, Eigen::MatrixXd, Eigen::VectorXd, Eigen::VectorXd> perform_particle_simulation(
    Eigen::Matrix<double, Eigen::Dynamic, 2>& r,
    Eigen::VectorXd& n,
    std::vector<int>& vertices_3D_active,
    Eigen::MatrixXd distance_matrix_v,
    Eigen::VectorXd& v_order,
    double v0,
    double k,
    double k_next,
    double v0_next,
    double σ,
    double μ,
    double r_adh,
    double k_adh,
    double dt,
    int tt,
    int num_part,
    std::unordered_map<int, Mesh_UV_Struct>& vertices_2DTissue_map,
    double plotstep = 0.1
);
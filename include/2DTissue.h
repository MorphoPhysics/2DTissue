// 2DTissue.h
#pragma once

#include <vector>
#include <filesystem>
#include <Eigen/Dense>
#include <map>

#include <utilities/sim_structs.h>

// Individuelle Partikel Informationen
struct Particle{
    double x_UV;
    double y_UV;
    double x_velocity_UV;
    double y_velocity_UV;
    double x_alignment_UV;
    double y_alignment_UV;
    double x_3D;
    double y_3D;
    double z_3D;
    int neighbor_count;
};

// System Informationen
struct System{
    double order_parameter;
    std::vector<Particle> particles;
};


class _2DTissue
{
private:
    // Include here your class variables (the ones used in start and update methods)
    std::filesystem::path mesh_path;
    double v0;
    double k;
    double k_next;
    double v0_next;
    double σ;
    double μ;
    double r_adh;
    double k_adh;
    double step_size;
    int step_count;
    int map_cache_count;

    Eigen::MatrixXd r;
    Eigen::MatrixXd n;
    std::vector<int> vertices_3D_active;
    Eigen::MatrixXd distance_matrix;
    Eigen::VectorXd v_order;
    Eigen::MatrixXd halfedge_uv;
    Eigen::MatrixXi faces_uv;
    Eigen::MatrixXd vertices_UV;
    Eigen::MatrixXd vertices_3D;
    std::vector<int64_t> h_v_mapping;
    double dt;
    int num_part;
    std::unordered_map<int, Mesh_UV_Struct> vertices_2DTissue_map;

public:
    _2DTissue(
        std::filesystem::path mesh_path,
        double v0 = 0.1,
        double k = 10,
        double k_next = 10,
        double v0_next = 0.1,
        double σ = 0.4166666666666667,
        double μ = 1,
        double r_adh = 1,
        double k_adh = 0.75,
        double step_size = 0.001,
        int step_count = 1,
        int map_cache_count = 30
    );
    void start(
        int particle_count = 10
    );
    System update(
        int tt
    );
};
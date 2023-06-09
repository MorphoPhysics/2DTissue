// error_checking.h

#pragma once

#include <Eigen/Dense>
#include <vector>

#include <utilities/sim_structs.h>

void error_unvalid_vertices(
    std::vector<VertexData> vertex_data
);

void error_invalid_values(
    Eigen::Matrix<double, Eigen::Dynamic, 2> r_UV_new
);

void error_lost_particles(
    Eigen::Matrix<double, Eigen::Dynamic, 2> r_UV_new,
    int num_part
);
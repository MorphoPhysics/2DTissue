// author: @Jan-Piotraschke
// date: 2023-04-12
// license: Apache License 2.0
// version: 0.1.0

#include <vector>
#include <Eigen/Dense>
#include <iostream>

#include <utilities/matrix_algebra.h>
#include <particle_simulation/particle_vector.h>

/*

Vicsek-type n correction adapted from "Phys. Rev. E 74, 061908"
*/
Eigen::VectorXd correct_n(
    const Eigen::Matrix<double, Eigen::Dynamic, 2>& r_dot,
    const Eigen::VectorXd n,
    double τ,
    double dt
){
    // cross product of n and r_dots
    auto norm_3D = normalize_3D_matrix(r_dot);
    auto cross_3D = calculate_3D_cross_product(n, r_dot);
    auto ncross = cross_3D.cwiseQuotient(norm_3D);

    Eigen::VectorXd n_cross_correction = (1.0 / τ) * ncross * dt;

    Eigen::VectorXd new_n = n - calculate_3D_cross_product(n, n_cross_correction);

    return new_n.rowwise().normalized();
}


// // TODO: dies könnte vlt nicht bei 2D gelten
// std::pair<Eigen::VectorXd, Eigen::VectorXd> calculate_particle_vectors(
//     Eigen::Matrix<double, Eigen::Dynamic, 2> &r_dot,
//     Eigen::VectorXd n,
//     double dt
// ){
//     // std::cout << "r_dot: " << r_dot << std::endl;

//     double τ = 1;
//     // make a small correct for n according to Vicsek
//     n = correct_n(r_dot, n, τ, dt);

//     // Project the orientation of the corresponding faces using normal vectors
//     n = n.rowwise().normalized();
//     Eigen::VectorXd nr_dot = r_dot.rowwise().normalized();

//     return std::pair(n, nr_dot);
// }

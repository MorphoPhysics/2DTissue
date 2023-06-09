// mesh_loader.h
#pragma once

#include <iostream>
#include <cstdint>
#include <map>
#include <string>
#include <vector>
#include <Eigen/Dense>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>

#include <utilities/sim_structs.h>

void loadMeshVertices(std::string filepath, Eigen::MatrixXd& vertices);

void loadMeshFaces(std::string filepath, Eigen::MatrixXi& faces);

std::pair<Eigen::MatrixXd, std::vector<int64_t>> get_mesh_data(
    std::unordered_map<int, Mesh_UV_Struct> mesh_dict,
    int mesh_id
);
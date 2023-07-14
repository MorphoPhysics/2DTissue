// author: @Jan-Piotraschke
// date: 2023-07-13
// license: Apache License 2.0
// version: 0.1.0

#include <gtest/gtest.h>
#include <fstream>
#include <boost/filesystem.hpp>

#include <utilities/2D_surface.h>

namespace fs = boost::filesystem;
const fs::path PROJECT_PATH = PROJECT_SOURCE_DIR;
const fs::path MESH_FOLDER = PROJECT_PATH  / "meshes";

TEST(MeshNameTest, NormalFileName) {
    std::string path = "/path/to/mesh_file.off";
    std::string expected = "mesh_file";
    EXPECT_EQ(get_mesh_name(path), expected);
}

TEST(MeshNameTest, FileNameWithMultiplePeriods) {
    std::string path = "/path/to/mesh_file.part1.off";
    std::string expected = "mesh_file.part1";
    EXPECT_EQ(get_mesh_name(path), expected);
}

TEST(MeshNameTest, NoFileName) {
    std::string path = "/path/to/";
    std::string expected = ".";
    EXPECT_EQ(get_mesh_name(path), expected);
}

TEST(SetUVBorderEdges, Test1) {
    std::string mesh_file_path = (MESH_FOLDER / "ellipsoid_x4.off").string();
    int start_node_int = 0;

    // Load the 3D mesh
    _3D::Mesh sm;
    std::ifstream in(CGAL::data_file_path(mesh_file_path));
    in >> sm;

    _3D::vertex_descriptor start_node = *(vertices(sm).first + start_node_int);
    std::vector<_3D::edge_descriptor> result = set_UV_border_edges(mesh_file_path, start_node);

    // Check the length of the result
    int expected = 44;
    EXPECT_EQ(result.size(), expected);
}

TEST(FarthestVertex, Test1) {
    std::string mesh_file_path = (MESH_FOLDER / "ellipsoid_x4.off").string();

    // Load the 3D mesh
    _3D::Mesh mesh;
    std::ifstream in(CGAL::data_file_path(mesh_file_path));
    in >> mesh;

    int start_node_int = 0;
    _3D::Mesh::Vertex_index start_node(start_node_int);

    // Create vectors to store the predecessors (p) and the distances from the root (d)
    std::vector<_3D::vertex_descriptor> predecessor_pmap(num_vertices(mesh));  // record the predecessor of each vertex
    std::vector<int> distance(num_vertices(mesh));  // record the distance from the root

    // Calculate the distances from the start node to all other vertices
    calculate_distances(mesh, start_node, predecessor_pmap, distance);

    // Find the farthest vertex from the start node
    _3D::vertex_descriptor target_node = find_farthest_vertex(mesh, start_node, distance);

    int expected = 1798;
    _3D::Mesh::Vertex_index vertex_expected(expected);

    EXPECT_EQ(target_node, vertex_expected);
}
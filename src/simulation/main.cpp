// author: @Jan-Piotraschke
// date: 2023-06-19
// license: Apache License 2.0
// version: 0.2.0

#include <iostream>
#include <filesystem>

#include <2DTissue.h>

const std::filesystem::path PROJECT_PATH = PROJECT_SOURCE_DIR;

int main()
{
    int num_frames = 300;

    // Initialize the 2DTissue object
    std::string mesh_path = PROJECT_PATH.string() + "/meshes/sphere.off";

    for (int num_part = 1000; num_part <= 1000; num_part += 100) {
        _2DTissue _2dtissue(mesh_path, num_part, num_frames);

        _2dtissue.start();

        std::clock_t start = std::clock();

        while(!_2dtissue.is_finished()) {
            System data = _2dtissue.update();
        }

        std::cout << _2dtissue.get_order_parameter() << '\n';

        std::clock_t end = std::clock();
        double duration = (end - start) / (double) CLOCKS_PER_SEC;
        std::cout << "Time taken: " << duration << " seconds" << '\n';
    }

    return 0;
}

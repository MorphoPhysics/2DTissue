# Polar active particles on arbitrary curved surfaces

[![Generic badge](https://img.shields.io/badge/arXiv-1610.05987-green.svg)](https://arxiv.org/abs/1610.05987)
[![Generic badge](https://img.shields.io/badge/Phys.Rev.E-95.062609-yellow.svg)](https://journals.aps.org/pre/abstract/10.1103/PhysRevE.95.062609)
![Generic badge](https://img.shields.io/badge/Matlab-R2022b-blue.svg)
[![Generic badge](https://img.shields.io/badge/License-AGPL3.0-orange.svg)](https://github.com/Sebastian-ehrig/Confined_active_particles/blob/main/LICENSE)

---

This model was developed to explore the effect of surface curvature on the collective behaviour of active (self-propelled) particles.

It is part of a wider research initiative in the context of pattern formation in biological systems.

The results of the simulation for ellipsoidal surfaces have been published in ["Curvature-controlled defect dynamics in active systems"]( https://journals.aps.org/pre/abstract/10.1103/PhysRevE.95.062609).

The accepted version of the paper is available for free on arxiv: https://arxiv.org/abs/1610.05987.


---

## Background information about the Project Code Setup

C++ is a static programming language, whereas Julia is a dynamic language.  

By combining a static language with a dynamic language, we can utilize the static, compiled C++ files for the routines in Geometry Processing.
These are for example following procedures:  
- Creating an UV surface from a 3D mesh
- Getting the longest distance
- Calculating paths
- Getting the distance between particles (e.g., with the Heat Method)

These compiled files are executed quickly since the code doesn't need to be translated every time it is executed.  

With Julia we can handle these data dynamically. This allows us easy adjustments using native mathematical expression (with symbols suchs as ϵ and β) and a more pleasant exploration of new analysis methods.


---

## Compile the C++ code for accessing it in Julia

0. only once: run `make init` to initialize the project
1. register your C++ script in the CMakeLists.txt file
2. open a terminal in the root of the project
3. run `make build` to compile the C++ code


---

## Package management in Julia

The `Project.toml` and `Manifest.toml` contain the package definitions for Julia.  
This allwos us to manage packages with Julias built-in package manager.  
This is how you manage packages with it:

- Open a terminal in the root of the project
- Run `julia -t 8` for parallel computing -> use at least 8 cores
- type `]` (closing square bracket)
- run `activate .`
- use `instantiate` to install all packages
- use `add <PackageName>` to add a new package
- use `rm <PackageName>` to remove a package
- use `up <PackageName>` to update a package to a newer version

All your modifications to the packages will be reflected in the `Project.toml` and `Manifest.toml` respectively.

## Run the simulation in Julia

Execute the following command in the project folder inside your shell: `julia -t 8 --project main.jl`


---

## Trouble shooting:  
If you can't use CxxWrap, please delete all the artifacts inside .julia/artifacts.  
Print out the Prefix_path using `CxxWrap.prefix_path()` inside the Julia REPL.  
If this works, you can run `make build` inside your shell.


---

## Requirements 

For C++ please install following libraries:
1. CGAL (version 5.5.1)
2. Boost (version 1.80.0)
3. Eigen (version 3.4.0_1)

For Matlab you need the Statistics toolbox installed.

---

## Theoretical Model

The model described in the publication is a Vicsek type model (Vicsek et al. 1995, Physical review letters 75(6): 1226) of spherical active particles with a fixed radius confined to the surface of an ellipsoid. Particle interactions are modelled through forces between neighbouring particles that tend to align their velocities (adapted from Szabo et al. 2006, Physical Review E 74(6): 061908).

The particle motion on the curved surface is performed by an unconstrained motion in the tangential plane followed by a projection onto the surface. To be able to use the model on arbitrary surfaces, surfaces are approximated with triangulated meshes.

All simulations have been performed in Matlab R2015b by solving an overdamped differential equations of motion using a forward Euler integration method with a fixed time step. Model paprameters have been chosen such that the study is in the regime of low noise and low energy and particles interact virually as hard spheres. 

For more details on the model please see publication.

---
### Example Videos

Supplemental material Movies of the paper ["Curvature-controlled defect dynamics in active systems"](https://journals.aps.org/pre/abstract/10.1103/PhysRevE.95.062609) showing particle and vortex dynamics on ellipsoidal surfaces of various aspect ratio.
Points of constant normal curvature (umbilics) are highlighted as red spheres, black arrows are the particle orientation vectors and the surface is color-coded according to the vortex order parameter (VOP, dark blue for VOP=0 and yellow for VOP=1).

#### Movie 1

Prolate spheroid with aspect ratio x/z = 0.25.

https://user-images.githubusercontent.com/102523524/208914480-f1010653-5fbc-4a3c-ba60-4246b6f5829d.mp4

#### Movie 2

Oblate spheroid with aspect ratio x/z = 4.

https://user-images.githubusercontent.com/102523524/208915160-afaf0adf-35be-401f-b2a1-544532e0afed.mp4

---

## Reference

Ehrig, S., Ferracci, J., Weinkamer, R., & Dunlop, J. W. Curvature-controlled defect dynamics in active systems. Phys. Rev. E 95, 062609 (2017)
https://journals.aps.org/pre/abstract/10.1103/PhysRevE.95.062609

Ehrig, S., Ferracci, J., Weinkamer, R., & Dunlop, J. W. (2016). Curvature-controlled defect dynamics in active systems. arXiv preprint arXiv:1610.05987.
https://arxiv.org/abs/1610.05987

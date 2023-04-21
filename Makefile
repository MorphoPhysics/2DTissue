# Makefile for building C++ libraries with CxxWrap and Julia

SHELL := /bin/bash

# Path to project directory
PROJECT_DIR := $(shell pwd)

# Path to external directory
EXTERNAL_DIR := $(PROJECT_DIR)/external

# Get JlCxx path
JLCXX_PATH := $(shell julia --project=@. -e 'using Pkg; Pkg.instantiate(); using CxxWrap; println(CxxWrap.prefix_path())')

# CMake flags
CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Release \
               -DCMAKE_CXX_FLAGS="-O2" \
			   -DCMAKE_C_COMPILER=$(shell brew --prefix llvm)/bin/clang \
			   -DCMAKE_CXX_COMPILER=$(shell brew --prefix llvm)/bin/clang++ \
               -DCMAKE_PREFIX_PATH=$(JLCXX_PATH);

# Extern repository name
REPOSITORY := libcxxwrap-julia

.PHONY: all
all: check_dependencies build

# Check if LLVM and Emscripten are installed, if not, install using Homebrew
.PHONY: check_dependencies
check_dependencies:
	@echo "Checking dependencies..."
	@OS=$$(uname -s); \
	if [ "$$OS" == "Darwin" ]; then \
		LLVM_PATH=$$(brew --prefix llvm); \
		if [ -z "$$LLVM_PATH" ]; then \
			echo "Installing LLVM via Homebrew..."; \
			brew install llvm; \
			LLVM_PATH=$$(brew --prefix llvm); \
		fi; \
		export PATH="$$LLVM_PATH/bin:$$PATH"; \
		export LDFLAGS="-L$$LLVM_PATH/lib $$LDFLAGS"; \
		export CPPFLAGS="-I$$LLVM_PATH/include $$CPPFLAGS"; \
		CMAKE_FLAGS="$$CMAKE_FLAGS -DCMAKE_C_COMPILER=$$LLVM_PATH/bin/clang -DCMAKE_CXX_COMPILER=$$LLVM_PATH/bin/clang++"; \
		which emcc >/dev/null || (echo "Installing Emscripten via Homebrew..."; brew install emscripten); \
		which julia >/dev/null || (echo "Installing Julia via Homebrew..."; brew install --cask julia); \
		which assimp >/dev/null || (echo "Installing Assimp via Homebrew..."; brew install assimp); \
		which yarn >/dev/null || (echo "Installing Yarn via Homebrew..."; brew install yarn); \
		pkg-config --exists opencv4 || (echo "Installing OpenCV via Homebrew..."; brew install opencv); \
	elif [ "$$OS" == "Linux" ]; then \
		MAKEFILE_DEPS="llvm clang emscripten julia assimp yarn opencv"; \
		for DEP in $$MAKEFILE_DEPS; do \
			which $$DEP >/dev/null || (echo "Installing $$DEP via package manager..."; sudo apt-get install -y $$DEP); \
		done; \
	elif [ "$$OS" == "MINGW64_NT-10.0" ]; then \
		@echo "Please ensure you have installed LLVM, Emscripten, Julia, Assimp, OpenCV and Yarn manually, and they are available in the PATH."; \
	else \
		@echo "Homebrew installation only works on macOS. Please install LLVM, Emscripten, Julia, Assimp, OpenCV and Yarn manually."; \
	fi
	@echo "Dependencies check complete."

########################################################################################################################
# Dependencies                                                                                                         #
########################################################################################################################

.PHONY: init
init: clone
	mkdir -p $(EXTERNAL_DIR) && \
	cd $(EXTERNAL_DIR)/$(REPOSITORY)-build && \
	cmake -DJulia_EXECUTABLE=$(shell which julia) ../$(REPOSITORY)
	$(MAKE) -C $(EXTERNAL_DIR)/$(REPOSITORY)-build -j $(shell sysctl -n hw.ncpu)

.PHONY: clone
clone:
ifeq ($(wildcard $(EXTERNAL_DIR)/$(REPOSITORY)/.),)
	mkdir -p $(EXTERNAL_DIR) && \
	git clone https://github.com/JuliaInterop/$(REPOSITORY).git $(EXTERNAL_DIR)/$(REPOSITORY)
	mkdir $(EXTERNAL_DIR)/$(REPOSITORY)-build
else
	@echo "Repository already exists"
endif

.PHONY: build
build:
	cmake -S $(PROJECT_DIR) \
		  -B $(PROJECT_DIR)/build \
		  $(CMAKE_FLAGS)
	$(MAKE) -C $(PROJECT_DIR)/build -j $(shell sysctl -n hw.ncpu)
	@echo "Build finished. The binaries are in $(PROJECT_DIR)/build/lib"


########################################################################################################################
# Setup                                                                                                                #
########################################################################################################################

.PHONY: clean
clean:
	rm -rf $(REPOSITORY)
	rm -rf $(PROJECT_DIR)/build
	rm -rf $(REPOSITORY)-Build

.PHONY: clean_env
clean_env:
	julia --project=@. -e 'using Pkg; for pkg in keys(Pkg.project().dependencies) Pkg.rm(pkg) end'

.PHONY: distclean
distclean: clean
	rm -rf $(PROJECT_DIR)/build/*

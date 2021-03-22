# This Makefile is being prepared to cache installation setups on
# jenkins@vali.inf.ed.ac.uk and ensure that WASM pipeline builds and route
# through regression tests. 


THREADS=40

SHELL    := /bin/bash

ROOT     := /mnt/Storage/jphilip/bergamot
BERGAMOT := $(ROOT)/bergamot-translator
EMSDK    := $(ROOT)/emsdk
MODELS   := $(ROOT)/models

BUILD        := $(ROOT)/build
NATIVE_BUILD := $(BUILD)/native
WASM_BUILD   := $(BUILD)/wasm
MODELS_GZ	 := $(BUILD)/models.gz.d

# Requires CMake > 3.12 or something. Locally compiled and added.
# 3.20.0-rc1 is used while testing this script
CMAKE := /home/jphilip/.local/bin/cmake
BUILD_TYPE ?= Release

# Parameterize builds by branches
BRANCH ?= jp/absorb-batch-translator 


.PHONY: emsdk bergamot models dirs

dirs:
	mkdir -p $(ROOT) $(BUILD) $(NATIVE_BUILD) $(WASM_BUILD) $(MODELS_GZ)

emsdk:
	git -C $(EMSDK) pull || git clone https://github.com/emscripten-core/emsdk.git $(EMSDK)
	$(EMSDK)/emsdk install latest

bergamot:
	git -C $(BERGAMOT) pull || git clone https://github.com/browsermt/bergamot-translator $(BERGAMOT)
	git -C $(BERGAMOT) checkout $(BRANCH)
	git -C $(BERGAMOT) submodule update --init --recursive

models: dirs
	git -C $(MODELS) pull || git clone https://github.com/mozilla-applied-ml/bergamot-models $(MODELS)
	cp -r $(MODELS)/* $(MODELS_GZ)/
	gunzip $(MODELS_GZ)/*/*

first-setup: emsdk dirs models

wasm: dirs bergamot
	$(EMSDK)/emsdk activate latest &> /tmp/error.log || cat /tmp/error.log
	source $(EMSDK)/emsdk_env.sh && cd $(WASM_BUILD) && \
		emcmake $(CMAKE) -L \
			-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
			-DCOMPILE_WASM=on \
			$(BERGAMOT)
	cd $(WASM_BUILD) &&  make -f $(WASM_BUILD)/Makefile -j$(THREADS)

native: dirs bergamot
	cd $(NATIVE_BUILD) && \
		$(CMAKE) \
			-L \
			-DCOMPILE_CUDA=off -DUSE_WASM_COMPATIBLE_SOURCES=off\
			-DCMAKE_BUILD_TYPE=$(BUILD_TYPE) \
		   	$(BERGAMOT)

	cd $(NATIVE_BUILD) && make -f $(NATIVE_BUILD)/Makefile -j$(THREADS)

clean:
	rm $(BUILD) -rv

clean-native: 
	rm $(NATIVE_BUILD) -rv

clean-wasm:
	rm $(WASM_BUILD) -rv

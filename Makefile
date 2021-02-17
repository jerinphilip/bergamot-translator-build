

THREADS=40

SHELL := /bin/bash

ROOT := /mnt/Storage/jphilip/bergamot
BERGAMOT := $(ROOT)/bergamot-translator
EMSDK    := $(ROOT)/emsdk
MODELS   := $(ROOT)/models

BUILD := $(ROOT)/build
NATIVE_BUILD := $(BUILD)/native
WASM_BUILD   := $(BUILD)/wasm

.PHONY: emsdk bergamot models dirs

dirs:
	mkdir -p $(ROOT) $(BUILD) $(NATIVE_BUILD) $(WASM_BUILD)

emsdk:
	git -C $(EMSDK) pull || git clone https://github.com/emscripten-core/emsdk.git $(EMSDK)
	$(EMSDK)/emsdk install latest

bergamot:
	git -C $(BERGAMOT) pull || git clone https://github.com/browsermt/bergamot-translator $(BERGAMOT)

models:
	git -C $(MODELS) pull || git clone https://github.com/mozilla-applied-ml/bergamot-models $(MODELS)

wasm: emsdk bergamot models dirs
	$(EMSDK)/emsdk activate latest
	git -C $(BERGAMOT) checkout wasm-integration
	source $(EMSDK)/emsdk_env.sh && cd $(WASM_BUILD) && emcmake cmake DCOMPILE_WASM=on -DPACKAGE_DIR=$(MODELS) $(BERGAMOT)
	cd $(WASM_BUILD) && make -f $(WASM_BUILD)/Makefile -j$(THREADS)

native:  dirs bergamot
	git -C $(BERGAMOT) checkout jp/absorb-batch-translator
	cd $(NATIVE_BUILD) && cmake -DCOMPILE_CUDA=off -DCMAKE_BUILD_TYPE=Release \
      -DCOMPILE_DECODER_ONLY=off -DCOMPILE_LIBRARY_ONLY=off -DUSE_MKL=on \
      -DCOMPILE_THREAD_VARIANT=on -S $(BERGAMOT)
	cd $(NATIVE_BUILD) && make -f $(NATIVE_BUILD)/Makefile -j$(THREADS)



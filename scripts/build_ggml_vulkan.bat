@echo off
REM Build only ggml-vulkan.dll from a patched llama.cpp source tree.
REM
REM Pre-condition: C:\tmp\llamacpp_<TAG>\ exists and the COOPMAT-disable
REM patch from patches/disable-coopmat.patch has been applied.
REM
REM Adjust the source path below if you used a different location or tag.

setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" || exit /b 1

set SRC=C:\tmp\llamacpp_b9016
if not "%~1"=="" set SRC=%~1

cd /d "%SRC%" || exit /b 1

REM GGML_BACKEND_DL=ON is required: the upstream bundle we swap into is built
REM this way, so its loader finds each backend through the generic
REM ggml_backend_init / ggml_backend_score exports. Without this flag the
REM rebuilt ggml-vulkan.dll exports only the ggml_backend_vk_* API, ggml's
REM dynamic loader can't register it ("failed to find ggml_backend_init"), and
REM Vulkan silently never loads -> CPU-only offload.
cmake -B build_vulkan ^
  -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DGGML_VULKAN=ON ^
  -DGGML_BACKEND_DL=ON ^
  -DGGML_NATIVE=OFF ^
  -DGGML_BUILD_TESTS=OFF ^
  -DGGML_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TESTS=OFF ^
  -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_CURL=OFF ^
  -DBUILD_SHARED_LIBS=ON || exit /b 1

cmake --build build_vulkan --config Release --target ggml-vulkan -j 8 || exit /b 1

echo --- Done. DLL location:
dir build_vulkan\bin\ggml-vulkan.dll 2>nul

REM Guard against the GGML_BACKEND_DL regression: the DLL is useless to ggml's
REM loader unless it exports the generic entry points. Fail loudly if missing.
echo --- Verifying dynamic-backend exports:
dumpbin /exports build_vulkan\bin\ggml-vulkan.dll | findstr /C:"ggml_backend_init" /C:"ggml_backend_score" || (echo ERROR: ggml-vulkan.dll is missing ggml_backend_init/ggml_backend_score ^(GGML_BACKEND_DL not applied^) & exit /b 1)

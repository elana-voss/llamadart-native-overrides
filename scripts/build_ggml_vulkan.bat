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

cmake -B build_vulkan ^
  -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DGGML_VULKAN=ON ^
  -DGGML_BUILD_TESTS=OFF ^
  -DGGML_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TESTS=OFF ^
  -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_CURL=OFF ^
  -DBUILD_SHARED_LIBS=ON || exit /b 1

cmake --build build_vulkan --config Release --target ggml-vulkan -j 8 || exit /b 1

echo --- Done. DLL location:
dir build_vulkan\bin\ggml-vulkan.dll 2>nul

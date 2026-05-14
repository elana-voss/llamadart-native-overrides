# llamadart-native-overrides

Patched native bundles for [leehack/llamadart](https://github.com/leehack/llamadart) — drop-in for environments where the upstream `leehack/llamadart-native` bundle crashes.

## What's patched

The `windows-x64` bundle's `ggml-vulkan.dll` is rebuilt from llama.cpp at the matching tag, with `GGML_VULKAN_COOPMAT_GLSLC_SUPPORT` and `GGML_VULKAN_COOPMAT2_GLSLC_SUPPORT` disabled. This skips the `vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR` / `...FlexibleDimensionsPropertiesNV` calls that crash inside:

- NVIDIA Blackwell driver on RTX 50-series laptop GPUs (sm_120). NVIDIA forum: <https://forums.developer.nvidia.com/t/blackwell-rtx-5050-laptop-sm-120-vulkan-driver-crashes-in-cooperative-matrix-property-queries/369162>
- AMD AMDVLK on integrated GPUs (RDNA 3.5 Strix Point). [AMDVLK#422](https://github.com/GPUOpen-Drivers/AMDVLK/issues/422). Upstream workaround PR closed: [ggml-org/llama.cpp#22750](https://github.com/ggml-org/llama.cpp/pull/22750).

The bundle is also slimmed to `cpu + vulkan` backends only (CUDA / BLAS DLLs dropped), so a fresh pub-cache pull is ~13 MB instead of ~700 MB.

## Usage

Used via a [forked llamadart](https://github.com/elana-voss/llamadart) whose `hook/build.dart` redirects `windows-x64` downloads to this repository's releases. Non-windows-x64 bundles still come from upstream `leehack/llamadart-native`.

## Release tags

Tags match upstream llama.cpp build numbers (`b9016`, etc.). Only build numbers that cardwave actively uses are published — this is not a mirror of upstream.

# Rebuilding the windows-x64 bundle

This document captures how the bundle hosted in each release was produced, so a new tag (e.g. when llamadart moves to a new llama.cpp build) can be reproduced without re-deriving anything.

## What changes vs upstream

1. `ggml-vulkan.dll` is rebuilt from source with two GLSL extension probes commented out (see `patches/disable-coopmat.patch`). The probes call `vkGetPhysicalDeviceCooperativeMatrixProperties*`, which crashes inside the affected drivers — disabling them at compile time removes the calls entirely.
2. The bundle is slimmed to `cpu + vulkan` only (CUDA / BLAS DLLs dropped).

The rebuild **must** use `-DGGML_BACKEND_DL=ON` (the upstream bundle is built that way), together with `-DGGML_NATIVE=OFF` (CMake rejects `GGML_BACKEND_DL` while `GGML_NATIVE` is on; we only build the Vulkan target so the host-CPU tuning that `GGML_NATIVE` controls is irrelevant here). It makes each backend DLL export the generic `ggml_backend_init` / `ggml_backend_score` entry points that ggml's runtime loader (`ggml_backend_load_all_from_path`) requires. A rebuild without it produces a `ggml-vulkan.dll` exporting only the `ggml_backend_vk_*` API; the loader then can't register it and logs `failed to find ggml_backend_init in ggml-vulkan.dll`, so Vulkan never loads and offload silently falls back to CPU. The build script verifies the exports and fails if they're absent.

The non-windows-x64 bundles are not touched; cardwave's llamadart fork redirects only `windows-x64` here.

## Build environment (Windows host, one-time setup)

- Visual Studio 2022 Community with the "Desktop development with C++" workload (provides `cl.exe`, `link.exe`, the Windows SDK).
- [Vulkan SDK](https://vulkan.lunarg.com/sdk/home) (provides `glslc.exe` and the Vulkan headers/loader).
- CMake (the one bundled with miniconda works; any modern CMake is fine).
- Ninja (any source — included with Git for Windows under `C:\msys64\mingw64\bin\` on this host).

## Reproducible build

```powershell
# 1. Pick the target llama.cpp build tag (must match the version llamadart uses).
$TAG = 'b9016'

# 2. Clone llama.cpp at that tag.
cd C:\tmp
git clone --depth 1 --branch $TAG https://github.com/ggml-org/llama.cpp.git "llamacpp_$TAG"

# 3. Apply the COOPMAT-disable patch.
cd "C:\tmp\llamacpp_$TAG"
git apply <path-to-overrides-repo>\patches\disable-coopmat.patch

# 4. Build (this is the script committed below). Runs vcvars64.bat, configures
#    CMake with GGML_VULKAN=ON and GGML_BACKEND_DL=ON, builds the ggml-vulkan
#    target only, then verifies the DLL exports ggml_backend_init/score.
cmd /c <path-to-overrides-repo>\scripts\build_ggml_vulkan.bat

# 5. Verify the patched DLL exists.
Get-Item "C:\tmp\llamacpp_$TAG\build_vulkan\bin\ggml-vulkan.dll"
```

The build takes ~5 minutes on a modern dev laptop.

## Repack the bundle

```powershell
# 6. Download the matching upstream tarball.
$UPSTREAM = "https://github.com/leehack/llamadart-native/releases/download/$TAG/llamadart-native-windows-x64-$TAG.tar.gz"
curl -L -o "C:\tmp\upstream-$TAG.tar.gz" $UPSTREAM

# 7. Extract.
mkdir "C:\tmp\bundle-$TAG"
tar xzf "C:\tmp\upstream-$TAG.tar.gz" -C "C:\tmp\bundle-$TAG"

# 8. Swap in our patched DLL.
Copy-Item "C:\tmp\llamacpp_$TAG\build_vulkan\bin\ggml-vulkan.dll" "C:\tmp\bundle-$TAG\ggml-vulkan.dll" -Force

# 9. (Optional) Slim — drop CUDA + BLAS DLLs that the cardwave config never selects.
foreach ($drop in 'cublas64_12.dll','cublaslt64_12.dll','cudart64_12.dll','ggml-cuda.dll','ggml-blas.dll','openblas.dll') {
  Remove-Item "C:\tmp\bundle-$TAG\$drop" -ErrorAction SilentlyContinue
}

# 10. Repack with the exact name the llamadart hook downloads.
cd "C:\tmp\bundle-$TAG"
tar czf "C:\tmp\llamadart-native-windows-x64-$TAG.tar.gz" .
```

## Publish

```bash
gh release create $TAG /c/tmp/llamadart-native-windows-x64-$TAG.tar.gz \
  --repo elana-voss/llamadart-native-overrides \
  --title "$TAG (windows-x64, cpu+vulkan, coopmat-disabled)" \
  --notes "see README.md and BUILD.md"
```

Then bump the SHA in cardwave's [llamadart fork](https://github.com/elana-voss/llamadart) `hook/build.dart` (`_llamaCppTag` constant) and update cardwave's `pubspec.yaml` `dependency_overrides.llamadart.ref`.

## When this can be deleted

When NVIDIA ships a Blackwell driver fix and AMD ships an AMDVLK fix for integrated GPUs, the bundle no longer needs the COOPMAT patch. At that point cardwave can repin to upstream `leehack/llamadart` directly and this repo becomes dead weight.

Tracking:
- [NVIDIA Blackwell forum post](https://forums.developer.nvidia.com/t/blackwell-rtx-5050-laptop-sm-120-vulkan-driver-crashes-in-cooperative-matrix-property-queries/369162) — acked, no fix shipped.
- [AMDVLK#422](https://github.com/GPUOpen-Drivers/AMDVLK/issues/422) — open, no AMD response.

# ffmpeg-builder

A cross‑platform CI project that builds **portable FFmpeg binaries** (and optional `ffprobe`) with a **declarative profile** of codecs/features. Works locally and on **GitHub Actions**; produces zipped artifacts per OS/arch ready to drop into your project.

- Linux: Ubuntu 22.04 (x86_64) — optional aarch64 via Docker/QEMU
- macOS: Apple Silicon (arm64) & Intel (x86_64)
- Windows: MSYS2/MinGW x86_64 (FFplay off by default)

Supports popular codecs via source builds by default:

- **x264**, **x265**, **SVT‑AV1**, **AOM‑AV1**, **Opus**, **fdk‑aac** (nonfree, opt‑in), **libvpx** (VP8/VP9)
- Easily extendable (OpenH264, libvmaf, libass, etc.)

---

## Quick start (local)

```bash
# Clone
git clone https://github.com/alfg/ffmpeg-builder.git
cd ffmpeg-builder

# Choose a profile (or edit/duplicate it)
cat profiles/default.yml

# Bootstrap toolchain & build deps + FFmpeg into ./out/<triplet>
./scripts/bootstrap-linux.sh   # or bootstrap-macos.sh / bootstrap-windows.ps1
PROFILE=profiles/default.yml \
  ./scripts/build-ffmpeg.sh

# Package artifacts (zip + manifest)
./scripts/package.sh
```

Artifacts land in `dist/ffmpeg-<version>-<os>-<arch>[-nonfree].zip` with:

- `bin/ffmpeg`, `bin/ffprobe` (and `ffplay` if enabled)
- `LICENSES/` for bundled libraries
- `build-manifest.json` and `configure-flags.txt`

## Local overrides via env vars

- `FFMPEG_VERSION=7.1`
- `ENABLE_X264=0 ENABLE_AOM=1 ...`
- `ENABLE_NONFREE=1 ENABLE_FDK_AAC=1`
- `PARALLEL=8`

---

## Notes & tips

- **Reproducibility**: cache the `./.build-cache` and `.ccache` to speed up CI; pin versions by swapping source tarball URLs.
- **Security**: If enabling `fdk-aac`, set `nonfree: true` and ensure redistribution aligns with license terms.
- **Extending**: Add another script under `scripts/_ports/<lib>.sh` and append a `CONFIG_FLAGS+=(--enable-lib<lib>)` in `build-ffmpeg.sh`.
- **macOS universal**: Build once per arch and `lipo -create` into a universal binary if you need a single file.
- **Linux aarch64**: Use Docker + QEMU (`setup-qemu-action`) to cross-compile or run on `ubuntu-24.04-arm` runners when available.
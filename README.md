# FileSqueeze third-party components

[FileSqueeze](https://apps.microsoft.com/detail/9N52H890DG1W) is a closed-source
Windows application. It ships some open-source native components, and some of them
are licensed under the GNU LGPL. This repository gives the corresponding source,
the exact build recipe and the replacement instructions for those components.

FileSqueeze's own code is not in this repository. The application uses FFmpeg as a
separate process and loads the ImageMagick library as a separate DLL.

| Component | Folder | How FileSqueeze uses it |
| --- | --- | --- |
| FFmpeg 8.1.3 (LGPL v3), with zlib, zimg, dav1d, libvpl, nv-codec-headers, AMF headers | [ffmpeg/](ffmpeg/) | `ffmpeg.exe` and `ffprobe.exe` run as child processes |
| Magick.NET 14.16.0 native library (ImageMagick + delegates) | [magick/](magick/) | `Magick.Native-Q8-x64.dll`, loaded at run time |

## Releases

Each FileSqueeze version that changes a native component has a GitHub release here.
The [release workflow](.github/workflows/release.yml) builds every release from its tag,
and the workflow log shows the full build. The release attaches:

- `ffmpeg-…-win64-lgpl-filesqueeze.zip`: the exact binaries in the app package, with licences,
  `build-configuration.txt`, `toolchain.txt` and `SHA256SUMS`;
- `ffmpeg-…-sources.tar`: every source archive used for the build and this recipe;
- source archives of the Magick revisions in [magick/README.md](magick/README.md).

## Rebuilding FFmpeg

Requires Docker with Linux containers.

```powershell
./ffmpeg/build.ps1        # Windows
```

```sh
cd ffmpeg && docker build -t filesqueeze-ffmpeg-build . && \
  docker run --rm -v "$PWD/cache:/cache" -v "$PWD/out:/out" filesqueeze-ffmpeg-build
```

The build checks the SHA-256 of every source archive in
[ffmpeg/sources.lock](ffmpeg/sources.lock). To build modified FFmpeg, change the source
archive and its hash in the lock file. FFmpeg is configured without GPL or non-free parts.
See `build-configuration.txt` in the output for the exact configure line.

## Replacing a component in an installed FileSqueeze

The Store installs FileSqueeze into a protected folder. To run FileSqueeze with a modified
library:

1. Download the FileSqueeze MSIX (for example with the Store's download links), or copy the
   installed folder from `C:\Program Files\WindowsApps\XAKPCDevLabs.FileSqueeze_*` to a
   writable location.
2. Replace `Tools\ffmpeg.exe`, `Tools\ffprobe.exe` and the `Tools\*.dll` files with your build
   of FFmpeg, or replace `Magick.Native-Q8-x64.dll` with your build of Magick.Native.
3. Register the folder as a development package:
   `Add-AppxPackage -Register .\AppxManifest.xml` (Developer Mode must be on).

FileSqueeze passes ordinary command-line arguments to `ffmpeg.exe` and `ffprobe.exe`.
A replacement build must provide the `h264_mf` encoder, or at least one of `h264_nvenc`,
`h264_qsv`, `h264_amf`, and the `aac` encoder plus the `scale`, `zscale` and `tonemap` filters.

The FileSqueeze licence terms do not restrict your rights under the LGPL to modify these
components, and to reverse engineer FileSqueeze to debug such modifications.

## Recipe licence

The build scripts in this repository are under the MIT licence ([LICENSE](LICENSE)).
Each component keeps its own licence.

Questions: fs@xakpc.dev

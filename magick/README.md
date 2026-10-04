# Magick.NET native library

FileSqueeze uses the unmodified `Magick.Native-Q8-x64.dll` from the
[Magick.NET-Q8-AnyCPU 14.16.0](https://www.nuget.org/packages/Magick.NET-Q8-AnyCPU/14.16.0)
NuGet package. The application loads it as a separate DLL at run time.

The DLL statically contains ImageMagick and its delegate libraries. Some are
under the LGPL (for example libheif and libde265 for HEIC). Their full licence
texts are in `Magick-NOTICE.txt`, which ships with FileSqueeze.

## Corresponding source

| Component | Revision |
| --- | --- |
| Magick.Native (build scripts for the DLL) | [dlemstra/Magick.Native@1187ae6](https://github.com/dlemstra/Magick.Native/tree/1187ae6ead3c4ac8b3020cfd8a98b9990697eec6) |
| Delegate library sources and recipes | [ImageMagick/Dependencies@c97d2ef](https://github.com/ImageMagick/Dependencies/tree/c97d2ef53d5ee9c25e70e98a27a306b932f12acb) |
| libheif | [ImageMagick/heif@5def418](https://github.com/ImageMagick/heif/tree/5def4181577ada890da9b8cb0b913f93f24c715e) |
| libde265 | [ImageMagick/de265@80e57d4](https://github.com/ImageMagick/de265/tree/80e57d4a56dd9bd725e1d937be8060fbffc36ca1) |

Each FileSqueeze release on this repository also attaches source archives of
these revisions, so the source stays available if an upstream repository changes.

## Replacing the library

Build `Magick.Native-Q8-x64.dll` from the Magick.Native sources (optionally with
modified delegate libraries). The exported interface must match Magick.NET
14.16.0. Replace the file of the same name in the FileSqueeze installation
directory. See the top-level [README](../README.md) for how to get a writable
copy of an installed Store application.

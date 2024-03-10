# OVERVIEW

Biber is a sophisticated bibliography processing backend for the LaTeX
biblatex package. It supports an unsurpassed feature set for automated
conformance to complex bibliography style requirements such as labelling,
sorting and name handling. It has comprehensive Unicode support.

**Please note**--the default download for all platforms is 64-bit. Please
look in the files section for the correct 32-bit platform instead of
using the default download button if you want 32-bit.

## REQUIREMENTS

Biber is written in Perl with the aim of providing a customised and
sophisticated data preparation backend for biblatex.

You do not need to install Perl to use biber--binaries are provided for many
operating systems via the main TeX distributions (TeXLive, MacTeX, MiKTeX)
and also via download from SourceForge.

You only need a Perl installation to use biber in one of the following
cases:

- A binary version is not available for your OS/platform.
- You wish to keep up with all of the bleeding-edge git commits before they are packaged into a binary.

For the vast majority of users, using the latest binary for the OS/platform
you are using will be what you want to do. For details on the requirements
for installing the Perl program version, please see the biber PDF documentation.

The git repository for Biber is kept on github:

[https://github.com/plk/biber](https://github.com/plk/biber)

## INSTALLING

If you wish to install from the source, make sure you have permissions to
install Perl modules, get the source and from the top-level source
directory, do:

```
perl Build.PL
./Build installdeps
./Build install
```

biber should now be available in your path, run `biber --version` to verify.

## USEFUL ENVIRONMENT VARIABLES

There are a few environment variables for `biber` which are useful sometimes:

### ISBN_RANGE_MESSAGE

`biber` uses the Perl `Business::ISBN::Data` module to verify ISBNs. This relies
on a data file called `RangeMessage.xml` which comes with the module and which
is packaged with `biber`. This can be updated quite regularly and the packaged
version might be several months old. If you find yourself needing an updated
version of this file (e.g. you have ISBN validation errors when using `biber`s
`--validate-datamodel` option), then you can download a recent version from
here:
[https://www.isbn-international.org/range_file_generation](https://www.isbn-international.org/range_file_generation)
and point to the location with this environment variable.

### PAR_GLOBAL_TMPDIR

When a new version of the binary version of `biber` first runs, it unpacks
itself to location which is OS dependent but usually some sort of temporary
location (which you can see with `biber --cache`). Sometimes, this causes
problems because the OS might clean up files in the default location or you
might not have permissions to unpack `biber` to the default location. You can
use this environment variable to set the location of the unpack cache.

## SUPPORT AND DOCUMENTATION

After installing, `biber --help` will give you the basic documentation.

The latest PDF documentation can be found here:

[https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber](https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber)

More information, bugfix releases, forums and bug tracker are available at:

[https://github.com/plk/biber](https://github.com/plk/biber)

## BUILDING

If you wish to build you own binary, see the main biber PDF documentation
and particularly the included BUILDERS.README file
The PDF documentation is in the `documentation` folder for the release on
Sourceforge.

## LICENCE

Copyright 2009-2024 François Charette and Philip Kime, all rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

# Package

version = "1.0.0"
author = "Augusto Coronel"
description = "The declarative GNU Stow"
license = "MIT"
srcDir = "src"
bin = @["neostow"]

# Dependencies

requires "nim >= 2.2.4"

task gendoc, "Generate documentation":
  exec "nim doc --project --outdir=docs src/neostow.nim"
  exec "nim md2html --outdir=docs --o:docs/index.html README.md"

doc viewers

decdump.c    util that converts a binary file into comma-separated decimal
             values

doc.asm      scrolling petscii doc viewer, 24 lines, pal only
doc2.asm     scrolling petscii doc viewer, 23 lines, pal and ntsc
conv.c       convert .c files from kameli petscii editor into a .prg file
             (based on doc2) that views the pages

pagedoc.asm  separate page petscii doc viewer, 25 lines, msi-logo and
             instructions and page counter in border, rle-compressed pages,
             pal and ntsc
pageconv.c   convert .c files from kameli petscii editor into a hex dump that
             must be copied into pagedoc.asm. each page must have its own .c
             file!

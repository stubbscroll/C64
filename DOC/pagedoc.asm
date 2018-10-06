; petscii doc viewer with colours and pages (25 lines per page)
; msi-logo in upper border, infopanel in lower border
; ntsc-compatible because there's nothing really complicated going on
; link-friendly: docs are rle-compressed to save memory

; stuff that can be improved/optimized
; - replace the upper half of the sinus table, and use bidirectional loop
;   over the first half, should save around 128 bytes
; - go even further and calculate upper half of curve on the fly, saves up to
;   64 bytes (minus additional code)
; - code that detects if joystick goes from high to low is ugly, could be
;   improved i guess
; - try different colours for page numbers in lower border
; - add preservation of $3fff for non-black background colour

bgcol         = 0 ; background colour, border+screen must have the same colour
                  ; if it's black we don't have to care about $3fff
pages         = 2

screen        = $0400
showcharset   = $16   ; d018 value. 14=upper case, 16=lower case

spritecol     = $01
spritecol1    = $0e
spritecol2    = $06

panelcol1     = $0c
panelcol2     = $07 ; not currently used

	; zeropage variables

temp	= $f9
curpage	= $fa ; current page
sinusp	= $fb
ptr1	= $fc ; pointers
ptr2	= ptr1+2 ; this must be after ptr1 in memory

zp1	= $f9 ; reuse zp variables with more sensible names
zp2	= $fa
zp3	= $fb

	!to "pagedoc.prg",cbm
	* = $0801
	; sys start (must be < 10000)
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	; copy memory to $0800, then run program
	; warning, i don't think i've tested this routine
link	ldx #0
	ldy #50     ; number of pages to copy
linka	lda $aa00,x ; the linked program starts here in memory
linkb	sta $0800,x ; this can be changed, can go down to $0200
	inx
	bne linka
	inc linka+2
	inc linkb+2
	dey
	bne linka
	lda #$37
	sta $01
linkc	jmp linkc ; replace with jump to linked program
	; copy copy-routine to stack
copy	sei
	lda #$34
	sta $01
	ldx #copy-link-1
-	lda link,x
	sta $0100,x
	dex
	bpl -
	jmp $0100

	; we have 3 bytes free, put something here
	!byte 0,0,0

	; megastyle sprites, must be aligned to 64 bytes
sprites	!byte 20,0,80,105,1,148,170,2,156,170,70,188,166,138,124,173
	!byte 153,252,175,171,252,175,103,124,175,239,124,175,221,124,175,253
	!byte 188,175,49,188,175,50,188,175,2,188,175,2,188,175,2,188
	!byte 175,2,188,175,2,188,239,3,188,255,3,252,60,0,240,0
	!byte 26,165,0,106,169,64,170,169,193,167,255,194,175,255,194,175
	!byte 255,6,175,0,10,175,0,10,173,160,10,166,164,10,170,172
	!byte 10,170,156,10,171,252,10,167,240,10,175,0,10,173,0,10
	!byte 165,165,14,166,169,78,234,169,195,255,255,195,63,255,0,0
	!byte 26,80,1,106,148,6,170,156,26,159,252,41,191,252,43,127
	!byte 240,103,252,0,175,240,0,172,240,80,172,241,148,172,242,156
	!byte 173,242,188,165,242,188,166,242,188,170,242,188,170,214,188,169
	!byte 90,188,175,106,124,156,170,252,188,255,240,124,255,192,240,0
	!byte 144,0,26,164,0,106,167,1,170,223,2,159,255,2,191,247
	!byte 198,127,23,202,252,23,202,124,27,198,191,43,194,159,107,194
	!byte 167,171,192,105,171,192,26,171,192,6,171,192,2,107,192,6
	!byte 43,195,170,43,206,170,27,206,169,63,207,255,63,3,255,0
	!byte 80,26,165,148,106,169,156,106,169,252,95,247,252,95,255,240
	!byte 63,247,0,0,23,0,0,23,0,0,27,192,0,43,240,0
	!byte 43,240,0,43,124,0,43,124,0,43,188,0,43,188,0,43
	!byte 124,0,39,240,0,47,240,0,31,192,0,63,0,0,60,0
	!byte 1,64,80,70,81,148,202,114,156,202,242,188,202,242,188,202
	!byte 242,188,202,214,188,202,90,188,198,90,188,197,127,124,197,255
	!byte 252,195,255,124,192,1,124,192,1,124,192,1,188,206,182,188
	!byte 206,154,188,206,170,124,3,170,240,3,255,240,0,255,192,0
	!byte 20,0,1,101,0,6,167,0,10,175,0,10,175,0,10,175
	!byte 0,10,175,0,10,175,0,10,175,0,10,175,0,10,175,0
	!byte 10,175,0,10,175,0,10,175,0,10,173,85,10,165,85,74
	!byte 166,170,202,234,170,202,234,171,206,255,255,15,63,255,3,0
	!byte 170,80,0,170,148,0,170,156,0,127,252,0,255,252,0,255
	!byte 240,0,240,0,0,240,0,0,218,0,0,106,64,0,170,192
	!byte 0,169,192,0,191,192,0,127,0,0,240,0,0,208,0,0
	!byte 90,80,0,106,148,0,170,156,0,255,252,0,255,240,0

	; irq3: double-irq that opens sideborder for msi sprites, prepare infobar sprites
	; code placed here because the branches that depend on timing won't cross pages
irq3	; stable timing
	ldx #7
-	dex
	bpl -
ntsc	lda #$ea ; change stuff here for ntsc
	bit $24
	lda $d012
	cmp $d012
	beq +    ; eliminate final jitter
+	ldx #5
-	dex
	bpl -
ntsc2	nop
	nop
	nop
	ldx #22
-	nop
	nop
	nop
ntsc3	ldy #$ea ; change more stuff for ntsc
	dec $d016
	inc $d016
	ldy #3
--	dey
	bpl --
	dex
	bne -
	; prepare infopanel sprites
	lda #$fd
	jsr spritey
	inx
	stx $d01c

	ldx #7
	stx temp
-	lda spriteptr,x
	sta $07f8,x
	lda #panelcol1
	sta $d027,x
	dex
	bpl -
	pla ; we can't txs safely here, because the original irq could have
	pla ; happened inside a subroutine. hence, the code is 2 bytes longer
	pla
	lda #$58
	jsr spritex
	; read keyboard
	lda $dc01
	tax
	eor olddc01
	tay
	stx olddc01
	and #$20 ; cbm: previous page
	beq +
	and olddc01
	bne +
	; previous page
	lda #1
	sta prevpage
+	tya
	and #$10 ; space: next page
	beq +
	and olddc01
	bne +
	; next page
	lda #1
	sta nextpage
+	; read joystick in port 2
	lda $dc00
	tax
	eor olddc00
	tay
	stx olddc00
	and #$04 ; left: previous page
	beq +
	and olddc00
	bne +
	; previous page
	lda #1
	sta prevpage
+	tya
	and #$08 ; right: next page
	beq +
	and olddc00
	bne +
	; next page
	lda #1
	sta nextpage
+	; next irq
	lda #$f8
	sta $d012
	ldx #<irq1
	ldy #>irq1
	jmp irqend

start	sei
	; insert rti at $03ff since this location survives memory copy afterwards
	lda #$40
	sta $03ff
	ldx #$ff
	txs
	ldy #$03
	stx $0318 ; we'll be in 01-bank $33 briefly, safeguard
	sty $0319
	stx $fffa
	sty $fffb
	ldx #<irq1
	ldy #>irq1
	stx $fffe
	sty $ffff
	; init infopanel!
	; clear sprites
	ldx #7  ; zp1 = number of loop iterations for printloop
	stx zp1 ; initialize zp1 while we have the right value
--	lda spriteptr,x
	jsr getptr
	ldy #$3e
	lda #0
-	sta (ptr1),y
	dey
	bpl -
	dex
	bpl --
	; print text in sprites
	inx
	stx zp2 ; zp2 = sprite number (0-7)
	lda #$33
	sta $01
printloop ldx zp2
	lda spriteptr,x
	jsr getptr
	; top of first char line: sprite line 5
	; the value of ptr1+0 is already in A, saves an lda
	ora #$0f
	sta ptr1+0
	lda zp2
	asl
	adc zp2
	tax
	stx zp3 ; zp3 = char number (zp2*3)
	lda infobar,x
	jsr printchar
	inc ptr1+0
	ldx zp3
	lda infobar+1,x
	jsr printchar
	inc ptr1+0
	ldx zp3
	lda infobar+2,x
	jsr printchar
	; jump to next row
	lda ptr1+0
	eor #$36 ; faster+shorter than clc, adc #$16
	sta ptr1+0
	ldx zp3
	lda infobar+24,x
	jsr printchar
	inc ptr1+0
	ldx zp3
	lda infobar+25,x
	jsr printchar
	inc ptr1+0
	ldx zp3
	lda infobar+26,x
	jsr printchar
	inc zp2
	dec zp1
	bpl printloop
	; create backup of rom digit chars
	ldx #79
-	lda $d180,x
	sta charbak,x
	dex
	bpl -
	lda #$35
	sta $01
	lda #$f8
	sta $d012
	lda #$0b
	sta $d011
	lda #$7f
	sta $dc0d
	lda #$01
	sta $d01a
	; check for ntsc
	ldx #$ff
-	cpx $d012
	bne -
	ldx #$10
-	cpx $d012
	bne -
	bit $d011
	bmi pal
	; patch stable raster timing
	lda #$ea
	sta ntsc
	lda #$24
	sta ntsc2
	sta ntsc3
	lda #0
	sta ntsc4+1
pal	lda #bgcol
	sta $d020
	sta $d021
	lda #showcharset
	sta $d018
	lda #$c8
	sta $d016
	lda #$03
	sta $dd00
	ldx #0
	stx $d418
	stx curpage
	stx sinusp
	stx $d017
	stx $d01b
	stx $d01d
	dex
	stx $d015
	lda #spritecol1
	sta $d025
	lda #spritecol2
	sta $d026
	; print number of pages in infopanel
	lda spriteptr+7
	jsr getptr
	ora #40
	sta ptr1+0
	lda #pages
	jsr bintodec
	pha
	txa
	jsr printdigit
	pla
	inc ptr1+0
	jsr printdigit
	; calculate rest of sinus table
	ldx #$3f
	ldy #0
-	; generate upper half of table
	lda sinus,x
	eor #$ff
	clc
	adc #$bb
	sta sinus+64,y
	iny
	dex
	bpl -
	; generate right half of table
	inx
	ldy #$ff
-	lda sinus,x
	sta sinus,y
	dey
	inx
	bpl -
	; view first page
	jsr viewpage
	cli
main	; flip to previous page
	lda prevpage
	beq +
	dec prevpage
	ldx curpage
	beq +
	dec curpage
	jsr viewpage
+	; flip to next page
	lda nextpage
	beq +
	dec nextpage
	ldx curpage
	cpx #pages-1
	beq +
	inc curpage
	jsr viewpage

+	jmp main
	; fire in port 2 or run/stop: quit
	; uncomment if we want to link
;+	lda $dc00
;	and #$10
;	beq quit
;	lda $dc01
;	and #$80
;	bne main
;quit	sei
;	; clean up everything
;	ldx #0
;	stx $d015
;-	lda #0
;	sta $d800,x
;	sta $d900,x
;	sta $da00,x
;	sta $db00,x
;	lda #32
;	sta $0400,x
;	sta $0500,x
;	sta $0600,x
;	sta $06e8,x
;	inx
;	bne -
;	dex
;	lda #$1b
;	sta $d011
	; turn off raster irq
	; TODO check if this is actually correct
;	stx $dc0d
;	inx
;	stx $d01a
;	jmp link

	; irq1: open upper+lower border
irq1	pha
	tya
	pha
	txa
	pha
	ldx #$13
	stx $d011
	dex
	stx $d012
	ldx #<irq2
	ldy #>irq2
irqend	stx $fffe
	sty $ffff
	asl $d019
	lda $dc0d
	pla
	tax
	pla
	tay
	pla
	rti

	; irq2: second part of border opening, prepare msi sprites
irq2	pha
	tya
	pha
	txa
	pha
	ldx #$1b
	stx $d011
	stx $d012
	ldx #<irq3
	ldy #>irq3
	stx $fffe
	sty $ffff
	; msi sprites
	lda #$1c
	jsr spritey
	stx $d01c
	ldx #7
	stx temp
-	lda msiptr,x
	sta $07f8,x
	lda #spritecol
	sta $d027,x
	dex
	bpl -
	; get x-coordinate from sinus table
	ldx sinusp
	lda sinus,x
	inc sinusp
	jsr spritex
	; subtract 8 if sprite 0 has x-coordinate below 0,
	; since $1f7 is the position before 0 (but only on pal!)
	lda $d000
	cmp #$f8
	bcc +
ntsc4	sbc #$08
	sta $d000
+	; prepare for double-irq
	asl $d019
	lda $dc0d
	cli
nops	nop ; the double-irq will happen during these nops, and this will
	nop ; cause the jitter to be at most 1
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	; the code should never execute this far. there are probably a couple
	; of nops too many anyway
	jmp nops

	; calculate memory address in vic bank 3 for sprite pointer (given in A)
getptr	sta ptr1+1
	lda #0
	lsr ptr1+1
	ror
	lsr ptr1+1
	ror
	sta ptr1+0
	rts

	; set y-coordinate for all sprites, given in A
	; the code depends in x being $ff after this routine returns
spritey	ldx #$0f
-	sta $d000,x
	dex
	dex
	bpl -
	rts

	; prints the char given in A to sprite pointed to by ptr1
printchar sta addr+1
	lda #0
	asl addr+1
	rol
	asl addr+1
	rol
	asl addr+1
	rol
	ora #$d8
	sta addr+2
print2	ldx #7
	ldy #21
addr	lda $bdbd,x
	sta (ptr1),y
	dey
	dey
	dey
	dex
	bpl addr
rts1	rts

	; prints the digit given in A (0-indexed) to sprite pointed to by ptr1
printdigit
	asl
	asl
	asl
	adc #<charbak ; a is small, no clc needed
	sta addr+1
	lda #0
	adc #>charbak
	sta addr+2
	bne print2

	; convert value in A to decimal
	; return tens digit in x, ones digit in A
bintodec ldx #0
-	cmp #10
	bcc rts1 ; jump to a nearby rts
	sbc #10
	inx
	bne - ; branch always happens

viewpage
	; update screen without showing too much garbage or artifacts
	; 1. black out chars
	; 2. update screen
	; 3. update colours
	lda #bgcol
	ldx #0
-	sta $d800,x
	inx
	bne -
-	sta $d900,x
	inx
	bne -
-	sta $da00,x
	inx
	bne -
	; the following is faster than adding cpx #$e8, plus it saves 2 bytes
-	sta $db00,x
	inx
	bne -
	; unpack screen
	ldx curpage
	ldy screenptrhi,x
	lda screenptrlo,x
	tax
	lda #>screen
	jsr unpack
	; update page counter
	lda spriteptr+6
	jsr getptr
	ora #40
	sta ptr1+0
	ldx curpage
	inx
	txa
	jsr bintodec
	pha
	txa
	jsr printdigit
	inc ptr1+0
	pla
	jsr printdigit
	; unpack colours
	ldx curpage
	ldy colourptrhi,x
	lda colourptrlo,x
	tax
	lda #$d8
	; "call" unpack by letting the code execute into it

	; rle decompression!
	; read bytes and interpret them as follows:
	; read first byte (value v)
	; if v=0: we're read all values, exit
	; if v is positive (<$80): then read next byte and write it v+1 times
	; if v is negative (>$7f): let w=(v xor 255)+1 (so $ff becomes $1).
	; then read the next w bytes and write them as is
unpack	stx ptr1+0   ; unpack from (ptr1)
	sty ptr1+1
	sta ptr2+1   ; unpack to (ptr2)
	ldy #0
	sty ptr2+0
unloop	lda (ptr1),y
	beq done     ; 0: we're done. jump to a nearby rts
	bmi notpack
	; positive value v: next byte is repeated v+1 times
	tax
	iny
	lda (ptr1),y ; read byte to be repeated
	dey
-	sta (ptr2),y
	inc ptr2+0
	bne +
	inc ptr2+1
+	dex
	bpl -
	inx
	lda #2
	bne incptr
notpack	; negative value v: copy the next (v xor 255)+1 bytes
	; (we're not actually xor-ing, but that is what happens)
	tax
	inc ptr1+0
	bne +
	inc ptr1+1
+
-	lda (ptr1),y
	sta (ptr2),y
	iny
	inx
	bne -
	ldx #2
-	tya
incptr	clc
	adc ptr1+0,x
	sta ptr1+0,x
	bcc +
	inc ptr1+1,x
+	dex
	dex
	bpl -
	ldy #0
	beq unloop

	; set x-coordinates for 8 sprites, including d010
	; input: a = x-coordinate of first sprite, 0-231 used as normal,
	; 232-255 is to the left of 0
	; temp must be set to 7 (or any value such that d010+temp=0) beforehand
spritex	
	ldy #2
	sta $d000
-	clc
	adc #24
	sta $d000,y
	bcc +
	; store index where x passes 255, use for lookup in d010 table
	sty temp
+	iny
	iny
	cpy #$10
	bne -
	; here, temp=2 is interpreted as sprite 0 being to the left of x=0
	ldx temp
	lda d010,x
	sta $d010
	; fixing x-coordinates between $1f8-$01ff on pal is the responsibility
	; of the caller (see example in irq2)
done	rts

	; 2 lines with 24 chars each
infobar !scr "CBM:  prev              "
	!scr "SPACE:next           /  "

	; infobar with exit
;infobar !scr "CBM:prev      SPACE:next"
;	!scr "RUN/STOP:exit        /  "

spriteptr !byte 4,5,6,8,11,13,14,15        ; pointers to the bottom sprites with text
msiptr	!byte 33,34,35,36,37,38,39,40 ; pointers to megastyle sprites
	; d010 table uses only indexes 2 4 6 7 8 10 12 14, adresses in-between
	; are used for other things
d010_2	!byte 1   ; d010 table entry
d010 = d010_2-2
prevpage !byte 0  ; 1=trigger for previous page
	!byte $fc ; d010 table entry
nextpage !byte 0  ; 1=trigger for next page
	!byte $f8,0,$f0 ; d010 table entries (the middle 0 is used)
olddc00	!byte 255 ; previous value of $dc00, used to detect change
	!byte $e0 ; d010 table entry
olddc01	!byte 255 ; previous value of $dc01
	!byte $c0 ; d010 table entry
	!byte 0   ; unused memory
	!byte $80 ; d010 table entry
	; 187: highest x-coordinate that doesn't cause glitch on sprite lines
	; -1 and 20 on the far right
prevpage = d010+3 ; 1: view prev page
nextpage = d010+5 ; 1: view next page
olddc00 = d010+9
olddc01 = d010+11

	; sinus from -1 to 188 (exclusive)
sinus	!hex ff ff ff ff  ff ff 00 00  00 01 01 02  03 03 04 05
	!hex 06 07 08 09  0a 0b 0c 0d  0e 10 11 13  14 15 17 19
	!hex 1a 1c 1e 1f  21 23 25 27  28 2a 2c 2e  30 33 35 37
	!hex 39 3b 3d 3f  42 44 46 48  4b 4d 4f 51  54 56 58 5b
	!fill $c0,0 ; allocate space for the rest of the sinus table
charbak	!fill 80,0 ; copy of digits from rom charset

; pages (converted by pageconv.c from petscii editor)
screenptrlo !byte <screen1,<screen2
screenptrhi !byte >screen1,>screen2
colourptrlo !byte <col1,<col2
colourptrhi !byte >col1,>col2
screen1 !hex fe f0 ee 23 20 fc f0 ee ed fd 23 77 fd ed fd 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 06 20 ee 10 05 14 13 03 09 09 20 04 0f 03 20 16 09 05 17 05 12 0b 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 0c 20 ef 13 08 0f 04 04 19 20 14 05 13 14 20 09 0d 01 07 05 06 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fd 6a 20 6a 24 20 fc 6a 20 f0 ee 23 20 fc f0 ee ed fd 23 77 fe ed fd 00
col1	!hex 29 07 23 09 fe 07 07 57 09 07 01 03 05 11 0a 7f 09 7f 09 7f 09 47 09 f0 06 0e 03 01 03 0e 0e 09 02 08 0a 0a 01 07 0a 08 07 02 7f 09 71 09 29 07 23 09 fe 07 07 00
screen2 !hex 7f a0 52 a0 f3 01 0e 0f 14 08 05 12 a0 a0 10 01 07 05 7f a0 7f a0 7f a0 7f a0 44 a0 f9 d4 85 93 94 89 8e 87 7f a0 3b a0 00
col2	!hex 7f 0b 52 0b 06 05 fe 0b 0b 03 04 7f 0b 7f 0b 7f 0b 7f 0b 44 0b f9 01 02 03 04 05 06 07 7f 0b 3b 0b 00

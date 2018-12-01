; demo routine example - tech-tech (a.k.a. waving with more than 8 pixels)
; change the x-coordinate on char graphics on every rasterline by more than 8
; pixels
;
; the trick: we can't change the screen map on every rasterline (the change only
; happen at badlines), so we change the char definition instead.
;
; setup: reserve 6 lines of text on the screen. set the car values to 0, 1, 2,
; 3, ..., 239. render our example logo to 7 charsets, where each subsequent copy ; of the charset is displaced one char to the right (7 charsets is the most we
; can have in one bank while also having screen memory)
;
; limitation: since we can't change the screen memory content for each
; rasterline, we can't do that for colour memory either. it pretty much has
; to be static. also, all the charsets take up a lot of memory
;
; this program is pal only

screen	= $4000
charset	= $4800 ; 7 charsets are stored starting from this address
romchar = $d800 ; $d000 = upper case, $d800 = lower case
bank	= 2
colour	= 14

	; zeropage variables

zp1	= $fe
zp2	= $fc
sinuspos = $fb

	!to "techtech.prg",cbm
	* = $0801
	; sys start (must be < 10000)
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

d018	= $d018
d016	= $d016

	; the irq is placed here to avoid page crossing in the critical loop
	; warning, messy routine with precise timimg
irq1	nop
	nop
	ldy #7
	sty zp1
	dey
	sty zp2
	ldx #0
tloop	lda d016tab,x  ;5 ;badline: spend 23 cycles
	ldy d018tab,x  ;5
	sty d018       ;4
	sta d016       ;4
	inx            ;2
	bit $ea        ;3 = 23

tloop2	lda d016tab,x  ;5 =5 ;regular line: spend 63 cycles
	ldy d018tab,x  ;5 =10
	sty d018       ;4 =14
	sta d016       ;4 =18
	inx            ;2 =20
	dec zp1        ;3 =23
	beq +          ;2 =25
	ldy #6         ;2 =27
-	dey            ;5*5-1 = 29 =56
	bne -
	nop            ;2 =58
	nop            ;2 =60
	beq tloop2     ;3 =63
+	lda #7         ;2 =28 (+1 from branch taken)
	sta zp1        ;3 =31
	ldy #4         ;2 =33
-	dey            ;5*4-1 = 19 =52
	bne -
	nop            ;2 =54
	dec zp2        ;3 =57
	bne tloop      ;3 =60 ;for some reason 3 cycles disappear here

	; next irq
	ldx #<irq2
	ldy #>irq2
	stx $0314
	sty $0315
	lda #$c1
	sta $d012
	lda #$1b
	sta $d011
	asl $d019
	jmp $ea7e

start	sei
	; clear the entire bank ($4000-$7fff)
	lda #0
	ldy #>screen
	sta zp1+0
	sty zp1+1
	ldx #$40
	tay
-	sta (zp1),y
	iny
	bne -
	inc zp1+1
	dex
	bne -
	; set up the screen: the 240 first chars (topmost 6 rows) get values
	; from 0 to 239, the rest is filled with 240 (space)
	ldx #0
-	txa
	sta screen,x
	inx
	bne -
	lda #240
	ldx #0
-	sta screen+240,x
	sta screen+240+256,x
	sta screen+240+512,x
	inx
	bne -
	; create a "bitmap" of the logo inside a charset.
	; read from zp1 (points to charset rom), write to zp2
	lda #$33
	sta $01
	ldx #0
	lda #>charset
	stx zp2+0
	sta zp2+1
	; read x-th char of the logo and write the char definition to the x-th
	; char in the charset
charloop lda logo,x
	sta zp1+0
	lda #0
	asl zp1+0
	rol
	asl zp1+0
	rol
	asl zp1+0
	rol
	ora #>romchar
	sta zp1+1
	; do the actual copy
	ldy #7
-	lda (zp1),y
	sta (zp2),y
	dey
	bpl -
	lda zp2+0
	clc
	adc #8
	sta zp2+0
	bcc +
	inc zp2+1
+	inx
	cpx #240
	bne charloop
	; create displaced copies of the charset we just created
	; begin by copying 8 blocks from $47f8-$4ff7 to $5000-$57ff, then
	; copy $4ff8-$57f7 to $5800-$5fff and so on until we filled 7 charsets.
	; we read from 8 bytes before the actual start so we can copy exactly
	; 8 blocks which makes the implementation easier
	ldx #<(charset-8) ; take char address minus 8
	ldy #>(charset-8)
	stx zp1+0
	sty zp1+1
	ldx #0
	ldy #(>charset)+8 ; add 8 to high byte of charset address
	stx zp2+0
	sty zp2+1
	ldy #0
	ldx #$38
-	lda (zp1),y
	sta (zp2),y
	iny
	bne -
	inc zp1+1
	inc zp2+1
	dex
	bne -

	; memory setup done, set up irq
	lda #$37
	sta $01
	lda #$7f
	sta $dc0d
	ldx #<irq2
	ldy #>irq2
	stx $0314
	sty $0315
	lda #$c1
	sta $d012
	lda #$1b
	sta $d011
	lda #$01
	sta $d01a
	lda #bank
	sta $dd00
	ldx #0
	stx sinuspos
	stx $d020
	stx $d021
	lda #colour
-	sta $d800,x
	sta $d900,x
	sta $da00,x
	sta $db00,x
	inx
	bne -

	cli
loop2 jmp loop2

irq2	; prepare tables
	ldx #0
	ldy sinuspos
sinloop	; use lower 3 bits of sinus to set x-scroll in $d016
	lda sinus,y
	and #7
	ora #$c0
	sta d016tab,x
	; use the next 3 bits to choose charset
	; so xx000xxx => 02
	;    xx001xxx => 04
	;    ...
	;    xx110xxx => 0e
	lda sinus,y
	lsr
	lsr
	lsr
	asl
	adc #2
	sta d018tab,x
	iny
	cpy #sinusend-sinus
	bne +
	ldy #0
+	inx
	cpx #48
	bne sinloop
	; increase sinus pointer
	ldy sinuspos
	iny
	cpy #sinusend-sinus
	bne +
	ldy #0
+	sty sinuspos
	; next irq

	lda #$32
	sta $d012
	lda #$1b
	sta $d011
	ldx #<irq1
	ldy #>irq1
	stx $0314
	sty $0315
	asl $d019
	jmp $ea7e

sinus	!hex 00 00 00 00 01 01 02 03 04 05 06 07 08 0a 0b 0c 0e 0f 11 13
	!hex 14 16 18 1a 1b 1b 1d 1f 21 22 24 26 27 29 2a 2c 2d 2e 30 31 32
	!hex 33 34 35 35 36 36 37 37 37 37 37 37 37 36 36 35 35 34 33 32 
	!hex 31 30 2f 2d 2c 2a 29 27 26 24 22 21 1f 1d 1b 1a 18 16 15 13
	!hex 11 10 0e 0c 0b 0a 08 07 06 05 04 03 02 01 01 00 00 00
sinusend

logo	!byte 32,112,64,114,64,110,32,112,64,64,64,110,32,112,64,114,64,110,32,65,32,19,9,13,16,12,5,32,32,32,32,32,32,32,32,32,32,32,32,32,32
	!byte 93,32,93,32,93,32,93,32,32,32,125,32,32,32,93,32,32,32,4,5,13,15,14,19,20,18,1,20,9,15,14,32,32,32,32,32,32,32,32,32
	!byte 93,32,93,32,93,32,109,64,64,64,110,32,32,32,93,32,32,32,15,6,32,20,5,3,8,45,20,5,3,8,32,32,32,32,32,32,32,32,32,32
	!byte 93,32,32,32,93,32,32,32,32,32,93,32,32,32,93,32,32,32,40,1,14,4,32,73,32,3,1,14,39,20,32,32,32,32,32,32,32,32,32,32
	!byte 93,32,32,32,93,32,112,110,32,32,93,32,32,32,93,32,32,32,7,18,1,16,8,9,3,19,41,32,32,32,32,32,32,32,32,32,32,32,32,32
	!byte 125,32,32,32,109,32,109,64,64,64,125,32,109,64,113,64,125,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
theend

; find next address starting on the beginning of a page
; and put some tables there
; each table holds the value to be written to d016 and d018 for each rasterline
d016tab	= (theend+255)/256*256
d018tab	= d016tab+48

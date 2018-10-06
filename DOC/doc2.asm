; petscii doc viewer with colours and scrolling
; ntsc-compatible version with 1 row less in both pal and ntsc (for equality)
; extremely link-unfriendly because it eats memory
; 0800-0fff: blank charset
; 1000-11ff: code
; 1200-61ff: text
; 6200-90e0: generated unrolled scroll routine
; 9100-fff9 is free

textlength    = 98    ; number of lines with text

bordercol     = 0
backgroundcol = 0
maxspeed      = 8 ; pixels per frame

showscreen    = $0428 ; skip 1 line, changed $0400 to $0428
showcharset   = $14   ; d018 value. 14=upper case, 16=lower case

scroll = $6200      ; location of scroll routine

; zeropage addresses. the following addresses are safe as long as we don't
; use kernal floating point routines

screenat = $61      ; fine position in text (2 bytes)
inertia  = $63      ; scrolling inertia

temp1 = $64
temp2 = $65
temp3 = $66 ; (2 bytes)
temp4 = $68 ; (2 bytes)
temp5 = $6a ; (2 bytes)

maxpos  = (textlength-23)*8 ; skip 1 line, changed -24 to -23

	!to "doc2.prg",cbm
	* = $0801
	; sys start (must be < 10000)
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	* = $1000
start	sei
;	jsr garbage
	; set up irq
	ldx #<nmi
	ldy #>nmi
	stx $fffa
	sty $fffb
	ldx #<irq
	ldy #>irq
	stx $fffe
	sty $ffff
	lda #$3e
	sta $d012
	lda #$0b
	sta $d011
	lda #$7f
	sta $dc0d
	lda #$01
	sta $d01a

	lda #$35
	sta $01
	lda #bordercol
	sta $d020
	lda #backgroundcol
	sta $d021
	lda #showcharset
	sta $d018
	lda #$c8
	sta $d016
	lda #$03
	sta $dd00
	ldx #0
	stx $d418
	stx $d015
	stx screenat+0
	stx screenat+1
	stx inertia
	; create blank charset
	; ensure in other ways that 0900-0fff is zeroed
	txa
-	sta $0800,x
	inx
	bne -
	jsr generate

	; view
loop	lda #$f7
-	cmp $d012
	bne -
	cli
	lda screenat
	and #$07
	eor #$07
	ora #$10
	sta $d011
	lda #$12 ; empty charset
	sta $d018

	; extract offset to correct text row from fine pos (divide by 8)
	; and send it as x to the huge routine
	lda screenat+1
	sta temp1
	lda screenat+0
	lsr temp1
	ror
	lsr temp1
	ror
	lsr temp1
	ror
	tax
;	dec $d020
	jsr scroll
;	inc $d020

	; movement:
	; c= up, space down
	; or joystick in port 2
	ldy inertia
	ldx $dc01
	txa
	and #$10
	beq down
	txa
	and #$20
	beq up
	ldx $dc00     
	txa
	and #$01
	bne +
	; up: decrease inertia down to -maxspeed
up	cpy #256-maxspeed
	beq pos
	dey
	jmp pos
+	txa
	and #$02
	bne decay
	; down: increase inertia up to maxspeed
down	cpy #maxspeed
	beq pos
	iny
	jmp pos
decay	; no movement, decay inertia
	cpy #0
	beq pos
	bmi +
	dey
	jmp pos
+	iny
pos	; process inertia
	sty inertia
	tya
	beq done     ; inertia=0, don't do anything
	bpl downfix

	; apply upward inertia to screen pos
	clc
	adc screenat+0
	sta screenat+0
	bcs +
	dec screenat+1
	bpl +
	; if we went into negative we scrolled past the top position.
	; set to 0
	lda #0
	sta screenat+0
	sta screenat+1
	sta inertia
+
	jmp done

downfix	; apply downward inertia to screen pos
	clc
	adc screenat+0
	sta screenat+0
	bcc +
	inc screenat+1
+	lda screenat+0
	cmp #<maxpos
	lda screenat+1
	sbc #>maxpos
	bcc +
	; we went past the end, crop to actual end
	lda #<maxpos
	sta screenat+0
	lda #>maxpos
	sta screenat+1
	lda #0
	sta inertia
+
done	jmp loop

irq	pha
	txa
	pha
	; timing
	ldx #6
-	dex
	bne -
	nop
	lda #showcharset
	sta $d018
	asl $d019
	lda $dc0d
	pla
	tax
	pla
nmi	rti

	; fill text storage with garbage to test routine
	; disable this when we have actual text
;garbage
;	ldx #0
;	ldy #>textstart
;	stx temp3+0
;	sty temp3+1
;	ldy #$a0
;	stx temp4+0
;	sty temp4+1
	; copy 32 pages from basic rom to textstart
;	ldx #$20
;	jsr copy
;	ldy #$e0
;	sty temp4+1
	; copy 32 pages from kernal to end of previous stuff
;	ldx #$20
;	jsr copy
;	ldy #$a0
;	sty temp4+1
;	ldx #$10
	; copy 16 more pages from basic rom
;copy	ldy #0
;-	lda (temp4),y
;	sta (temp3),y
;	iny
;	bne -
;	inc temp4+1
;	inc temp3+1
;	dex
;	bne -
;	rts

generate
	; generate unrolled loop for scroll routine. full unroll is required
	; to update entire screen within a frame.
	; each column of text has its own page in memory + one more page for
	; colour data. the start of each column must be page-aligned to
	; avoid crossing page boundaries
	; memory layout:
	; page 0: chars for column 0 
	; page 1: colours for column 0
	; page 2: chars for column 1
	; page 3: colours for column 1
	; ...
	; page 78: chars for column 39
	; page 79: colours for column 39
	;
	; code for rendering one char:
	;   lda page0,x
	;   sta $0400
	;   lda page1,x
	;   sta $d800
	;
	; addressing for the char below (example):
	;   lda page0+1,x
	;   sta $0428
	;   lda page1+1,x
	;   sta $d828
	;
	; hardcoding the address page0+1 for the second line is faster than
	; doing inx 24 times, that's almost one raster line which is a
	; significant portion of the remaining raster time. inx is pointless
	; since we can't loop anyway, because all screen coordinates are
	; hardcoded (and they are indexed in a different way anyway)

	lda #0           ; loop over each row
	sta temp1
	ldx #<showscreen ; set pointer to screen mem
	ldy #>showscreen
	stx temp3+0
	sty temp3+1
	ldx #$28         ; set pointer to colour mem
	ldy #$d8         ; skip 1 line, set to $d828
	stx temp4+0
	sty temp4+1
	ldx #<scroll     ; start of routine in mem
	ldy #>scroll
	stx temp5+0
	sty temp5+1
	ldy #0           ; set y to 0, never touch it outside jsr gen

	; do one row
genloop2 ldx #0           ; loop over each column 0-39

	; generate code for a single char + its colour
genloop	lda #$bd         ; insert lda $xxxx,x (char from text storage)
	jsr gen
	lda temp1        ; low byte: screeny
	jsr gen
	txa              ; high byte: correct page = screenx*2
	asl              ; clc not needed, a is always <40, so c always becomes 0
	adc #>textstart
	jsr gen
	lda #$8d         ; insert sta screenmem
	jsr gen
	lda temp3+0
	jsr gen
	lda temp3+1
	jsr gen
	inc temp3+0
	bne +
	inc temp3+1
+
	lda #$bd         ; insert lda $xxxx,x (colour from text storage)
	jsr gen
	lda temp1        ; low byte: screeny
	jsr gen
	txa              ; high byte: correct page = screenx*2+1
	asl
	sec              ; this adds 1
	adc #>textstart
	jsr gen
	lda #$8d         ; insert sta colourmem
	jsr gen
	lda temp4+0
	jsr gen
	lda temp4+1
	jsr gen
	inc temp4+0
	bne +
	inc temp4+1
+
	inx
	cpx #$28
	bne genloop
	ldx temp1
	inx
	stx temp1
	cpx #24          ; skip 1 row, so 24 instead of 25
	bne genloop2
	lda #$60         ; finally, insert rts
	; no need for jsr gen, the routine is here
gen	sta (temp5),y
	iny
	bne +
	inc temp5+1
+	rts

endcode

; text starts at beginning of next page
textstart = (endcode+255)/256*256
;textstart = $2800

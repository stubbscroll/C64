; solution to project euler #16
; https://projecteuler.net/problem=16
; algorithm: start from 1 and double it 1000 times with addition. grow the
; answer array as we go to save around half the runtime

	CHROUT = $ffd2

	!to "016.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

len = $ff

start	sei
	ldx #0
	stx cnt+0  ; set counter to 0
	stx cnt+1
	inx
	stx len    ; current answer length: 1 byte
	stx answer ; set answer=1 (only first byte)
loop	; double
	ldy len
	ldx #0
	sed
	clc
-	lda answer,x
	adc answer,x
	sta answer,x
	inx
	dey
	bne -
	cld
	bcc +
	; carry=1, grow answer by 1 byte
	lda #1
	sta answer,x
	inc len
+	; advance counter
	inc cnt+0
	bne +
	inc cnt+1
+	; is count=1000?
	lda cnt+0
	cmp #<1000
	bne loop
	lda cnt+1
	cmp #>1000
	bne loop
	; done, calculate digit sum
	lda #0
	sta cnt+0 ;repurpose counter as digit sum
	sta cnt+1
	ldx #0
loop2	lda answer,x
	lsr
	lsr
	lsr
	lsr
	sta temp
	lda answer,x
	and #$0f
	sed
	clc
	adc temp
	adc cnt+0
	sta cnt+0
	lda cnt+1
	adc #0
	sta cnt+1
	cld
	inx
	cpx len
	bne loop2
	; display digit sum
	ldx #<cnt
	ldy #>cnt
	lda #2
	jsr printbcd
	lda #$0d
	jmp CHROUT

; print bcd number to CHROUT, don't output leading zeroes
; x,y: address of number
; a: length of number (in bytes)
; clobbered: a,x,y
printbcd stx bcdval+1
	sty bcdval+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
-
bcdval	lda $0000,x
	pha
	lsr
	lsr
	lsr
	lsr
	jsr printchar
	pla
	and #$0f
	jsr printchar
	dex
	cpx #$ff
	bne -
	cpy #0
	beq + ; y still 0: print 0
-	rts
printchar cpy #0
	bne +
	cmp #0
	beq -
	ldy #1 ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT

temp	!byte 0
cnt	!byte 0,0
answer	; don't actally need to store 200 empty bytes in the executable

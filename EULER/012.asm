; solution to project euler #12
; https://projecteuler.net/problem=12
; algorithm: loop through each triangle number in increasing order, perform
; trial division to get all prime factors and use it to calculate the number
; of divisors. terminate when we found one with >500 divisors.
; optimizations: use that a triangle number is of the form n*(n+1)/2 and factor
; n and n+1 separately, and afterwards merge the lists of exponents. also reuse
; the factorization of n+1 as n for the next term.
; runtime: 3 minutes 59 seconds

	CHROUT = $ffd2

	!to "012.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; multiply two unsigned 16-bit integers and get 32-bit product
; input: mul1, mul2 (2 bytes each)
; output: product (4 bytes)
; clobbered: a,x,mul1
; better performance is achieved by ensuring that mul1 has fewer bits set than
; mul2
; taken from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

	mul1 = $f8    ; 2 bytes
	mul2 = $fa    ; 2 bytes
	product = $fc ; 4 bytes

mul16	lda #0
	sta product+2 ; clear upper bits of product
	sta product+3
	ldx #16       ; set binary count to 16
-	lsr mul1+1    ; divide multiplier by 2
	ror mul1+0
	bcc +
	lda product+2 ; get upper half of product and add multiplicand
	clc
	adc mul2+0
	sta product+2
	lda product+3
	adc mul2+1
+	ror           ; rotate partial product
	sta product+3
	ror product+2
	ror product+1
	ror product+0
	dex
	bne -
	rts

; calculate quotient and remainder of division for unsigned 24-bit ints
; (divide "dividend" by "divisor")
; inputs: dividend, divisor (2 bytes)
; outputs: dividend (=quotient), remainder (2 bytes each)
; clobbered: a,x,y,dividend
; taken from http://codebase64.org/doku.php?id=base:16bit_division_16-bit_result

divisor = $fa     ; 2 bytes
dividend = $fc	  ; 2 bytes. reused for quotient
remainder = $fe	  ; 2 bytes

div16	lda #0	        ;preset remainder to 0
	sta remainder
	sta remainder+1
	ldx #16	        ;repeat for each bit: ...

-	asl dividend	;dividend lb & hb*2, msb -> Carry
	rol dividend+1	
	rol remainder	;remainder lb & hb * 2 + msb from carry
	rol remainder+1
	lda remainder
	sec
	sbc divisor	;substract divisor to see if it fits in
	tay	        ;lb result -> Y, for we may need it later
	lda remainder+1
	sbc divisor+1
	bcc +	;if carry=0 then divisor didn't fit in yet

	sta remainder+1	;else save substraction result as new remainder,
	sty remainder	
	inc dividend ;and INCrement result cause divisor fit in 1 times

+	dex
	bne -
	rts

; factor an unsigned 16-bit integer using trial division
; input: x,y integer (x+y*256)
; output: factoro (list of prime factors, 2 bytes each)
; output: factorn (number of items in list*2)
; clobbered: a,x,y

factor16 stx fn+0 ; fn = remaining part of number to factor
	sty fn+1
	; cast out multiples of 2 first
	txa
	ldy #0
	and #1
	bne done2 ; skip it all if there aren't any
	ldx #0
cast2	lda fn+0
	and #1
	bne write2
	lsr fn+1
	ror fn+0
	inx
	bne cast2
	; write the twos to the array
write2	
-	lda #2
	sta factoro,y
	lda #0
	sta factoro+1,y
	iny
	iny
	dex
	bne -
done2	sty factorn
	lda #3
	sta i+0
	lda #0
	sta i+1
	; starting with 3, divide by odd numbers in increasing order
dloop	ldx fn+0
	ldy fn+1
	stx dividend+0
	sty dividend+1
	ldx i+0
	ldy i+1
	stx divisor+0
	sty divisor+1
	jsr div16
	; if remainder=0, we found a prime factor
	lda remainder+0
	ora remainder+1
	bne +
	; reduce fn by factor
	ldx dividend+0
	ldy dividend+1
	stx fn+0
	sty fn+1
	; store factor in list
	ldx factorn
	lda i+0
	sta factoro,x
	inx
	lda i+1
	sta factoro,x
	inx
	stx factorn
	bne dloop ; divide again with same factor
+	; if i>result, terminate
	lda i+0
	cmp dividend+0
	lda i+1
	sbc dividend+1
	bcc +++
	; we're done! add fn to list if it's larger than 1
	lda fn+0
	cmp #1
	bne +
	ldy fn+1
	beq ++
+	ldx factorn
	sta factoro,x
	inx
	lda fn+1
	sta factoro,x
	inx
	stx factorn
++	rts
+++	; next odd number
	lda i+0
	clc
	adc #2
	sta i+0
	bcc dloop
	inc i+1
	bne dloop

i	!byte 0,0 ; divisor
fn	!byte 0,0
factoro	!fill 32,0
factorn	!byte 0

; convert unsigned 32-bit int to 40-bit (10-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int32tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	stx outbcd+3
	stx outbcd+4
	ldx #31
	sed
-	asl inbcd+0
	rol inbcd+1
	rol inbcd+2
	rol inbcd+3
	lda outbcd+0
	adc outbcd+0
	sta outbcd+0
	lda outbcd+1
	adc outbcd+1
	sta outbcd+1
	lda outbcd+2
	adc outbcd+2
	sta outbcd+2
	lda outbcd+3
	adc outbcd+3
	sta outbcd+3
	lda outbcd+4
	adc outbcd+4
	sta outbcd+4
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0,0,0
outbcd	!byte 0,0,0,0,0

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
	bpl -
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

; variables for main program

divs	!byte 0,0 ; number of divisors
n	!byte 0,0 ; for a given n (or actually n+1), the current triangle number is n*(n+1)/2
	; lists end with $ff,$ff
list1	!fill 34,0 ; room for 16 prime factors of n, enough for 2^16=65536
list2	!fill 34,0 ; prime factors for n+1
mlist	!fill 66,0 ; merged list

	; subroutine for merging lists
	; self-modifying code because i ran out of registers
madd	sta $ffff
	inc madd+1
	bne +
	inc madd+2
+	rts

start	sei
	ldx #2  ; set n=2
	stx n+0
	ldx #0
	stx n+1
	; add sentinel to end of list1, making it have length 0
	dex
	stx list1+0
	stx list1+1
	; list 1 is empty, which is equivalent to the factorization of 1.

loop	; factor n. assume that the factorization of n was done in the
	; last iteration of the loop and is placed in list1
	ldx n+0
	ldy n+1
	jsr factor16
	; copy to list2
	ldx #0
-	lda factoro,x
	sta list2,x
	inx
	cpx factorn
	bne -
	; add sentinel
	lda #$ff
	sta list2+0,x
	sta list2+1,x
	; merge lists
	; merging is actually not necessary. n and n+1 don't have
	; any common prime factors...
	ldx #<mlist
	ldy #>mlist
	stx madd+1
	sty madd+2
	ldx #0
	ldy #0
mloop	; done?
	lda list1+0,x
	and list1+1,x
	and list2+0,y
	and list2+1,y
	cmp #$ff
	beq mdone ; next element in both lists=$ffff: both lists merged
	lda list1+0,x
	cmp list2+0,y
	lda list1+1,x
	sbc list2+1,y
	bcc add1
	; add next element from list2
	lda list2,y
	jsr madd
	iny
	lda list2,y
	jsr madd
	iny
	bne mloop
add1	; add next element from list1
	lda list1,x
	jsr madd
	inx
	lda list1,x
	jsr madd
	inx
	bne mloop
mdone	; write sentinel to the merged list
	jsr madd
	jsr madd
	; calculate number of divisors, init at 1
	ldx #1
	stx divs+0
	dex
	stx divs+1
	; for each unique prime factor, count multiplicity
	; skip the first factor of 2 since we need to divide by 2
	ldy #2
mloop3	ldx #2 ; multiplicity counter
mloop2	
	; end of list?
	lda mlist+0,y
	and mlist+1,y
	cmp #$ff
	beq mend
	; equal to next element in list?
	lda mlist+0,y
	cmp mlist+2,y
	bne +
	lda mlist+1,y
	cmp mlist+3,y
	bne +
	; increase multiplicity of same prime factor
	inx
	iny
	iny
	bne mloop2
+	; multiply number of divisors so far by x
	stx mul1+0
	lda #0
	sta mul1+1
	lda divs+0
	sta mul2+0
	lda divs+1
	sta mul2+1
	jsr mul16
	lda product+0
	sta divs+0
	lda product+1
	sta divs+1
	iny
	iny
	bne mloop3
mend	; try next triangular number
	; copy list2 to list1
	ldx #33
-	lda list2,x
	sta list1,x
	dex
	bpl -
	; continue looping if we didn't get more than 500 divisors
	lda #<501
	cmp divs+0
	lda #>501
	sbc divs+1
	bcc done
	inc n+0
	bne +
	inc n+1
	; lifesign
	lda #$2e
	jsr CHROUT
+	jmp loop
done	; the current answer is based on factors of n and n-1,
	; so the answer is n*(n-1)/2
	lda #$0d
	jsr CHROUT
	ldx n+0
	ldy n+1
	stx mul1+0
	sty mul1+1
	cpx #0
	bne +
	dey
+	dex
	stx mul2+0
	sty mul2+1
	jsr mul16
	; divide by 2
	lsr product+3
	ror product+2
	ror product+1
	ror product+0
	ldx #3
-	lda product,x
	sta inbcd,x
	dex
	bpl -
	jsr int32tobcd
	ldx #<outbcd
	ldy #>outbcd
	lda #4
	jsr printbcd
	lda #$0d
	jmp CHROUT

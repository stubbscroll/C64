; solution to project euler #12
; https://projecteuler.net/problem=12
; algorithm: loop through each triangle number in increasing order, perform
; trial division to get all prime factors and use it to calculate the number
; of divisors. terminate when we found one with >500 divisors.
; optimizations: use that a triangle number is of the form n*(n+1)/2 and factor
; n and n+1 separately. store the number of divisors for n+1 (divide
; the even factor by 2 first) and reuse it as n for the next number.
; this version uses that n and n+1 are relatively prime, so there's no need
; to merge exponent lists. in addition, sieving is done at the start to make a
; list of primes which is used by the trial division so it doesn't waste time by
; checking divisibility with composites.
; runtime: 1 minute 57 seconds

	CHROUT = $ffd2

	!to "012a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; multiply two unsigned 8-bit integers and get 16-bit product
; inputs: mul1, mul2
; output: product
; clobbered: a,x,mul1
; shortened from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul81 = $fe ; 1 byte
mul82 = $ff ; 1 byte
product8 = $fc ; 2 bytes

mul8	lda #0
	ldx #8
-	lsr mul81
	bcc +
	clc
	adc mul82
+	ror
	ror product8+0
	dex
	bne -
	sta product8+1
	rts

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
; inputs: dividend, divisor (2 bytes, 1 byte)
; outputs: dividend (=quotient), remainder (2 bytes, 1 byte)
; clobbered: a,x,y,dividend
; based on http://codebase64.org/doku.php?id=base:16bit_division_16-bit_result

dividend = $fd  ; 2 bytes
divisor = $fc   ; 1 byte
remainder = $ff ; 1 bytes

div16_8	lda #0
	sta remainder
	ldx #16
-	asl dividend
	rol dividend+1
	rol remainder
	lda remainder
	sec
	sbc divisor
	bcc +
	sta remainder
	inc dividend
+	dex
	bne -
	rts

; factor an unsigned 16-bit integer using trial division
; input: x,y integer (x+y*256)
; output: factoro (list of prime factors, 1 bytes each, 16-bit primes
;         are replaced with $fe, ends with $ff)
; clobbered: a,x,y

factor16 stx fn+0
	sty fn+1
	; cast out multiples of 2 first
	txa
	ldy #0
	ldx #0
	and #1
	bne done2 ; skip it all if there aren't any
cast2	lda fn+0
	and #1
	bne write2
	lsr fn+1
	ror fn+0
	inx
	bne cast2
	; write the twos to the array
write2	
	lda #2
-	sta factoro,y
	iny
	dex
	bne -
done2	sty factorn
	stx i
	; loop over odd primes in increasing order
	; (have to be precalculated)
dloop	ldx fn+0
	ldy fn+1
	stx dividend+0
	sty dividend+1
	ldx i
	lda primes,x
	sta divisor
	jsr div16_8
	; if remainder=0, we found a prime factor
	lda remainder
	bne +
	; reduce fn by factor (in other words, set fn to quotient)
	ldx dividend+0
	ldy dividend+1
	stx fn+0
	sty fn+1
	; store factor in list
	ldx factorn
	ldy i
	lda primes,y
	sta factoro,x
	inx
	stx factorn
	bne dloop ; divide again with same factor
+	; if primes[i]>result, terminate
	ldx i
	lda primes,x
	cmp dividend+0
	lda #0
	sbc dividend+1
	bcc +++
	; we're done! add fn to list if it's larger than 1
ddone	ldx factorn
	lda fn+0
	cmp #1
	bne +
	ldy fn+1
	beq ++
+	lda #$fe
	sta factoro,x
	inx
	; add sentinel
++	lda #$ff
	sta factoro,x
	rts
+++	; next prime
	ldx i
	inx
	stx i
	cpx nprimes
	bne dloop
	beq ddone

i	!byte 0 ; index to list of primes
fn	!byte 0,0 ; number to factor
factoro	!fill 17,0 ; list of prime factors
factorn !byte 0 ; pointer to factoro list (where to write next factor)

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
n	!byte 0,0 ; current n to be factored
divsold	!byte 0,0 ; number of divisors of previous number

primes = sieve+256 ; list of precalculated primes
nprimes	!byte 0 ; number of primes

start	sei
	; precalculate prime numbers below 256 with sieve
	jsr sieve256
	; create list of prime numbers from sieve, starting from 3
	ldx #3
	ldy #0
-	lda sieve,x
	beq +
	txa
	sta primes,y
	iny
+	inx
	bne -
	sty nprimes
	ldx #2 ; set n=2, set number of divisors of 1 to 1
	stx n+0
	dex
	stx divsold+0
	dex
	stx n+1
	stx divsold+1
loop	; factor n
	ldx n+0
	ldy n+1
	jsr factor16
	; calculate number of divisors, init at 1
	ldx #1
	stx divs+0
	dex
	stx divs+1
	; for each unique prime factor, count multiplicity
	; if number is even, skip first factor of 2
	ldy #0
	lda factoro
	cmp #2
	bne mloop3
	iny
mloop3	ldx #2	; multiplicity counter
mloop2	; end of list?
	lda factoro+0,y
	cmp #$ff
	beq mend
	; equal to next element in list?
	lda factoro+0,y
	cmp factoro+1,y
	bne +
	; increase multiplicity of same prime factor
	inx
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
	bne mloop3
mend	; multiply number of divisors of n with that from n-1
	ldx divs+0
	ldy divs+1
	stx mul1+0
	sty mul1+1
	ldx divsold+0
	ldy divsold+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; check if it's over 500
	lda #<501
	cmp product+0
	lda #>501
	sbc product+1
	bcc done
	; copy current number of divisors to previous
	ldx divs+0
	ldy divs+1
	stx divsold+0
	sty divsold+1
	; next triangular number
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

; calculate all primes below 256 using a lazy implementation of
; sieve of eratosthenes that uses 1 byte per bit.
; output: sieve array where sieve[p]=1 if and only if p is prime
; needs 8*8=8 bit multiplication

sieve256 ; clear sieve: first, mark 0, 1 as composites, 2, 3 as primes
	ldx #0
	stx sieve+0
	stx sieve+1
	inx
	stx sieve+2
	stx sieve+3
	; the mark the remaining even elements as composites and odd as primes
	ldx #4
-	lda #0
	sta sieve,x
	inx
	lda #1
	sta sieve,x
	inx
	bne -

	ldx #3
	stx sievei
	; find the earliest odd prime in the sieve
	; only sieve with ints <16, since higher ints are also smaller multiples
	ldx sievei
-	lda sieve,x
	bne +
--	inx
	stx sievei
	cpx #16
	bne -
	rts
+	; start at i*i, loop with step size 2i
	stx sieve2i
	stx mul81
	stx mul82
	txa
	clc
	adc sieve2i
	sta sieve2i
	jsr mul8
	ldy product8
-	lda #0
	sta sieve,y
	tya
	clc
	adc sieve2i
	tay
	bcc -
	ldx sievei
	bne --

sievei	!byte 0
sieve2i	!byte 0
theend
sieve = (theend+255)/256*256 ; put sieve on start of next page
	; in sieve: 1=prime, 0=composite

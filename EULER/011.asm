; solution to project euler #11
; https://projecteuler.net/problem=11
; algorithm: try every cell in the grid as a starting position, and try all
; directions (need only check 4). surround grid with sentinel values to
; make boundary checking easier (no need to check for off-grid coordinates)

	CHROUT = $ffd2

	!to "011.prg",cbm
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
product	!byte 0,0,0,0 ; 4 bytes

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

ptr1 = $fe
ptr2 = $fc

	; directions (offset to add to pointer)
	; E, SE, S, SW
dirs	!byte 1,23,22,21
mul10	!byte 0,10,20,30,40,50,60,70,80,90

start	sei
	; init max product to 0
	lda #0
	ldx #3
-	sta max,x
	dex
	bpl -
	; convert grid to a more code-friendly format: 1 byte per number, stored
	; as normal int. sentinel (space) becomes $ff
	; read from ptr1 (2 bytes per cell), write to ptr2 (1 byte per cell)
	ldx #<gridori
	ldy #>gridori
	stx ptr1+0
	sty ptr1+1
	ldx #<grid
	ldy #>grid
	stx ptr2+0
	sty ptr2+1
	ldy #0
iloop	lda (ptr1),y
	cmp #$20
	bne digit
	; found space, convert to $ff
	lda #$ff
	sta (ptr2),y
	bne incr
digit	; read tens digit
	lda (ptr1),y
	and #$0f
	tax
	iny
	; read ones digit
	lda (ptr1),y
	and #$0f
	; make int by multiplying tens digit with table
	clc
	adc mul10,x
	dey
	sta (ptr2),y
incr	inc ptr1+0
	inc ptr1+0
	bne +
	inc ptr1+1
+	inc ptr2+0
	bne +
	inc ptr2+1
+	lda ptr1+0
	cmp #<gridend
	bne iloop
	lda ptr1+1
	cmp #>gridend
	bne iloop
	; store new grid end
	ldx ptr2+0
	ldy ptr2+1
	stx gridend2+0
	sty gridend2+1

	; try all cells as starting position for line! start at upper left
	ldx #<grid+23 ; actual upper left, don't start on border
	ldy #>grid+23
	stx ptr1+0
	sty ptr1+1
loop2	ldy #0
	lda (ptr1),y
	bmi skip ; skip border ($ff)
	; try all directions from current cell
	lda #0
-	pha
	tax
	lda dirs,x
	sta offset
	jsr try
	pla
	clc
	adc #1
	cmp #4
	bne -
skip	inc ptr1+0
	bne +
	inc ptr1+1
+	; are we at the end?
	lda ptr1+0
	cmp gridend2+0
	bne loop2
	lda ptr1+1
	cmp gridend2+1
	bne loop2
	; output answer
	ldx #3
-	lda max,x
	sta inbcd,x
	dex
	bpl -
	jsr int32tobcd
	lda #5
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

	; make a line from given starting cell (in ptr1) and
	; direction (in offset)
try	ldx #0 ; index of cell in line
	lda ptr1+0
	sta ptr2+0
	lda ptr1+1
	sta ptr2+1

tryloop	ldy #0
	lda (ptr2),y
	cmp #$ff
	bne +
	; we hit border, terminate
	rts
+	sta cur,x
	lda ptr2+0
	clc
	adc offset
	sta ptr2+0
	bcc +
	inc ptr2+1
+	inx
	cpx #4
	bne tryloop
	; multiply the 4 numbers in the line
	; start with the 2 first ones
	ldx cur+0
	ldy cur+1
	lda #0
	stx mul1+0
	sta mul1+1
	sty mul2+0
	sta mul2+1
	jsr mul16
	ldx product+0
	ldy product+1
	stx temp+0
	sty temp+1
	; proceed with the 2 last ones
	ldx cur+2
	ldy cur+3
	lda #0
	stx mul1+0
	sta mul1+1
	sty mul2+0
	sta mul2+1
	jsr mul16
	; multiply the 2 previous products
	ldx product+0
	ldy product+1
	stx mul1+0
	sty mul1+1
	ldx temp+0
	ldy temp+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; compare with max
	ldx #3
--	lda max,x
	cmp product,x
	beq next ; equal so far, check next byte
	bcs skip2 ; smaller, skip
	; we found a larger answer, keep
	ldx #3
-	lda product,x
	sta max,x
	dex
	bpl -
	rts
next	dex
	bpl --
	; entire number is equal, skip
skip2	rts

temp	!byte 0,0
cnt	!byte 0 ; index of cell in line
offset	!byte 0 ; direction we move in
cur	!byte 0,0,0,0 ; numbers in the line
max	!byte 0,0,0,0 ; 99^4 (upper bound for answer) needs 4 bytes

gridend2 !byte 0,0 ; grid end after conversion
	; 20x20 grid of 2-digit numbers
	; sentinels (space) added as a border
	; align to even address for easier pointer increment by 2
	!align 1,0
gridori	!text "                                            "
	!text "  0802229738150040007504050778521250779108  "
	!text "  4949994017811857608717409843694804566200  "
	!text "  8149317355791429937140675388300349133665  "
	!text "  5270952304601142692468560132567137023691  "
	!text "  2231167151676389419236542240402866331380  "
	!text "  2447326099034502447533537836842035171250  "
	!text "  3298812864236710263840675954706618386470  "
	!text "  6726206802621220956394396308409166499421  "
	!text "  2455580566739926971778789683148834896372  "
	!text "  2136230975007644204535140061339734313395  "
	!text "  7817532822753167159403800462161409535692  "
	!text "  1639054296353147555888240017542436298557  "
	!text "  8656004835718907054444374460215851541758  "
	!text "  1980816805944769287392138652177704895540  "
	!text "  0452088397359916079757321626267933279866  "
	!text "  8836688757622072034633674655123263935369  "
	!text "  0442167338253911249472180846293240627636  "
	!text "  2069364172302388346299698267598574043616  "
	!text "  2073352978319001743149714886811623570554  "
	!text "  0170547183515469169233486143520189196748  "
	!text "                                            "
gridend
grid	; converted grid is stored here

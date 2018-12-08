; advent of code 2018 day 7, part 2
; https://adventofcode.com/2018/day/7
; algorithm: use the base algorithm from part 1 and add the simulation part
; runtime: 9 seconds

	CHROUT = $ffd2

	!to "07b.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	zp1 = $fc
	zp2 = $fe
	letter = $f7
	pre = $f8
	time = $fa ; 2 bytes is enough, it holds worst case of 26*(27/2+60)=1911

	WORKERS = 5  ; 2 for example, 5 for full problem
	BASETIME = 61 ; 1 for example, 61 for full problem

start	sei
	; init variables
	ldx #25
	lda #0
-	sta used,x
	dex
	bpl -
	sta time+0
	sta time+1
	jsr conv
loop2	; start of main loop
	; if we have free worker slots, try adding more
	jsr isfree
	bmi passtime
	jsr add
passtime ; simulate 1 second
	; loop through each worker
	ldx #WORKERS-1
-	lda worker,x
	bmi +
	; worker exists in slot, increase time
	inc workert,x
	clc
	adc #BASETIME
	cmp workert,x
	bne +
	; worker is finished
	ldy worker,x
	lda #255
	sta used,y
	sta worker,x
+	dex
	bpl -
	; increase time elapsed by 1 second
	inc time+0
	bne +
	inc time+1
+	; all work done?
	ldx #25
	ldy #0
-	lda used,x
	bpl +
	iny
+	dex
	bpl -
	cpy #26
	bne loop2 ; not done, go back to main loop
	; we're done, print answer
	lda time+0
	sta inbcd+0
	lda time+1
	sta inbcd+1
	jsr int16tobcd
	lda #3
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

add	; try to add a worker
	lda #0
	sta letter
loop3	; is letter used already, or in progress?
	ldx letter
	lda used,x
	bne nextl ; yes, try next letter
	; go through input and see if we can use letter
	ldx #0
	stx pre ; eventually set pre=1 if letter exists in graph
loop4	ldy input,x
	bmi endin ; end of input?
	; does letter exist?
	cpy letter
	bne +
	inc pre
+	lda input+1,x
	cmp letter ; check if edge goes to the letter we're currently trying
	bne next
	inc pre
	; check prerequisite (letter has to be finished)
	lda used,y
	bpl nextl ; not fulfilled, try next letter
next	inx
	inx
	bne loop4
	; looped through the input, letter found ok. add it to workers
endin	ldx letter
	lda #1
	sta used,x
	ldy pre
	bne +
	; letter doesn't exist, mark it as fully used
	lda #255
	sta used,x
	bne nextl
+	inc used,x
	ldy #WORKERS-1
-	lda worker,y
	bmi +
	dey
	bpl -
+	txa
	sta worker,y
	lda #0
	sta workert,y
	; more workers available?
	jsr isfree
	bmi found
nextl	ldx letter
	inx
	stx letter
	cpx #26
	bne loop3
	rts

	; find free worker slot. return index of slot, or 255 if all are taken
isfree	ldx #WORKERS-1
-	lda worker,x
	bmi found
	dex
	bpl -
found	cpx #0
	rts

	; convert input: isolate the relevant info (the graph nodes).
	; the converted input is terminated with 0xff
conv	ldx #<input
	ldy #>input
	stx zp1+0
	stx zp2+0
	sty zp1+1
	sty zp2+1
loop	ldy #0
	lda (zp1),y
	bne +
	lda #$ff
	sta (zp2),y
	rts
+	ldy #5  ; read from node
	lda (zp1),y
	sec
	sbc #'A' ; convert letter to int between 0 and 25
	ldy #0
	sta (zp2),y
	ldy #36 ; read to node
	lda (zp1),y
	sec
	sbc #'A'
	ldy #1
	sta (zp2),y
	lda zp1+0
	clc
	adc #49
	sta zp1+0
	bcc +
	inc zp1+1
+	inc zp2+0
	inc zp2+0
	bne loop
	inc zp2+1
	bne loop

; convert unsigned 16-bit int to 24-bit (6-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; stolen from http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int16tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	ldx #15
	sed
-	asl inbcd+0
	rol inbcd+1
	lda outbcd+0
	adc outbcd+0
	sta outbcd+0
	lda outbcd+1
	adc outbcd+1
	sta outbcd+1
	lda outbcd+2
	adc outbcd+2
	sta outbcd+2
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0
outbcd	!byte 0,0,0

; print bcd number to CHROUT, don't output leading zeroes
; x,y: address of number
; a: length of number (in bytes)
; clobbered: a,x,y
printbcd stx bcdval+1
	sty bcdval+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
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
	bpl bcdval
	cpy #0
	beq + ; y still 0: print 0
-	rts
printchar cpy #0
	bne +
	cmp #0
	beq -
	iny ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT

used	!fill 26,0  ; 255: letter has been used, 1:letter is in progress
worker	!fill 5,255 ; worker id (0-25), or 255 if free
workert	!fill 5,0   ; time spent

	; input file! each line is terminated with linebreak (0x0d), the file
	; is 0-terminated
	!align 1,0,0 ; align to word boundary
input	!text "Step P must be finished before step G can begin.",13
	!text "Step X must be finished before step V can begin.",13
	!text "Step H must be finished before step R can begin.",13
	!text "Step O must be finished before step W can begin.",13
	!text "Step C must be finished before step F can begin.",13
	!text "Step U must be finished before step M can begin.",13
	!text "Step E must be finished before step W can begin.",13
	!text "Step F must be finished before step J can begin.",13
	!text "Step W must be finished before step K can begin.",13
	!text "Step R must be finished before step M can begin.",13
	!text "Step I must be finished before step K can begin.",13
	!text "Step D must be finished before step B can begin.",13
	!text "Step Z must be finished before step A can begin.",13
	!text "Step A must be finished before step N can begin.",13
	!text "Step T must be finished before step J can begin.",13
	!text "Step B must be finished before step N can begin.",13
	!text "Step Y must be finished before step M can begin.",13
	!text "Step Q must be finished before step N can begin.",13
	!text "Step G must be finished before step V can begin.",13
	!text "Step J must be finished before step N can begin.",13
	!text "Step M must be finished before step V can begin.",13
	!text "Step N must be finished before step V can begin.",13
	!text "Step K must be finished before step S can begin.",13
	!text "Step V must be finished before step L can begin.",13
	!text "Step S must be finished before step L can begin.",13
	!text "Step W must be finished before step D can begin.",13
	!text "Step A must be finished before step V can begin.",13
	!text "Step T must be finished before step Y can begin.",13
	!text "Step H must be finished before step W can begin.",13
	!text "Step O must be finished before step C can begin.",13
	!text "Step P must be finished before step S can begin.",13
	!text "Step Z must be finished before step N can begin.",13
	!text "Step G must be finished before step K can begin.",13
	!text "Step I must be finished before step T can begin.",13
	!text "Step D must be finished before step M can begin.",13
	!text "Step A must be finished before step Q can begin.",13
	!text "Step O must be finished before step S can begin.",13
	!text "Step N must be finished before step L can begin.",13
	!text "Step V must be finished before step S can begin.",13
	!text "Step M must be finished before step N can begin.",13
	!text "Step A must be finished before step B can begin.",13
	!text "Step H must be finished before step B can begin.",13
	!text "Step H must be finished before step G can begin.",13
	!text "Step Q must be finished before step M can begin.",13
	!text "Step U must be finished before step E can begin.",13
	!text "Step C must be finished before step S can begin.",13
	!text "Step M must be finished before step L can begin.",13
	!text "Step T must be finished before step L can begin.",13
	!text "Step I must be finished before step N can begin.",13
	!text "Step Y must be finished before step N can begin.",13
	!text "Step K must be finished before step V can begin.",13
	!text "Step U must be finished before step B can begin.",13
	!text "Step H must be finished before step Z can begin.",13
	!text "Step H must be finished before step Y can begin.",13
	!text "Step E must be finished before step F can begin.",13
	!text "Step F must be finished before step Q can begin.",13
	!text "Step R must be finished before step G can begin.",13
	!text "Step T must be finished before step S can begin.",13
	!text "Step T must be finished before step Q can begin.",13
	!text "Step X must be finished before step H can begin.",13
	!text "Step Q must be finished before step S can begin.",13
	!text "Step Q must be finished before step J can begin.",13
	!text "Step G must be finished before step S can begin.",13
	!text "Step D must be finished before step S can begin.",13
	!text "Step A must be finished before step J can begin.",13
	!text "Step I must be finished before step Y can begin.",13
	!text "Step U must be finished before step K can begin.",13
	!text "Step P must be finished before step R can begin.",13
	!text "Step A must be finished before step T can begin.",13
	!text "Step J must be finished before step K can begin.",13
	!text "Step Z must be finished before step J can begin.",13
	!text "Step Z must be finished before step V can begin.",13
	!text "Step P must be finished before step X can begin.",13
	!text "Step E must be finished before step I can begin.",13
	!text "Step G must be finished before step L can begin.",13
	!text "Step G must be finished before step N can begin.",13
	!text "Step J must be finished before step L can begin.",13
	!text "Step I must be finished before step Q can begin.",13
	!text "Step Q must be finished before step K can begin.",13
	!text "Step B must be finished before step J can begin.",13
	!text "Step R must be finished before step T can begin.",13
	!text "Step Z must be finished before step K can begin.",13
	!text "Step J must be finished before step V can begin.",13
	!text "Step R must be finished before step L can begin.",13
	!text "Step R must be finished before step N can begin.",13
	!text "Step W must be finished before step Q can begin.",13
	!text "Step U must be finished before step W can begin.",13
	!text "Step Y must be finished before step V can begin.",13
	!text "Step C must be finished before step T can begin.",13
	!text "Step X must be finished before step B can begin.",13
	!text "Step M must be finished before step S can begin.",13
	!text "Step B must be finished before step K can begin.",13
	!text "Step D must be finished before step N can begin.",13
	!text "Step P must be finished before step U can begin.",13
	!text "Step N must be finished before step K can begin.",13
	!text "Step M must be finished before step K can begin.",13
	!text "Step C must be finished before step A can begin.",13
	!text "Step W must be finished before step B can begin.",13
	!text "Step C must be finished before step Y can begin.",13
	!text "Step T must be finished before step V can begin.",13
	!text "Step W must be finished before step M can begin.",13,0

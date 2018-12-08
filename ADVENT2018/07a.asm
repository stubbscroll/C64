; advent of code 2018 day 7, part 1
; https://adventofcode.com/2018/day/7
; algorithm: at each step, greedily take the lowest letter that exists in
; graph where all preceding nodes are taken
; runtime: 0 seconds

	CHROUT = $ffd2

	!to "07a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	zp1 = $fc
	zp2 = $fe
	letter = $f7
	pre = $f8

start	sei
	; init variables
	ldx #25
	lda #0
-	sta used,x
	dex
	bpl -
	jsr conv
loop2	; try every letter for the next position
	lda #0
	sta letter
loop3	; is letter used already?
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
	; check prerequisite
	lda used,y
	beq nextl ; not fulfilled, try next letter
next	inx
	inx
	bne loop4
	; looped through the input, letter found ok.
	; output it if it's part of an edge
endin	ldx letter
	lda #1
	sta used,x
	ldy pre
	beq loop2
	txa
	clc
	adc #'A'
	jsr CHROUT
	sei
	jmp loop2
nextl	ldx letter
	inx
	stx letter
	cpx #26
	bne loop3
	; we looped through all letters without succeeding, we're done
	lda #$0d
	jmp CHROUT

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

used	!fill 26,0 ; 1=letter has been used

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

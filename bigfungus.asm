!ShortJumpTimer = #$17
!LongJumpTimer = #$17
!HammerTimer = #$40
!PrefightTimer = #$B0
!WaitingForSpawningTimer = #$40

;RAM Address for a timer used throughout the code
!TimerRAM = !1540

;RAM Address for a timer of the mushroom invincibility (when it gets hit)
!InvincibilityTimerRAM = !1558

;RAM Address for mushroom's current move.
!MoveRAM = !151C
!Approaching = #$00
!PreFight = #$01
!Dying = #$02
!Dead = #$03
!WaitingSpawn = #$04
!WaitingSmash = #$05
!LongJumps = #$06
!ShortJumps = #$07
!GoingToJump = #$08
!Throwing = #$07

!HitsRAM = !1528
!MushroomsThrownRAM = !1504
!NumHits = #7

ShortJumpSpeed:
db $20, $E0

LongJumpSpeed:
db $40, $D0

FlipTable:
db $40, $00

XDisp:
db $00,$10,$00,$10,$0D,$10,$00,$10,$00,$03

YDisp:
db $F0,$F0,$00,$00,$F8

Tilemap:
db $C0,$C2,$E0,$E2,$8A
db $C4,$C6,$E4,$E6,$8A
db $C8,$CA,$E8,$EA,$8A
db $80,$82,$A0,$A2,$8A

print "INIT ",pc
	;Timer for the prefight stage
	LDA !PrefightTimer
	STA !TimerRAM,x

	STZ !MushroomsThrownRAM,x
	STZ !MoveRAM,x
	STZ !HitsRAM,x
	STZ !InvincibilityTimerRAM,x

	%SubHorzPos()
	TYA
	STA !157C,x
	RTL

print "MAIN ",pc
	PHB : PHK : PLB
	JSR Main
	PLB
	RTL

Main:
	JSR Graphics

	;This checks if the sprite is offscreen
	LDA #$00
	%SubOffScreen()

	LDA $9D                         ; Load sprite locking
	BNE Return                      ; Don't process sprite

	;Only run when sprite is living
	LDA !14C8,x
	CMP #$08
	BNE Return

	;Updates X/Y position and gravity
	JSL $01802A|!BankB

	STZ !1602,x

	;Get if the mushroom is touching ground
	LDA !1588,x
	AND #$04
	;If it is
	BNE OnGroundD

	LDA !AA,x
	BPL GraphicUpdate1

	LDA #$05
	STA !1602,x
	BRA OnGroundD

GraphicUpdate1:
	LDA #$0A
	STA !1602,x

OnGroundD:
	;If it has hit a wall...
	LDA !1588,x
	AND #$03
	BEQ NoWall

	;Then flips the direction
	LDA !157C,x
	EOR #$01
	STA !157C,x

	;Makes the mushroom stop
	STZ !B6,x

NoWall:
	;If it has not hit a celing...
	LDA !1588,x
	AND #$08
	BEQ NoCeil

	;Skip this
	STZ !AA,x

NoCeil:
	;If the mushroom is invincibile, don't interact with Mario.
	LDA !InvincibilityTimerRAM,x
	BNE MakeAMove

	;If the mushroom is in pre-fight or dying mode, don't interact with Mario
	LDA !MoveRAM,x
	BEQ MakeAMove
	CMP !PreFight
	BEQ MakeAMove
	CMP !Dying
	BEQ MakeAMove
	
	;Checks if Mario has made contact with the sprite. If not, go to return.
	JSL $01A7DC|!BankB
	BCC MakeAMove

	LDA !MoveRAM,x
	CMP !Dead
	BEQ InteractionDead

	;Jumps to the interaction subroutine
	JSR Interaction

MakeAMove:
	;Gets the move and jumps to the subroutine that corresponds to it.
	LDA !MoveRAM,x
	ASL A : TAX
	JMP.w (States,x)

States:
	dw Approaching
	dw PreFight
	dw Dying
	dw Dead
	dw WaitAfterSpawn
	dw WaitAfterSmashing
	dw LongJump
	dw ShortJump
	dw GoingToJump
	dw ThrowMushroom
	dw ThrowMushroom

Return:
	RTS

;-----------------------------------------CODE FOR MARIO INTERACTION WHEN DEAD-----------------------------------------
InteractionDead:
	LDA #$0B
	STA $1DFC|!Base2

	;Gives Mario a mushroom
	LDA $19
	BNE SkipGrowing
	
	LDY #$00

	LDA #$00
	STA $19

	LDA #$02                ; \ Set growing action 
	STA $71    ; /

	LDA #$2F                ; \  
	STA $1496|!Base2,y             ;  | Set animation timer 
	STA $9D     ; / Set lock sprites timer
	
	LDA #$0A                ; \ 
	STA $1DF9|!Base2

SkipGrowing:
	;RIP first boss I ever made
	STZ !14C8,x
	RTS

;Oh? You're approaching me?
Approaching:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	LDA !14E0,x		; Load sprite X position (high byte)
	XBA				; Swap accumulator low and high byte
	LDA !E4,x		; Load the sprite X position (low byte)
	REP #$20		; 16-bit A
	SEC : SBC $94	; Load the palyer X position
	CMP #$0045		; If the difference is 0x00F0 or larger...
	SEP #$20		; 8-bit A
	BCS ReturnA		; branch

	LDA !PreFight
	STA !MoveRAM,x

	STZ $1411|!Base2
ReturnA:
	RTS

;-----------------------------------------CODE FOR ABOUT TO JUMP-----------------------------------------
GoingToJump:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	LDA !1588,x
	AND #$04
	BEQ ContinueGTJ

	LDA #$0A
	STA !1602,x

ContinueGTJ:
	LDA !TimerRAM,x
	BNE ReturnGTJ

	LDA !LongJumps
	STA !MoveRAM,x
ReturnGTJ:
	RTS

;-----------------------------------------CODE FOR CHOOSING A RANDOM MOVE-----------------------------------------
ChooseAMove:
	;LDA #$03
	%Random()
	CLC
	ADC !ShortJumps
	STA !MoveRAM,x

	LDA #$40
	STA !TimerRAM,x

	;Set mushrooms to throw
	LDA #$03
	STA !MushroomsThrownRAM,x

	LDA !MoveRAM,x
	CMP !GoingToJump
	BNE ReturnCAM

	LDA #$50
	STA !TimerRAM,x

ReturnCAM:
	RTS

;-----------------------------------------CODE FOR PREFIGHT--------------------------------------------------
PreFight:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;If the timer is still going, return
	LDA !TimerRAM,x
	BNE ReturnI

	;If the timer for prefight runs out...

	;Play sound effect
	LDA #$10
	STA $1DF9|!Base2

	;Spawn a puff of smoke
	LDA #$07 : STA $00
	LDA #$F8 : STA $01
	LDA #$1B : STA $02
	LDA #$01
	%SpawnSmoke()
	
	LDY #$18
	

	PHP
	REP #$30
	STZ $98

	LDA $1A               ; \ setup block properties
	STA $9A
	JSR Cement

	PLP

	LDY #$18

	PHP
	REP #$30
	STZ $98

	LDA $1A               ; \ setup block properties
	CLC
	ADC #$00F0
	STA $9A
	JSR Cement

	PLP

	;Have a slight delay still.
	LDA !WaitingSpawn
	STA !MoveRAM,x

	;Set the timer
	LDA !WaitingForSpawningTimer
	STA !TimerRAM,x
ReturnI:
	RTS

Cement:
	LDA.W #$0130
	%ChangeMap16()

	DEY

	LDA $98
	CLC
	ADC #$0010
	STA $98

	TYA
	BNE Cement
	
	RTS

NoCement:
	LDA.W #$0025
	%ChangeMap16()

	DEY

	LDA $98
	CLC
	ADC #$0010
	STA $98

	TYA
	BNE NoCement
	
	RTS

;-----------------------------------------CODE FOR DYING--------------------------------------------------
Dying:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;Get if the mushroom is touching ground
	LDA !1588,x
	AND #$04

	;If it is not
	BEQ NoOnGroundD

	;If it is on the ground, keep it on the ground
	STZ !B6,x

NoOnGroundD:
	;If the timer is still going, return
	LDA !TimerRAM,x
	BNE ReturnI

	;Play sound effect
	LDA #$10
	STA $1DF9|!Base2

	;Spawn a puff of smoke
	LDA #$07 : STA $00
	STZ $01
	LDA #$1B : STA $02
	LDA #$01
	%SpawnSmoke()

	;Set the mushroom to being dead
	LDA !Dead
	STA !MoveRAM,x

	LDY #$18
	

	PHP
	REP #$30
	STZ $98

	LDA $1A               ; \ setup block properties
	STA $9A
	JSR NoCement

	PLP

	LDY #$18

	PHP
	REP #$30
	STZ $98

	LDA $1A               ; \ setup block properties
	CLC
	ADC #$00F0
	STA $9A
	JSR NoCement

	PLP

	LDA #$01
	STA $1411|!Base2
	;LDA #$FF	;course clear
	;STA $1493	;mode
	RTS

;-----------------------------------------CODE FOR DEATH--------------------------------------------------
Dead:
	;Get the sprite number back in x.
	LDX $15E9|!Base2
	RTS

;-----------------------------------------CODE FOR WAITING AFTER SPAWN---------------------------------------------------
WaitAfterSpawn:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;If the timer is still going, return
	LDA !TimerRAM,x
	BNE ReturnW

	;If the timer is finished, make the mushroom do short jumps.
	LDA !ShortJumps
	STA !MoveRAM,x

	;"Why do I hear boss music?"
	LDA #$05
	STA $1DFB|!Base2

ReturnW:
	RTS

;-----------------------------------------CODE FOR WAITING AFTER SMASHING---------------------------------------------------
WaitAfterSmashing:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;If the timer is still going, return
	LDA !TimerRAM,x
	BNE ReturnWS

	;If the timer is finished, make the mushroom do short jumps.
	LDA #$03
	JMP ChooseAMove

ReturnWS:
	RTS

;-----------------------------------------CODE FOR MARIO INTERACTION-----------------------------------------
Interaction:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;Check if Mario is on top of the mushroom. The $0E came from SubOffScreen
	LDA $0E
	CMP #$E6
	;If not, hurt mario
	BPL HurtMario

	;Checks if Mario is falling or not
	LDA $7D
	BPL Falling

	;Gets if "Can be jumped on with upward Y speed" is set, then don't make mushroom hurt when falling
	LDA !190F,x
	AND #$10
	BNE Falling

	;If no enemies have been stomped yet, hurt mario.
	LDA $1697|!Base2
	BNE HurtMario

Falling:
	;If "Can be jumped on" is set, jump to the code to hurt the mushroom
	LDA !1656,x		
	AND #$10
	BNE HurtMushroom

	;Or else if Mario is neither spin jumping or on Yoshi, hurt Mario.
	LDA $140D|!Base2
	ORA $187A|!Base2
	BEQ HurtMario

	;Allows Yoshi/Spinning Mario bounce of mushroom
	LDA #$02
	STA $1DF9|!Base2

	;Gives a boost and adds a contact effect
	JSL $01AA33|!BankB
	JSL $01AB99|!BankB

	RTS

HurtMushroom:
	;Play contact sound effect.
	LDA #$20
	STA $1DF9|!Base2
	
	;Gives a boost and adds a contact effect
	JSL $01AA33|!BankB
	JSL $01AB99|!BankB

	;Gets the amount of hits the mushroom has suffered from and compares it to the number of hits needed to kill it
	LDA !HitsRAM,x
	CMP !NumHits
	BCS Kill

	;Sets the timer for invincibility
	LDA #$50
	STA !InvincibilityTimerRAM,x

	INC !HitsRAM,x
	RTS

HurtMario:
	;Jumps to subroutine to hurt Mario and ends subroutine
	JSL $00F5B7|!BankB
	RTS

Kill:
	;Set the mushroom to "Dying"
	LDA !Dying
	STA !MoveRAM,x

	;Make the music stop
	LDA #$80
	STA $1DFB|!Base2

	LDA #$C0
	STA !TimerRAM,x
	RTS

;-----------------------------------------CODE FOR DOING THE SHORT JUMP-----------------------------------------
ShortJump:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;If it has not hit a wall.
	LDA !1588,x
	AND #$03
	BEQ NoWallSJ

	;For #$40 frames
	LDA #$10
	STA !TimerRAM,x

	LDA #$03
	JMP ChooseAMove

NoWallSJ:
	LDY !ShortJumpTimer
	;Get if the mushroom is touching ground
	LDA !1588,x
	AND #$04
	;If it is not, skip the rest and set the jump timer
	BEQ SetJumpTimer

	;Make Y & X speed 0 since it is on the ground
	STZ !AA,x
	STZ !B6,x

	;Checks if the timer is zero for jumping, if not get out of the subroutine.
	LDA !TimerRAM,x
	BNE ReturnSJ

	;Play "jump" sound effect
	LDA #$01
	STA $1DFA|!Base2

	;Move the mushroom upward (jump)
	LDA #$C0
	STA !AA,x

	;Also move the mushroom forward based on the direction it is facing
	LDY !157C,x
	LDA ShortJumpSpeed,y
	STA !B6,x

	LDY !ShortJumpTimer
	JMP SetJumpTimer
	
SetJumpTimer:
	;Set timer again
	TYA
	STA !TimerRAM,x

ReturnSJ:
	RTS

;-----------------------------------------CODE FOR DOING THE LONG JUMP------------------------------------------
LongJump:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;If it has not hit a wall, do not drop mushroom.
	LDA !1588,x
	AND #$03
	BEQ NoWallLJ

	;Or else... DROP THEM
	JSR DropMushroom

	LDA #$50
	STA !TimerRAM,x

	;If it has hit a wall, set the next move.
	LDA !WaitingSmash
	STA !MoveRAM,x

	JMP ReturnLJ

NoWallLJ:
	LDY #$10

	;Get if the mushroom is touching ground
	LDA !1588,x
	AND #$04

	;If it is not, jumps to seeing if the mushroom ran into a wall.
	BEQ SetJumpTimer

	;Make Y & X speed 0 since it is on the ground
	STZ !AA,x
	STZ !B6,x

	;Checks if the timer is zero for jumping, if not get out of the subroutine. The calling subroutine resets the timer (might change)
	LDA !TimerRAM,x
	BNE ReturnLJ

	;Play "jump" sound effect
	LDA #$01
	STA $1DFA|!Base2

	;Move the mushroom upward (jump)
	LDA #$D0
	STA !AA,x

	;Also move the mushroom forward based on the direction it is facing
	LDY !157C,x
	LDA LongJumpSpeed,y
	STA !B6,x

	LDY !LongJumpTimer
	;Reusing old code (which also has a return)
	JMP SetJumpTimer

ReturnLJ:
	RTS

;-----------------------------------------CODE FOR THROWING MUSHROOMS------------------------------------------
ThrowMushroom:
	;Get the sprite number back in x.
	LDX $15E9|!Base2

	;------------------------------------CHANGE CODE MAYBE----------------------------
	;Get if the mushroom is touching ground
	LDA !1588,x
	AND #$04
	;If it is not, set the hammer timer
	BEQ SetHammerTimer

	;The mushroom isn't going to move while throwing mushrooms
	STZ !B6,x

	LDA !MushroomsThrownRAM,x
	BNE Throw

	LDA #$01
	JMP ChooseAMove

Throw:

	LDA !TimerRAM,x
	CMP #$20
	BCS GraphicSkipTM

	LDA #$0F
	STA !1602,x

GraphicSkipTM:
	LDA !TimerRAM,x
	BNE ReturnTM

	DEC !MushroomsThrownRAM,x

	;Sprite x - (playertop x)
	LDA !E4,x ;Low byte of sprite x position
	SEC
	SBC $94 ;Low byte of player x position
	STA $00

	LDA !14E0,x ;High byte of sprite x position
	SBC $95 ;High byte of player x position
	STA $01

	;(Sprite y - 7) - (playertop y + 0F) = Sprite y - playertop y - 16
	LDA !D8,x ;Low byte of sprite y position
	SEC
	SBC $96 ;Low byte of player y position
	STA $02

	LDA !14D4,x ;High byte of sprite y position
	SBC $97 ;High byte of player y position
	STA $03

	LDA $02
	SEC
	SBC #$16
	STA $02

	LDA $03
	SBC #$00
	STA $03

	LDA #$40
	%Aiming()

	LDA $02
	STA $03

	LDA $00
	STA $02
	
	;Sets the offset of the thrown mushroom relative to the mushroom zero
	STZ $00
	LDA #$F8 : STA $01
	;STZ $01

	;For right now, hammers will be thrown
	LDA #!ExtendedOffset
	%SpawnExtended()

	LDA #$00
	STA $1765|!Base2,y

	

SetHammerTimer:
	;Set hammer timer
	LDA !HammerTimer
	STA !TimerRAM,x

ReturnTM:
	RTS

;-----------------------------------------CODE FOR DROPPING MUSHROOMS------------------------------------------
DropMushroom:
	;Shake the Screen
	LDA #$40
	STA $1887|!Base2
	LDX #$03

DropLoop:
	STZ $02
	STZ $03

	LDA #!ExtendedOffset
	%SpawnExtended()

	LDA #$C0
	STA $1715|!Base2,y
	LDA #$00
	STA $1729|!Base2,y

	;Get a random number in [10, E0]
	LDA #$D0
	%Random()
	CLC
	ADC #$10
	;Adds the camera position's low byte (no CLC is needed since my previous calculation can't overflow)
	ADC $1A
	;Stores the position to the extended sprites's low X byte
	STA $171F|!Base2,y

	;Sets the camera poisition's high byte and adds 1 if there was an overflow.
	LDA $1B
	ADC #$00
	;Stores the position to the extended sprites's high X byte
	STA $1733|!Base2,y
	

	LDA #$01
	STA $1765|!Base2,y

	DEX
	BNE DropLoop

	LDX $15E9|!Base2

Return2:
	RTS

;-----------------------------------------GRAPHICS ROUTINE------------------------------------------

Graphics:
	;If the
	LDA !MoveRAM,x
	CMP !Dying
	BEQ Draw

	;If the invincibility timer is zero, skip flashing
	LDA !InvincibilityTimerRAM,x
	BEQ Draw

	;Gets a one or zero from the frame counter and if it is zero, skip drawing
	LDA $14
	AND #$01
	BEQ Return2

Draw:
	;Get drawing started
	%GetDrawInfo()

	;Puts direction status into scratch ram.
	LDA !157C,x
	STA $02

	;Puts number of tiles into scratch ram.
	LDA #$03
	STA $03

	;Puts default properties into scratch ram
	LDA !15F6,x
	STA $04

	LDA !1602,x
	STA $05

	LDA !MoveRAM,x
	BEQ DrawSmallMushroom
	CMP !PreFight
	BEQ DrawSmallMushroom
	CMP !Dead
	BEQ DrawSmallMushroom

	LDA !1602,x
	CMP #$0F
	BNE NoHolding

	;If not, make the number of tiles 5.
	LDA #$04
	STA $03

NoHolding:
	PHX
	LDX $03

GraphicsLoop:
	PHX			; push the current tile number (00-03)

	LDA $02			; if the mole is facing right...
	BNE FacingLeft		;
	INX #5			; increment the index to the X displacement table by 4

FacingLeft:		;
	LDA $00			; $00 = base X position
	CLC			;
	ADC XDisp,x		; set the tile X displacement
	STA $0300|!Base2,y	; OAM address #1

	PLX			;

	LDA $01			; $01 = base Y position
	CLC			;
	ADC YDisp,x		; set the tile Y displacement
	STA $0301|!Base2,y	; OAM address #2

	
	PHX			;
	TXA
	CLC
	ADC $05
	TAX

	LDA Tilemap,x		; set the tile number
	STA $0302|!Base2,y	; OAM address #3

	PLX

	CPX #$04
	BEQ MushroomPalette

	LDA $04		; sprite palette and GFX page
	BRA Flip

MushroomPalette:
	LDA #$0B

Flip:
	PHX
	LDX $02			; if the sprite is facing right...
	BNE NoFlipTile		;
	ORA #$40		; X-flip the tile
NoFlipTile:		;
	ORA $64			; add in the sprite priority and set the tile properties
	STA $0303|!Base2,y	; OAM address #4

	PLX			; current tile
	INY #4			; add 4 to the OAM index
	DEX			; and decrement the tile count
	BPL GraphicsLoop		; if positive, there are more tiles to draw

	PLX			; pull back the sprite index

	LDY #$02		; the tiles are all 16x16, so Y = 02
	LDA $03
	JSL $01B7B3|!BankB	; finish the write to OAM

	
ReturnG:
	RTS

DrawSmallMushroom:
	;OAM tile X pos
	LDA $00
	CLC
	ADC #$07
	STA $0300|!Base2,y

	;OAM tile Y pos
	LDA $01
	STA $0301|!Base2,y

	;OAM tile num (mushroom for 24)
	LDA #$AA
	STA $0302|!Base2,y

	;Gets the default properties and priority for the current level and puts them together
	LDA !15F6,x
	ORA $64
	STA $0303|!Base2,y
	
	;A = tiles to draw 0 -> 1, Y = tile size 02 -> 16x16
	LDA #$00
	LDY #$02
	JSL $01B7B3|!BankB

	RTS

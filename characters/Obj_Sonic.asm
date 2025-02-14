; ----------------------------------------------------------------------------
; Object 01 - Sonic
; ----------------------------------------------------------------------------
; Sprite_19F50: Object_Sonic:
Obj_Sonic:
	; a0=character
	tst.w	(Debug_placement_mode).w	; is debug mode being used?
	beq.s	Obj_Sonic_Normal			; if not, branch
	jmp	(DebugMode).l
; ---------------------------------------------------------------------------
; loc_19F5C:
Obj_Sonic_Normal:
	moveq	#0,d0
	move.b	routine(a0),d0
	move.w	Obj_Sonic_Index(pc,d0.w),d1
	jmp	Obj_Sonic_Index(pc,d1.w)
; ===========================================================================
; off_19F6A: Obj_Sonic_States:
Obj_Sonic_Index:	offsetTable
		offsetTableEntry.w Obj_Sonic_Init		;  0
		offsetTableEntry.w Obj_Sonic_Control	;  2
		offsetTableEntry.w Obj_Sonic_Hurt		;  4
		offsetTableEntry.w Obj_Sonic_Dead		;  6
		offsetTableEntry.w Obj_Sonic_Gone		;  8
		offsetTableEntry.w Obj_Sonic_Respawning	; $A
; ===========================================================================
; loc_19F76: Obj_01_Sub_0: Obj_Sonic_Main:
Obj_Sonic_Init:
	addq.b	#2,routine(a0)	; => Obj_Sonic_Control
	move.b	#$13,y_radius(a0) ; this sets Sonic's collision height (2*pixels)
	move.b	#9,x_radius(a0)
	move.l	#Mapunc_Sonic,mappings(a0)
	move.w	#prio(2),priority(a0)
	move.b	#$18,width_pixels(a0)
	move.b	#4,render_flags(a0)
	lea		(Sonic_top_speed).w,a2	; Load Sonic_top_speed into a2
	jsr		ApplySpeedSettings	; Fetch Speed settings
	tst.b	(Last_star_pole_hit).w
	bne.s	Obj_Sonic_Init_Continued
	; only happens when not starting at a checkpoint:
	move.w	#make_art_tile(ArtTile_ArtUnc_Sonic,0,0),art_tile(a0)
	bsr.w	Adjust2PArtPointer
	move.b	#$C,top_solid_bit(a0)
	move.b	#$D,lrb_solid_bit(a0)
	move.w	x_pos(a0),(Saved_x_pos).w
	move.w	y_pos(a0),(Saved_y_pos).w
	move.w	art_tile(a0),(Saved_art_tile).w
	move.w	top_solid_bit(a0),(Saved_Solid_bits).w

Obj_Sonic_Init_Continued:
	move.b	#0,flips_remaining(a0)
	move.b	#4,flip_speed(a0)
	move.b	#0,(Super_Sonic_flag).w
	move.b	#$1E,air_left(a0)
	subi.w	#$20,x_pos(a0)
	addi_.w	#4,y_pos(a0)
	move.w	#0,(Sonic_Pos_Record_Index).w

	move.w	#$3F,d2
-	bsr.w	Sonic_RecordPos
	subq.w	#4,a1
	move.l	#0,(a1)
	dbf	d2,-

	addi.w	#$20,x_pos(a0)
	subi_.w	#4,y_pos(a0)

; ---------------------------------------------------------------------------
; Normal state for Sonic
; ---------------------------------------------------------------------------
; loc_1A030: Obj_01_Sub_2:
Obj_Sonic_Control:
	jsr		PanCamera

	tst.w	(Debug_mode_flag).w	; is debug cheat enabled?
	beq.s	+			; if not, branch
	btst	#button_B,(Ctrl_1_Press).w	; is button B pressed?
	beq.s	+			; if not, branch
	move.w	#1,(Debug_placement_mode).w	; change Sonic into a ring/item
	clr.b	(Control_Locked).w		; unlock control
	rts
; -----------------------------------------------------------------------
+	tst.b	(Control_Locked).w	; are controls locked?
	bne.s	+			; if yes, branch
	move.w	(Ctrl_1).w,(Ctrl_1_Logical).w	; copy new held buttons, to enable joypad control
	move.w	(Ctrl_6btn_1).w,(Ctrl_6btn_1_Logical).w	; copy new held buttons, to enable joypad control
	move.w	(Ctrl_Analog_1).w,(Ctrl_Analog_1_Logical).w	; copy new held buttons, to enable joypad control
+
	btst	#0,obj_control(a0)	; is Sonic interacting with another object that holds him in place or controls his movement somehow?
	bne.s	+			; if yes, branch to skip Sonic's control
	moveq	#0,d0
	move.b	status(a0),d0
	andi.w	#6,d0	; %0000 %0110
	move.w	Obj_Sonic_Modes(pc,d0.w),d1
	jsr	Obj_Sonic_Modes(pc,d1.w)	; run Sonic's movement control code
+
	cmpi.w	#-$100,(Camera_Min_Y_pos).w	; is vertical wrapping enabled?
	bne.s	+				; if not, branch
	andi.w	#$7FF,y_pos(a0) 		; perform wrapping of Sonic's y position
+
	bsr.s	Sonic_Display
	bsr.w	Sonic_Super
	bsr.w	Sonic_RecordPos
	bsr.w	Sonic_Water
	move.b	(Primary_Angle).w,next_tilt(a0)
	move.b	(Secondary_Angle).w,tilt(a0)
	tst.b	(WindTunnel_flag).w
	beq.s	+
	tst.b	anim(a0)
	bne.s	+
	move.b	next_anim(a0),anim(a0)
+
	bsr.w	Sonic_Animate
	tst.b	obj_control(a0)
	bmi.s	+
	jsr	(TouchResponse).l
+
	bra.w	LoadSonicDynPLC

; ===========================================================================
; secondary states under state Obj_Sonic_Control
; off_1A0BE:
Obj_Sonic_Modes:	offsetTable
		offsetTableEntry.w Obj_Sonic_MdNormal_Checks	; 0 - not airborne or rolling
		offsetTableEntry.w Obj_Sonic_MdAir			; 2 - airborne
		offsetTableEntry.w Obj_Sonic_MdRoll			; 4 - rolling
		offsetTableEntry.w Obj_Sonic_MdJump			; 6 - jumping
; ===========================================================================

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A0C6:
Sonic_Display:
	move.w	invulnerable_time(a0),d0
	beq.s	Obj_Sonic_Display
	subq.w	#1,invulnerable_time(a0)
	lsr.w	#3,d0
	bcc.s	Obj_Sonic_ChkInvin
; loc_1A0D4:
Obj_Sonic_Display:
	jsr	(DisplaySprite).l
; loc_1A0DA:
Obj_Sonic_ChkInvin:		; Checks if invincibility has expired and disables it if it has.
	btst	#status_sec_isInvincible,status_secondary(a0)
	beq.s	Obj_Sonic_ChkShoes
	tst.w	invincibility_time(a0)
	beq.s	Obj_Sonic_ChkShoes	; If there wasn't any time left, that means we're in Super Sonic mode.
	subq.w	#1,invincibility_time(a0)
	bne.s	Obj_Sonic_ChkShoes
	tst.b	(Current_Boss_ID).w	; Don't change music if in a boss fight
	bne.s	Obj_Sonic_RmvInvin
	cmpi.b	#$C,air_left(a0)	; Don't change music if drowning
	blo.s	Obj_Sonic_RmvInvin
	move.w	(Level_Music).w,d0
	musicreg	d0
;loc_1A106:
Obj_Sonic_RmvInvin:
	bclr	#status_sec_isInvincible,status_secondary(a0)
; loc_1A10C:
Obj_Sonic_ChkShoes:		; Checks if Speed Shoes have expired and disables them if they have.
	btst	#status_sec_hasSpeedShoes,status_secondary(a0)
	beq.s	Obj_Sonic_ExitChk
	tst.w	speedshoes_time(a0)
	beq.s	Obj_Sonic_ExitChk
	subq.w	#1,speedshoes_time(a0)
	bne.s	Obj_Sonic_ExitChk
	lea		(Sonic_top_speed).w,a2	; Load Sonic_top_speed into a2
	jsr		ApplySpeedSettings	; Fetch Speed settings
; loc_1A14A:
Obj_Sonic_RmvSpeed:
	bclr	#status_sec_hasSpeedShoes,status_secondary(a0)
	command	mus_ShoesOff		; Slow down tempo
; ---------------------------------------------------------------------------
; return_1A15A:
Obj_Sonic_ExitChk:
	rts
; End of subroutine Sonic_Display

; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars
; and input/status flags for Tails' AI to follow
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A15C:
Sonic_RecordPos:
	move.w	(Sonic_Pos_Record_Index).w,d0
	lea	(Sonic_Pos_Record_Buf).w,a1
	lea	(a1,d0.w),a1
	move.w	x_pos(a0),(a1)+
	move.w	y_pos(a0),(a1)+
	addq.b	#4,(Sonic_Pos_Record_Index+1).w

	lea	(Sonic_Stat_Record_Buf).w,a1
	lea	(a1,d0.w),a1
	move.w	(Ctrl_1_Logical).w,(a1)+
	move.w	status(a0),(a1)+

	rts
; End of subroutine Sonic_RecordPos

; =============== S U B R O U T I N E =======================================


Reset_Player_Position_Array:
		cmpa.w	#MainCharacter,a0			; is object player 1?
		bne.s	Reset_Player_Position_ArrayP2	; if not, branc
		lea	(Pos_table).w,a5
		lea	(Stat_table).w,a6
		move.w	#$3F,d0

loc_10DEC:
		move.w	x_pos(a0),(a5)+			; write location to pos_table
		move.w	y_pos(a0),(a5)+
		move.l	#0,(a6)+
		dbf	d0,loc_10DEC
		move.w	#0,(Pos_table_index).w
		rts

Reset_Player_Position_ArrayP2:
		;tst.w	(Competition_mode).w	; are we in Competition mode?
		;beq.s	locret_10E24		; if not, branch
		lea	(Stat_table).w,a1
		move.w	#$3F,d0

loc_10E12:
		move.w	x_pos(a0),(a1)+
		move.w	y_pos(a0),(a1)+
		dbf	d0,loc_10E12
		move.w	#0,(Pos_table_index_P2).w

locret_10E24:
		rts
; End of function Reset_Player_Position_Array


; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A186:
Sonic_Water:
	tst.b	(Water_flag).w	; does level have water?
	bne.s	Obj_Sonic_InWater	; if yes, branch

return_1A18C:
	rts
; ---------------------------------------------------------------------------
; loc_1A18E:
Obj_Sonic_InWater:
	move.w	(Water_Level_1).w,d0
	cmp.w	y_pos(a0),d0	; is Sonic above the water?
	bge.s	Obj_Sonic_OutWater	; if yes, branch

	bset	#6,status(a0)	; set underwater flag
	bne.s	return_1A18C	; if already underwater, branch

	movea.l	a0,a1
	bsr.w	ResumeMusic

	tst.b	(Option_WaterSoundFilter).w
	beq.s	+
	command	Mus_ToWater
+
	move.l	#Obj_SmallBubbles,(Sonic_BreathingBubbles+id).w ; load Obj_SmallBubbles (sonic's breathing bubbles) at $FFFFD080
	move.b	#$81,(Sonic_BreathingBubbles+subtype).w
	move.l	a0,(Sonic_BreathingBubbles+objoff_3C).w
	lea		(Sonic_top_speed).w,a2	; Load Sonic_top_speed into a2
	jsr		ApplySpeedSettings	; Fetch Speed settings
	asr.w	x_vel(a0)
	asr.w	y_vel(a0)	; memory operands can only be shifted one bit at a time
	asr.w	y_vel(a0)
	beq.s	return_1A18C
	move.w	#$100,(Sonic_Dust+anim).w	; splash animation
	sfx	sfx_Splash
	rts
; ---------------------------------------------------------------------------
; loc_1A1FE:
Obj_Sonic_OutWater:
	bclr	#6,status(a0) ; unset underwater flag
	beq.w	return_1A18C ; if already above water, branch

	movea.l	a0,a1
	bsr.w	ResumeMusic
	command	Mus_OutWater
	lea		(Sonic_top_speed).w,a2	; Load Sonic_top_speed into a2
	jsr		ApplySpeedSettings	; Fetch Speed settings
	;cmpi.b	#4,routine(a0)	; is Sonic falling back from getting hurt?
	;beq.s	+		; if yes, branch
	asl	y_vel(a0)
;+
	tst.w	y_vel(a0)
	beq.w	return_1A18C
	move.w	#$100,(Sonic_Dust+anim).w	; splash animation
	movea.l	a0,a1
	bsr.w	ResumeMusic
	cmpi.w	#-$1000,y_vel(a0)
	bgt.s	+
	move.w	#-$1000,y_vel(a0)	; limit upward y velocity exiting the water
+
	sfx	sfx_Splash
	rts
; End of subroutine Sonic_Water

; ===========================================================================
; ---------------------------------------------------------------------------
; Start of subroutine Obj_Sonic_MdNormal
; Called if Sonic is neither airborne nor rolling this frame
; ---------------------------------------------------------------------------
; loc_1A26E:
Obj_Sonic_MdNormal_Checks:
	move.b	(Ctrl_1_Press_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0
	bne.s	Obj_Sonic_MdNormal
	cmpi.b	#AniIDSonAni_Blink,anim(a0)
	beq.s	return_1A2DE
	cmpi.b	#AniIDSonAni_GetUp,anim(a0)
	beq.s	return_1A2DE
	cmpi.b	#AniIDSonAni_Wait,anim(a0)
	bne.s	Obj_Sonic_MdNormal
	cmpi.b	#$1E,anim_frame(a0)
	blo.s	Obj_Sonic_MdNormal
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_up_mask|button_down_mask|button_left_mask|button_right_mask|button_B_mask|button_C_mask|button_A_mask,d0
	beq.s	return_1A2DE
	move.b	#AniIDSonAni_Blink,anim(a0)
	cmpi.b	#$AC,anim_frame(a0)
	blo.s	return_1A2DE
	move.b	#AniIDSonAni_GetUp,anim(a0)
	bra.s	return_1A2DE
; ---------------------------------------------------------------------------
; loc_1A2B8:
Obj_Sonic_MdNormal:
	bsr.w	Sonic_CheckPeelout
	bsr.w	Sonic_CheckSpindash
	bsr.w	Sonic_Jump
	bsr.w	Sonic_SlopeResist
	bsr.w	Sonic_Move
	bsr.w	Sonic_Roll
	bsr.w	Sonic_LevelBound
	jsr	(ObjectMove).l
	bsr.w	AnglePos
	bsr.w	Sonic_SlopeRepel

return_1A2DE:
	rts
; End of subroutine Obj_Sonic_MdNormal
; ===========================================================================
; Start of subroutine Obj_Sonic_MdAir
; Called if Sonic is airborne, but not in a ball (thus, probably not jumping)
; loc_1A2E0: Obj_Sonic_MdJump
Obj_Sonic_MdAir:
	bsr.w	Sonic_JumpHeight
	bsr.w	Sonic_AirCurl
	bsr.w	Sonic_ChgJumpDir
	bsr.w	Sonic_LevelBound
	jsr	(ObjectMoveAndFall).l
	btst	#6,status(a0)	; is Sonic underwater?
	beq.s	+		; if not, branch
	subi.w	#$28,y_vel(a0)	; reduce gravity by $28 ($38-$28=$10)
+
	bsr.w	Sonic_JumpAngle
	bsr.w	Sonic_DoLevelCollision
	rts
; End of subroutine Obj_Sonic_MdAir

Sonic_AirCurl:
	tst.b	(Option_AirCurling).w
	beq.s	+

	btst	#button_a,(Ctrl_1_Press_Logical).w	; is a being pressed?
	beq.s	+			; if not, branch

	tst.b	spindash_flag(a0)
	bne.s	+

	move.b	#1,jumping(a0)
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)	; use "jumping" animation
	bset	#Status_Roll,status(a0)
	cmpi.l	#Obj_Knuckles,id(a0)
	bne.s	+
	clr.b	double_jump_flag(a0)
	clr.b	glidemode(a0)
+
	rts
; ===========================================================================
; Start of subroutine Obj_Sonic_MdRoll
; Called if Sonic is in a ball, but not airborne (thus, probably rolling)
; loc_1A30A:
Obj_Sonic_MdRoll:
	tst.b	pinball_mode(a0)
	bne.s	+
	bsr.w	Sonic_Jump
+
	bsr.w	Sonic_RollRepel
	bsr.w	Sonic_RollSpeed
	bsr.w	Sonic_LevelBound
	jsr	(ObjectMove).l
	bsr.w	AnglePos
	bsr.w	Sonic_SlopeRepel
	rts
; End of subroutine Obj_Sonic_MdRoll
; ===========================================================================
; Start of subroutine Obj_Sonic_MdJump
; Called if Sonic is in a ball and airborne (he could be jumping but not necessarily)
; Notes: This is identical to Obj_Sonic_MdAir, at least at this outer level.
;        Why they gave it a separate copy of the code, I don't know.
; loc_1A330: Obj_Sonic_MdJump2:
Obj_Sonic_MdJump:
	tst.l	(HomingAttack_Object).l
	bne.s	Sonic_HomingAttackMove
	bsr.w	Sonic_CheckGoSuper
	bsr.w	Sonic_DropDash
	bsr.w	Sonic_JumpHeight
	bsr.w	Sonic_AirCurl
	bsr.w	Sonic_ChgJumpDir
	bsr.w	Sonic_LevelBound
	jsr	(ObjectMoveAndFall).l
	btst	#6,status(a0)	; is Sonic underwater?
	beq.s	+		; if not, branch
	subi.w	#$28,y_vel(a0)	; reduce gravity by $28 ($38-$28=$10)
+
	bsr.w	Sonic_JumpAngle
	bsr.w	Sonic_DoLevelCollision
	rts
; End of subroutine Obj_Sonic_MdJump

Sonic_HomingAttackMove:
	move.l	(HomingAttack_Object).l,a1
	tst.l	id(a1) ; if object is deleted, cancel
	beq.w	Sonic_HomingAttackStop
	; Failsafe timer
	addi.b	#1,double_jump_flag(a0)
	cmpi.b	#60,double_jump_flag(a0)
	bge.w	Sonic_HomingAttackStop

	moveq	#0,d1
	move.w	x_pos(a1),d1
	sub.w	x_pos(a0),d1

	moveq	#0,d2
	move.w	y_pos(a1),d2
	sub.w	y_pos(a0),d2

	jsr		CalcAngle
	jsr		CalcSine
	
	muls.w	#16,d0
	muls.w	#16,d1

	move.w	d0,y_vel(a0)
	move.w	d1,x_vel(a0)

	jsr	(ObjectMove).l
	bsr.w	Sonic_LevelBound
	bra.w	Sonic_DoLevelCollision

Sonic_HomingAttackStop:
	clr.l	(HomingAttack_Object).l
	clr.w	x_vel(a0)
	clr.w	y_vel(a0)
	clr.b	double_jump_flag(a0)
	rts	

; ---------------------------------------------------------------------------

Sonic_DropDash:
	cmpi.b	#2,(Option_SonicAbility).l
	beq.s	Sonic_DropDashCont
	cmpi.b	#3,(Option_SonicAbility).l
	beq.s	Sonic_DropDashCont
	rts

Sonic_DropDashCont:
	move.b	status_secondary(a0),d0
	andi.b	#Status_FireShield_mask|Status_LtngShield_mask|Status_BublShield_mask,d0 ; got a shield?
	bne.w	+ ; yep? begone

	tst.b	double_jump_flag(a0)	; Have we started a double jump?
	beq.s	+						; If not, stop

	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0 ; is a jump button pressed?
	beq.s	Sonic_DropDashCancel		; if not, branch

	tst.b	glidemode(a0)		; Has the timer hit 0?
	beq.s	+					; If so, branch
	subi.b	#1,glidemode(a0)
	tst.b	glidemode(a0)		; Has the timer hit 0?
	bne.s	+					; If not, branch
	sfx		sfx_DropDash
	move.b	#AniIDSonAni_DropDash,anim(a0)
+
	rts

Sonic_DropDashCancel:
	cmpi.b	#20,glidemode(a0)
	beq.s	+
	move.b	#20,glidemode(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)
+
	rts

; ---------------------------------------------------------------------------
; Subroutine to make Sonic walk/run
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A35A:
Sonic_Move:
	move.w	(Sonic_top_speed).w,d6

	moveq	#0,d0
	move.b	(Ctrl_Analog_1_X_Logical).w,d0

	subi.w	#31,d0
    bpl.b   +
    neg.w   d0
	addi.w	#1,d0
+
	move.w	#32,d1
	sub.w	d0,d1
	lsr.w	#2,d1

	cmpi.w	#8,d1
	beq.s	+
	
	lsr.w	d1,d6
+

	move.w	(Sonic_acceleration).w,d5
	move.w	(Sonic_deceleration).w,d4
    if status_sec_isSliding = 7
	tst.b	status_secondary(a0)
	bmi.w	Obj_Sonic_Traction
    else
	btst	#status_sec_isSliding,status_secondary(a0)
	bne.w	Obj_Sonic_Traction
    endif
	tst.w	move_lock(a0)
	bne.w	Obj_Sonic_ResetScr
	btst	#button_left,(Ctrl_1_Held_Logical).w	; is left being pressed?
	beq.s	Obj_Sonic_NotLeft			; if not, branch
	cmpi.b	#$8,anim(a0)				; is character ducking?
	beq.w	Obj_Sonic_NotLeft
	bsr.w	Sonic_MoveLeft
; loc_1A382:
Obj_Sonic_NotLeft:
	btst	#button_right,(Ctrl_1_Held_Logical).w	; is right being pressed?
	beq.s	Obj_Sonic_NotRight			; if not, branch
	cmpi.b	#$8,anim(a0)				; is character ducking?
	beq.w	Obj_Sonic_NotRight
	bsr.w	Sonic_MoveRight
; loc_1A38E:
Obj_Sonic_NotRight:
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0		; is Sonic on a slope?
	bne.w	Obj_Sonic_ResetScr	; if yes, branch
	tst.w	inertia(a0)	; is Sonic moving?
	bne.w	Obj_Sonic_ResetScr	; if yes, branch
	bclr	#5,status(a0)
	move.b	#AniIDSonAni_Wait,anim(a0)	; use "standing" animation
	btst	#3,status(a0)
	beq.w	Sonic_Balance
	moveq	#0,d0
	move.w	interact(a0),a1
	tst.b	status(a1)
	bmi.w	Sonic_Lookup
	moveq	#0,d1
	move.b	width_pixels(a1),d1
	move.w	d1,d2
	add.w	d2,d2
	subq.w	#2,d2
	add.w	x_pos(a0),d1
	sub.w	x_pos(a1),d1
	tst.b	(Super_Sonic_flag).w
	bne.w	SuperSonic_Balance
	cmpi.w	#2,d1
	blt.s	Sonic_BalanceOnObjLeft
	cmp.w	d2,d1
	bge.s	Sonic_BalanceOnObjRight
	bra.w	Sonic_Lookup
; ---------------------------------------------------------------------------
; loc_1A3FE:
SuperSonic_Balance:
	cmpi.w	#2,d1
	blt.w	SuperSonic_BalanceOnObjLeft
	cmp.w	d2,d1
	bge.w	SuperSonic_BalanceOnObjRight
	bra.w	Sonic_Lookup
; ---------------------------------------------------------------------------
; balancing checks for when you're on the right edge of an object
; loc_1A410:
Sonic_BalanceOnObjRight:
	btst	#0,status(a0)
	bne.s	+
	move.b	#AniIDSonAni_Balance,anim(a0)
	addq.w	#6,d2
	cmp.w	d2,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance2,anim(a0)
	bra.w	Obj_Sonic_ResetScr
	; on right edge of object but facing left:
+	move.b	#AniIDSonAni_Balance3,anim(a0)
	addq.w	#6,d2
	cmp.w	d2,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance4,anim(a0)
	bclr	#0,status(a0)
	bra.w	Obj_Sonic_ResetScr
; ---------------------------------------------------------------------------
; balancing checks for when you're on the left edge of an object
; loc_1A44E:
Sonic_BalanceOnObjLeft:
	btst	#0,status(a0)
	beq.s	+
	move.b	#AniIDSonAni_Balance,anim(a0)
	cmpi.w	#-4,d1
	bge.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance2,anim(a0)
	bra.w	Obj_Sonic_ResetScr
	; on left edge of object but facing right:
+	move.b	#AniIDSonAni_Balance3,anim(a0)
	cmpi.w	#-4,d1
	bge.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance4,anim(a0)
	bset	#0,status(a0)
	bra.w	Obj_Sonic_ResetScr
; ---------------------------------------------------------------------------
; balancing checks for when you're on the edge of part of the level
; loc_1A48C:
Sonic_Balance:
	jsr	(ChkFloorEdge).l
	cmpi.w	#$C,d1
	blt.w	Sonic_Lookup
	tst.b	(Super_Sonic_flag).w
	bne.w	SuperSonic_Balance2
	cmpi.b	#3,next_tilt(a0)
	bne.s	Sonic_BalanceLeft
	btst	#0,status(a0)
	bne.s	+
	move.b	#AniIDSonAni_Balance,anim(a0)
	move.w	x_pos(a0),d3
	subq.w	#6,d3
	jsr	(ChkFloorEdge_Part2).l
	cmpi.w	#$C,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance2,anim(a0)
	bra.w	Obj_Sonic_ResetScr
	; on right edge but facing left:
+	move.b	#AniIDSonAni_Balance3,anim(a0)
	move.w	x_pos(a0),d3
	subq.w	#6,d3
	jsr	(ChkFloorEdge_Part2).l
	cmpi.w	#$C,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance4,anim(a0)
	bclr	#0,status(a0)
	bra.w	Obj_Sonic_ResetScr
; ---------------------------------------------------------------------------
Sonic_BalanceLeft:
	cmpi.b	#3,tilt(a0)
	bne.s	Sonic_Lookup
	btst	#0,status(a0)
	beq.s	+
	move.b	#AniIDSonAni_Balance,anim(a0)
	move.w	x_pos(a0),d3
	addq.w	#6,d3
	jsr	(ChkFloorEdge_Part2).l
	cmpi.w	#$C,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance2,anim(a0)
	bra.w	Obj_Sonic_ResetScr
	; on left edge but facing right:
+	move.b	#AniIDSonAni_Balance3,anim(a0)
	move.w	x_pos(a0),d3
	addq.w	#6,d3
	jsr	(ChkFloorEdge_Part2).l
	cmpi.w	#$C,d1
	blt.w	Obj_Sonic_ResetScr
	move.b	#AniIDSonAni_Balance4,anim(a0)
	bset	#0,status(a0)
	bra.w	Obj_Sonic_ResetScr
; ---------------------------------------------------------------------------
; loc_1A55E:
SuperSonic_Balance2:
	cmpi.b	#3,next_tilt(a0)
	bne.s	loc_1A56E

; loc_1A566:
SuperSonic_BalanceOnObjRight:
	bclr	#0,status(a0)
	bra.s	loc_1A57C
; ---------------------------------------------------------------------------
loc_1A56E:
	cmpi.b	#3,tilt(a0)
	bne.s	Sonic_Lookup

; loc_1A576:
SuperSonic_BalanceOnObjLeft:
	bset	#0,status(a0)

loc_1A57C:
	move.b	#AniIDSonAni_Balance,anim(a0)
	bra.s	Obj_Sonic_ResetScr
; ---------------------------------------------------------------------------
; loc_1A584:
Sonic_Lookup:
	btst	#button_up,(Ctrl_1_Held_Logical).w	; is up being pressed?
	beq.s	Sonic_Duck			; if not, branch
	move.b	#AniIDSonAni_LookUp,anim(a0)			; use "looking up" animation
	addq.w	#1,(Sonic_Look_delay_counter).w
	cmpi.w	#$78,(Sonic_Look_delay_counter).w
	blo.s	Obj_Sonic_ResetScr_Part2
	move.w	#$78,(Sonic_Look_delay_counter).w
	cmpi.w	#$C8,(Camera_Y_pos_bias).w
	beq.s	Obj_Sonic_UpdateSpeedOnGround
	addq.w	#2,(Camera_Y_pos_bias).w
	bra.s	Obj_Sonic_UpdateSpeedOnGround
; ---------------------------------------------------------------------------
; loc_1A5B2:
Sonic_Duck:
	btst	#button_down,(Ctrl_1_Held_Logical).w	; is down being pressed?
	beq.s	Obj_Sonic_ResetScr			; if not, branch
	move.b	#AniIDSonAni_Duck,anim(a0)			; use "ducking" animation
	addq.w	#1,(Sonic_Look_delay_counter).w
	cmpi.w	#$78,(Sonic_Look_delay_counter).w
	blo.s	Obj_Sonic_ResetScr_Part2
	move.w	#$78,(Sonic_Look_delay_counter).w
	cmpi.w	#8,(Camera_Y_pos_bias).w
	beq.s	Obj_Sonic_UpdateSpeedOnGround
	subq.w	#2,(Camera_Y_pos_bias).w
	bra.s	Obj_Sonic_UpdateSpeedOnGround

; ===========================================================================
; moves the screen back to its normal position after looking up or down
; loc_1A5E0:
Obj_Sonic_ResetScr:
	move.w	#0,(Sonic_Look_delay_counter).w
; loc_1A5E6:
Obj_Sonic_ResetScr_Part2:
	cmpi.w	#(224/2)-16,(Camera_Y_pos_bias).w	; is screen in its default position?
	beq.s	Obj_Sonic_UpdateSpeedOnGround	; if yes, branch.
	bhs.s	+				; depending on the sign of the difference,
	addq.w	#4,(Camera_Y_pos_bias).w	; either add 2
+	subq.w	#2,(Camera_Y_pos_bias).w	; or subtract 2

; ---------------------------------------------------------------------------
; updates Sonic's speed on the ground
; ---------------------------------------------------------------------------
; sub_1A5F8:
Obj_Sonic_UpdateSpeedOnGround:
	tst.b	(Super_Sonic_flag).w
	beq.w	+
	move.w	#$C,d5
+
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_left_mask|button_right_mask,d0 ; is left/right pressed?
	bne.s	Obj_Sonic_Traction	; if yes, branch
	move.w	inertia(a0),d0
	beq.s	Obj_Sonic_Traction
	bmi.s	Obj_Sonic_SettleLeft

; slow down when facing right and not pressing a direction
; Obj_Sonic_SettleRight:
	sub.w	d5,d0
	bcc.s	+
	move.w	#0,d0
+
	move.w	d0,inertia(a0)
	bra.s	Obj_Sonic_Traction
; ---------------------------------------------------------------------------
; slow down when facing left and not pressing a direction
; loc_1A624:
Obj_Sonic_SettleLeft:
	add.w	d5,d0
	bcc.s	+
	move.w	#0,d0
+
	move.w	d0,inertia(a0)

; increase or decrease speed on the ground
; loc_1A630:
Obj_Sonic_Traction:
	move.b	angle(a0),d0
	jsr	(CalcSine).l
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	move.w	d1,x_vel(a0)
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,y_vel(a0)

; stops Sonic from running through walls that meet the ground
; loc_1A64E:
Obj_Sonic_CheckWallsOnGround:
	move.b	angle(a0),d0
	addi.b	#$40,d0
	bmi.s	return_1A6BE
	move.b	#$40,d1			; Rotate 90 degrees clockwise
	tst.w	inertia(a0)		; Check inertia
	beq.s	return_1A6BE	; If not moving, don't do anything
	bmi.s	+				; If negative, branch
	neg.w	d1				; Otherwise, we want to rotate counterclockwise
+
	move.b	angle(a0),d0
	add.b	d1,d0
	move.w	d0,-(sp)
	bsr.w	CalcRoomInFront
	move.w	(sp)+,d0
	tst.w	d1
	bpl.s	return_1A6BE
	asl.w	#8,d1
	addi.b	#$20,d0
	andi.b	#$C0,d0
	beq.s	loc_1A6BA
	cmpi.b	#$40,d0
	beq.s	loc_1A6A8
	cmpi.b	#$80,d0
	beq.s	loc_1A6A2
	add.w	d1,x_vel(a0)
	bset	#5,status(a0)
	move.w	#0,inertia(a0)
	rts
; ---------------------------------------------------------------------------
loc_1A6A2:
	sub.w	d1,y_vel(a0)
	rts
; ---------------------------------------------------------------------------
loc_1A6A8:
	sub.w	d1,x_vel(a0)
	bset	#5,status(a0)
	move.w	#0,inertia(a0)
	rts
; ---------------------------------------------------------------------------
loc_1A6BA:
	add.w	d1,y_vel(a0)

return_1A6BE:
	rts
; End of subroutine Sonic_Move


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A6C0:
Sonic_MoveLeft:
	move.w	inertia(a0),d0
	beq.s	+
	bpl.s	Sonic_TurnLeft ; if Sonic is already moving to the right, branch
+
	bset	#0,status(a0)
	bne.s	+
	bclr	#5,status(a0)
	move.b	#AniIDSonAni_Run,next_anim(a0)
+
	sub.w	d5,d0	; add acceleration to the left
	move.w	d6,d1
	neg.w	d1
	cmp.w	d1,d0	; compare new speed with top speed
	bgt.s	++	; if new speed is less than the maximum, branch

	cmpi.b	#1,(Option_PhysicsStyle).w ; Ground speed cap toggle
	beq.s	+
	add.w	d5,d0	; remove this frame's acceleration change
	cmp.w	d1,d0	; compare speed with top speed
	ble.s	++	; if speed was already greater than the maximum, branch
+
	move.w	d1,d0	; limit speed on ground going left
+
	move.w	d0,inertia(a0)
	move.b	#AniIDSonAni_Walk,anim(a0)	; use walking animation
	rts
; ---------------------------------------------------------------------------
; loc_1A6FA:
Sonic_TurnLeft:
	sub.w	d4,d0
	bcc.s	+
	move.w	#-$80,d0
+
	move.w	d0,inertia(a0)
	move.b	angle(a0),d1
	addi.b	#$20,d1
	andi.b	#$C0,d1
	bne.s	return_1A744
	cmpi.w	#$400,d0
	blt.s	return_1A744
	move.b	#AniIDSonAni_Stop,anim(a0)	; use "stopping" animation
	bclr	#0,status(a0)
	sfx	sfx_Skid
	cmpi.b	#$C,air_left(a0)
	blo.s	return_1A744	; if he's drowning, branch to not make dust
	move.b	#6,(Sonic_Dust+routine).w
	move.b	#$15,(Sonic_Dust+mapping_frame).w

return_1A744:
	rts
; End of subroutine Sonic_MoveLeft


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A746:
Sonic_MoveRight:
	move.w	inertia(a0),d0
	bmi.s	Sonic_TurnRight	; if Sonic is already moving to the left, branch
	bclr	#0,status(a0)
	beq.s	+
	bclr	#5,status(a0)
	move.b	#AniIDSonAni_Run,next_anim(a0)
+
	add.w	d5,d0	; add acceleration to the right
	cmp.w	d6,d0	; compare new speed with top speed
	blt.s	++	; if new speed is less than the maximum, branch

	cmpi.b	#1,(Option_PhysicsStyle).w ; Ground speed cap toggle
	beq.s	+
	sub.w	d5,d0	; remove this frame's acceleration change
	cmp.w	d6,d0	; compare speed with top speed
	bge.s	++	; if speed was already greater than the maximum, branch
+
	move.w	d6,d0	; limit speed on ground going right
+
	move.w	d0,inertia(a0)
	move.b	#AniIDSonAni_Walk,anim(a0)	; use walking animation
	rts
; ---------------------------------------------------------------------------
; loc_1A77A:
Sonic_TurnRight:
	add.w	d4,d0
	bcc.s	+
	move.w	#$80,d0
+
	move.w	d0,inertia(a0)
	move.b	angle(a0),d1
	addi.b	#$20,d1
	andi.b	#$C0,d1
	bne.s	return_1A7C4
	cmpi.w	#-$400,d0
	bgt.s	return_1A7C4
	move.b	#AniIDSonAni_Stop,anim(a0)	; use "stopping" animation
	bset	#0,status(a0)
	sfx	sfx_Skid
	cmpi.b	#$C,air_left(a0)
	blo.s	return_1A7C4	; if he's drowning, branch to not make dust
	move.b	#6,(Sonic_Dust+routine).w
	move.b	#$15,(Sonic_Dust+mapping_frame).w

return_1A7C4:
	rts
; End of subroutine Sonic_MoveRight

; ---------------------------------------------------------------------------
; Subroutine to change Sonic's speed as he rolls
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A7C6:
Sonic_RollSpeed:
	move.w	(Sonic_top_speed).w,d6
	asl.w	#1,d6
	moveq	#6,d5	; natural roll deceleration = 1/2 normal acceleration
	move.w	#$20,d4	; controlled roll deceleration... interestingly,
			; this should be Sonic_deceleration/4 according to Tails_RollSpeed,
			; which means Sonic is much better than Tails at slowing down his rolling when he's underwater
    if status_sec_isSliding = 7
	tst.b	status_secondary(a0)
	bmi.w	Obj_Sonic_Roll_ResetScr
    else
	btst	#status_sec_isSliding,status_secondary(a0)
	bne.w	Obj_Sonic_Roll_ResetScr
    endif
	tst.w	move_lock(a0)
	bne.s	Sonic_ApplyRollSpeed
	btst	#button_left,(Ctrl_1_Held_Logical).w	; is left being pressed?
	beq.s	+				; if not, branch
	bsr.w	Sonic_RollLeft
+
	btst	#button_right,(Ctrl_1_Held_Logical).w	; is right being pressed?
	beq.s	Sonic_ApplyRollSpeed		; if not, branch
	bsr.w	Sonic_RollRight

; loc_1A7FC:
Sonic_ApplyRollSpeed:
	move.w	inertia(a0),d0
	beq.s	Sonic_CheckRollStop
	bmi.s	Sonic_ApplyRollSpeedLeft

; Sonic_ApplyRollSpeedRight:
	sub.w	d5,d0
	bcc.s	+
	move.w	#0,d0
+
	move.w	d0,inertia(a0)
	bra.s	Sonic_CheckRollStop
; ---------------------------------------------------------------------------
; loc_1A812:
Sonic_ApplyRollSpeedLeft:
	add.w	d5,d0
	bcc.s	+
	move.w	#0,d0
+
	move.w	d0,inertia(a0)

; loc_1A81E:
Sonic_CheckRollStop:
	tst.w	inertia(a0)
	bne.s	Obj_Sonic_Roll_ResetScr
	tst.b	pinball_mode(a0) ; note: the spindash flag has a different meaning when Sonic's already rolling -- it's used to mean he's not allowed to stop rolling
	bne.s	Sonic_KeepRolling
	bclr	#Status_Roll,status(a0)
	move.b	#$13,y_radius(a0)
	move.b	#9,x_radius(a0)
	move.b	#AniIDSonAni_Wait,anim(a0)
	subq.w	#5,y_pos(a0)
	bra.s	Obj_Sonic_Roll_ResetScr

; ---------------------------------------------------------------------------
; magically gives Sonic an extra push if he's going to stop rolling where it's not allowed
; (such as in an S-curve in HTZ or a stopper chamber in CNZ)
; loc_1A848:
Sonic_KeepRolling:
	move.w	#$400,inertia(a0)
	btst	#0,status(a0)
	beq.s	Obj_Sonic_Roll_ResetScr
	neg.w	inertia(a0)

; resets the screen to normal while rolling, like Obj_Sonic_ResetScr
; loc_1A85A:
Obj_Sonic_Roll_ResetScr:
	cmpi.w	#(224/2)-16,(Camera_Y_pos_bias).w	; is screen in its default position?
	beq.s	Sonic_SetRollSpeeds		; if yes, branch
	bhs.s	+				; depending on the sign of the difference,
	addq.w	#4,(Camera_Y_pos_bias).w	; either add 2
+	subq.w	#2,(Camera_Y_pos_bias).w	; or subtract 2

; loc_1A86C:
Sonic_SetRollSpeeds:
	move.b	angle(a0),d0
	jsr	(CalcSine).l
	muls.w	inertia(a0),d0
	asr.l	#8,d0
	move.w	d0,y_vel(a0)	; set y velocity based on $14 and angle
	muls.w	inertia(a0),d1
	asr.l	#8,d1
	; HJW: Mania caps this higher
	move.w	#$1000,d0
	cmpi.b	#3,(Option_PhysicsStyle).w
	blt.s	+
	move.w	#$1400,d0
+
	cmp.w	d0,d1
	ble.s	+
	move.w	d0,d1	; limit Sonic's speed rolling right
+
	neg.w	d0
	cmp.w	d0,d1
	bge.s	+
	move.w	d0,d1	; limit Sonic's speed rolling left
+
	move.w	d1,x_vel(a0)	; set x velocity based on $14 and angle
	bra.w	Obj_Sonic_CheckWallsOnGround
; End of function Sonic_RollSpeed


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


; loc_1A8A2:
Sonic_RollLeft:
	move.w	inertia(a0),d0
	beq.s	+
	bpl.s	Sonic_BrakeRollingRight
+
	bset	#0,status(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)	; use "rolling" animation
	rts
; ---------------------------------------------------------------------------
; loc_1A8B8:
Sonic_BrakeRollingRight:
	sub.w	d4,d0	; reduce rightward rolling speed
	bcc.s	+
	move.w	#-$80,d0
+
	move.w	d0,inertia(a0)
	rts
; End of function Sonic_RollLeft


; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||


; loc_1A8C6:
Sonic_RollRight:
	move.w	inertia(a0),d0
	bmi.s	Sonic_BrakeRollingLeft
	bclr	#0,status(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)	; use "rolling" animation
	rts
; ---------------------------------------------------------------------------
; loc_1A8DA:
Sonic_BrakeRollingLeft:
	add.w	d4,d0	; reduce leftward rolling speed
	bcc.s	+
	move.w	#$80,d0
+
	move.w	d0,inertia(a0)
	rts
; End of subroutine Sonic_RollRight


; ---------------------------------------------------------------------------
; Subroutine for moving Sonic left or right when he's in the air
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A8E8:
Sonic_ChgJumpDir:
	move.w	(Sonic_top_speed).w,d6

	moveq	#0,d0
	move.b	(Ctrl_Analog_1_X_Logical).w,d0

	subi.w	#31,d0
    bpl.b   +
    neg.w   d0
	addi.w	#1,d0
+
	move.w	#32,d1
	sub.w	d0,d1
	lsr.w	#2,d1

	cmpi.w	#8,d1
	beq.s	+
	
	lsr.w	d1,d6
+

	move.w	(Sonic_acceleration).w,d5
	asl.w	#1,d5
	btst	#4,status(a0)		; did Sonic jump from rolling?
	bne.s	Obj_Sonic_Jump_ResetScr	; if yes, branch to skip midair control
	move.w	x_vel(a0),d0
	btst	#button_left,(Ctrl_1_Held_Logical).w
	beq.s	++	; if not holding left, branch

	bset	#0,status(a0)
	sub.w	d5,d0	; add acceleration to the left
	move.w	d6,d1
	neg.w	d1
	cmp.w	d1,d0	; compare new speed with top speed
	bgt.s	++	; if new speed is less than the maximum, branch
	cmpi.b	#2,(Option_PhysicsStyle).w
	blt.s	+
	add.w	d5,d0	; +++ remove this frame's acceleration change
	cmp.w	d1,d0	; +++ compare speed with top speed
	ble.s	++	; +++ if speed was already greater than the maximum, branch
+
	move.w	d1,d0	; limit speed in air going left, even if Sonic was already going faster (speed limit/cap)
+
	btst	#button_right,(Ctrl_1_Held_Logical).w
	beq.s	++	; if not holding right, branch

	bclr	#0,status(a0)
	add.w	d5,d0	; accelerate right in the air
	cmp.w	d6,d0	; compare new speed with top speed
	blt.s	++	; if new speed is less than the maximum, branch
	cmpi.b	#2,(Option_PhysicsStyle).w
	blt.s	+
	sub.w	d5,d0	; +++ remove this frame's acceleration change
	cmp.w	d6,d0	; +++ compare speed with top speed
	bge.s	++	; +++ if speed was already greater than the maximum, branch
+
	move.w	d6,d0	; limit speed in air going right, even if Sonic was already going faster (speed limit/cap)
; Obj_Sonic_JumpMove:
+	move.w	d0,x_vel(a0)

; loc_1A932: Obj_Sonic_ResetScr2:
Obj_Sonic_Jump_ResetScr:
	cmpi.w	#(224/2)-16,(Camera_Y_pos_bias).w	; is screen in its default position?
	beq.s	Sonic_JumpPeakDecelerate	; if yes, branch
	bhs.s	+				; depending on the sign of the difference,
	addq.w	#4,(Camera_Y_pos_bias).w	; either add 2
+	subq.w	#2,(Camera_Y_pos_bias).w	; or subtract 2

; loc_1A944:
Sonic_JumpPeakDecelerate:
	cmpi.w	#-$400,y_vel(a0)	; is Sonic moving faster than -$400 upwards?
	blo.s	return_1A972		; if yes, return
	move.w	x_vel(a0),d0
	move.w	d0,d1
	asr.w	#5,d1		; d1 = x_velocity / 32
	beq.s	return_1A972	; return if d1 is 0
	bmi.s	Sonic_JumpPeakDecelerateLeft	; branch if moving left

; Sonic_JumpPeakDecelerateRight:
	sub.w	d1,d0	; reduce x velocity by d1
	bcc.s	+
	move.w	#0,d0
+
	move.w	d0,x_vel(a0)
	rts
;-------------------------------------------------------------
; loc_1A966:
Sonic_JumpPeakDecelerateLeft:
	sub.w	d1,d0	; reduce x velocity by d1
	bcs.s	+
	move.w	#0,d0
+
	move.w	d0,x_vel(a0)

return_1A972:
	rts
; End of subroutine Sonic_ChgJumpDir
; ===========================================================================

; ---------------------------------------------------------------------------
; Subroutine to prevent Sonic from leaving the boundaries of a level
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A974:
Sonic_LevelBound:
	move.l	x_pos(a0),d1
	move.w	x_vel(a0),d0
	ext.l	d0
	asl.l	#8,d0
	add.l	d0,d1
	swap	d1
	move.w	(Camera_Min_X_pos).w,d0
	cmpi.w  #0,d0
	beq.s   +
	subi.w  #40,d0
+
	addi.w	#$10,d0
	cmp.w	d1,d0			; has Sonic touched the left boundary?
	bhi.s	Sonic_Boundary_Sides	; if yes, branch
	move.w	(Camera_Max_X_pos).w,d0
	addi.w	#320+40-24,d0		; screen width - Sonic's width_pixels
	tst.b	(Current_Boss_ID).w
	bne.s	+
	addi.w	#$40,d0
+
	cmp.w	d1,d0			; has Sonic touched the right boundary?
	bls.s	Sonic_Boundary_Sides	; if yes, branch

; loc_1A9A6:
Sonic_Boundary_CheckBottom:
	move.w	(Camera_Max_Y_pos_now).w,d0
	addi.w	#$E0,d0
	cmp.w	y_pos(a0),d0		; has Sonic touched the bottom boundary?
	blt.s	Sonic_Boundary_Bottom	; if yes, branch
	rts
; ---------------------------------------------------------------------------
; https://info.sonicretro.org/SCHG_How-to:Disable_floor_collision_while_dying
Sonic_Boundary_Bottom:
	lea	0.w,a2			; NAT: Make the code below wont crash
	addq.l    #4,sp
	jmpto	(KillCharacter).l, JmpTo_KillCharacter
; ===========================================================================

; loc_1A9BA:
Sonic_Boundary_Sides:
	move.w	d0,x_pos(a0)
	move.w	#0,2+x_pos(a0) ; subpixel x
	move.w	#0,x_vel(a0)
	move.w	#0,inertia(a0)
	bra.s	Sonic_Boundary_CheckBottom
; ===========================================================================

; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to start rolling when he's moving
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1A9D2:
Sonic_Roll:
    if status_sec_isSliding = 7
	tst.b	status_secondary(a0)
	bmi.s	Obj_Sonic_NoRoll
    else
	btst	#status_sec_isSliding,status_secondary(a0)
	bne.s	Obj_Sonic_NoRoll
    endif

	cmpi.b	#2,(Option_PhysicsStyle).w
	beq.s	Sonic_Roll_SlowDucking

	cmpi.b	#4,(Option_PhysicsStyle).w
	beq.s	Sonic_Roll_SlowDucking

	cmpi.b	#5,(Option_PhysicsStyle).w
	beq.s	Sonic_Roll_SlowDucking
	
	bra.s	Sonic_Roll_NoSlowDucking

Sonic_Roll_SlowDucking:
	btst	#button_down,(Ctrl_1_Held_Logical).w ; is down being pressed?
	beq.s   Obj_Sonic_NoRoll               ; if not, branch
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_left_mask|button_right_mask,d0 ; is left/right being pressed?
	bne.s	Obj_Sonic_NoRoll	; if yes, branch
	mvabs.w	inertia(a0),d0
	cmpi.w   #$100,d0               ; is Sonic moving at $100 speed or faster?
	bhi.s   Obj_Sonic_ChkRoll               ; if yes, branch
	move.b   #AniIDSonAni_Duck,anim(a0)       ; use "ducking" animation
; return_1A9F8:
Obj_Sonic_NoRoll:
	rts

Sonic_Roll_NoSlowDucking:
	mvabs.w	inertia(a0),d0
	cmpi.w	#$80,d0		; is Sonic moving at $80 speed or faster?
	blo.s	Obj_Sonic_NoRoll	; if not, branch
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_left_mask|button_right_mask,d0 ; is left/right being pressed?
	bne.s	Obj_Sonic_NoRoll	; if yes, branch
	btst	#button_down,(Ctrl_1_Held_Logical).w ; is down being pressed?
	bne.s	Obj_Sonic_ChkRoll			; if yes, branch
	rts

; ---------------------------------------------------------------------------
; loc_1A9FA:
Obj_Sonic_ChkRoll:
	btst	#Status_Roll,status(a0)	; is Sonic already rolling?
	beq.s	Obj_Sonic_DoRoll	; if not, branch
	rts

; ---------------------------------------------------------------------------
; loc_1AA04:
Obj_Sonic_DoRoll:
	bset	#Status_Roll,status(a0)
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)	; use "rolling" animation
	addq.w	#5,y_pos(a0)
	sfx	sfx_Roll			; play rolling sound
	tst.w	inertia(a0)
	bne.s	return_1AA36
	move.w	#$200,inertia(a0)

return_1AA36:
	rts
; End of function Sonic_Roll


; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to jump
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AA38:
Sonic_Jump:
	move.b	(Ctrl_1_Press_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0 ; is A, B or C pressed?
	beq.w	return_1AAE6	; if not, return
	moveq	#0,d0
	move.b	angle(a0),d0
	addi.b	#$80,d0
	bsr.w	CalcRoomOverHead
	cmpi.w	#6,d1			; does Sonic have enough room to jump?
	blt.w	return_1AAE6		; if not, branch
	move.w	#$680,d2
	tst.b	(Super_Sonic_flag).w
	beq.s	+
	move.w	#$800,d2	; set higher jump speed if super
+
	btst	#6,status(a0)	; Test if underwater
	beq.s	+
	move.w	#$380,d2	; set lower jump speed if under
+
	; HJW: If in cutscene, skip Knux jump height (for WFZ cutscene)
	tst.b	(Control_Locked).w
	bne.w	+

	; HJW: Set lower jump speed for Knux
	cmpi.l	#Obj_Knuckles,id(a0)
	bne.s	+
	subi.w	#$80,d2
+
	moveq	#0,d0
	move.b	angle(a0),d0
	subi.b	#$40,d0
	jsr	(CalcSine).l
	muls.w	d2,d1
	asr.l	#8,d1
	add.w	d1,x_vel(a0)	; make Sonic jump (in X... this adds nothing on level ground)
	muls.w	d2,d0
	asr.l	#8,d0
	add.w	d0,y_vel(a0)	; make Sonic jump (in Y)
	bset	#1,status(a0)
	bclr	#5,status(a0)
	addq.l	#4,sp
	move.b	#1,jumping(a0)
	clr.b	stick_to_convex(a0)

	sfx	sfx_Jump	; play jumping sound
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	btst	#Status_Roll,status(a0)
	bne.s	Sonic_RollJump

	move.b	#AniIDSonAni_Roll,anim(a0)	; use "jumping" animation
	bset	#Status_Roll,status(a0)
	addq.w	#5,y_pos(a0)

return_1AAE6:
	rts
; ---------------------------------------------------------------------------
; loc_1AAE8:
Sonic_RollJump:
	cmpi.b	#3,(Option_PhysicsStyle).w
	bge.s	+
	bset	#Status_RollJump,status(a0)	; set the rolling+jumping flag
+
	rts
; End of function Sonic_Jump


; ---------------------------------------------------------------------------
; Subroutine letting Sonic control the height of the jump
; when the jump button is released
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; ===========================================================================
; loc_1AAF0:
Sonic_JumpHeight:
	tst.b	jumping(a0)	; is Sonic jumping?
	beq.s	Sonic_UpVelCap	; if not, branch

	move.w	#-$400,d1
	btst	#6,status(a0)	; is Sonic underwater?
	beq.s	+		; if not, branch
	move.w	#-$200,d1
+
	cmp.w	y_vel(a0),d1	; is Sonic going up faster than d1?
	ble.s	Sonic_InstaAndShieldMoves		; if not, branch
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0 ; is a jump button pressed?
	bne.s	+		; if yes, branch
	move.w	d1,y_vel(a0)	; immediately reduce Sonic's upward speed to d1
+
	rts
; ---------------------------------------------------------------------------
; loc_1AB22:
Sonic_UpVelCap:
	tst.b	pinball_mode(a0)	; is Sonic charging a spindash or in a rolling-only area?
	bne.s	return_1AB36		; if yes, return
	cmpi.w	#-$FC0,y_vel(a0)	; is Sonic moving up really fast?
	bge.s	return_1AB36		; if not, return
	move.w	#-$FC0,y_vel(a0)	; cap upward speed

return_1AB36:
	rts
; End of subroutine Sonic_JumpHeight


Sonic_InstaAndShieldMoves:
	; Disable all moves in 2P
	tst.w	(Two_player_mode).w
	bne.w	locret_11A14
	tst.b	double_jump_flag(a0)		; is Sonic currently performing a double jump?
	bne.w	locret_11A14			; if yes, branch
	move.b	(Ctrl_1_Press_logical).w,d0
	andi.b	#$70,d0				; are buttons A, B, or C being pressed?
	beq.w	locret_11A14			; if not, branch
	;tst.b	(Super_Sonic_flag).w	; check Super-state
	;beq.s	Sonic_PrimaryAbility		; if not in a super-state, branch
	;bmi.w	Sonic_HyperDash			; if Hyper, branch
	;move.b	#1,double_jump_flag(a0)
	;rts
; ---------------------------------------------------------------------------

Sonic_PrimaryAbility:
	cmpi.b	#4,(Option_SonicAbility).l
	beq.w	Sonic_HomingAttack
	cmpi.b	#5,(Option_SonicAbility).l
	beq.w	Sonic_ShieldControl

Sonic_FireShield:
	tst.b	(Option_InvincShields).w	; Allow shields while invinc?
	bne.s	+							; If so, branch
	btst	#Status_Invincible,status_secondary(a0)	; first, does Sonic have invincibility?
	bne.w	Sonic_DropDashStart				; if yes, branch
+
	btst	#Status_FireShield,status_secondary(a0)	; does Sonic have a Fire Shield?
	beq.w	Sonic_LightningShield			; if not, branch

Sonic_FireShieldDo:
	; Check again because shield control might be active
	btst	#Status_FireShield,status_secondary(a0)	; does Sonic have a Fire Shield?
	beq.s	+			; if not, branch
	move.b	#1,(Shield+anim).w
+
	; Assist check
	cmpi.l	#Obj_Tails,(Sidekick+id).w
	bne.s	+
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_up_mask,d0
	beq.w	+
	rts
+
	bclr	#Status_RollJump,status(a0)
	move.b	#1,double_jump_flag(a0)
	move.w	#$800,d0

	; HJW: "Joey" shield tweaks
	cmpi.b	#2,(Option_ShieldAbilityStyle).l
	bne.s	+
	mvabs.w	x_vel(a0),d1
	cmpi.w	#$500,d1
	blt.s	+
	move.w	d1,d0
	lsr.w	#2,d1
	add.w	d1,d0
+
	btst	#Status_Facing,status(a0)		; is Sonic facing left?
	beq.s	loc_11958				; if not, branch
	neg.w	d0					; reverse speed value, moving Sonic left

loc_11958:
	move.w	d0,x_vel(a0)		; apply velocity...
	move.w	d0,ground_vel(a0)	; ...both ground and air
	move.w	#0,y_vel(a0)		; kill y-velocity
	cmpi.b	#2,(Option_CameraStyle).w	; sonic cd camera
	beq.s	+
	move.w	#$2000,(Horiz_scroll_delay_val).w
	bsr.w	Reset_Player_Position_Array
+
	sfx		sfx_FireAttack			; play Fire Shield attack sound
	rts
; ---------------------------------------------------------------------------

Sonic_LightningShield:
	btst	#Status_LtngShield,status_secondary(a0)	; does Sonic have a Lightning Shield?
	beq.s	Sonic_BubbleShield			; if not, branch

Sonic_LightningShieldDo:
	; Check again because shield control might be active
	btst	#Status_LtngShield,status_secondary(a0)	; does Sonic have a Lightning Shield?
	beq.s	+			; if not, branch
	move.b	#1,(Shield+anim).w
+
	bclr	#Status_RollJump,status(a0)
	move.b	#1,double_jump_flag(a0)
	move.w	#-$580,y_vel(a0)	; bounce Sonic up, creating the double jump effect
	clr.b	jumping(a0)
	sfx		sfx_ElectricAttack			; play Lightning Shield attack sound
	rts
; ---------------------------------------------------------------------------

Sonic_BubbleShield:
	btst	#Status_BublShield,status_secondary(a0)	; does Sonic have a Bubble Shield
	beq.w	Sonic_InstaAndDrop			; if not, branch

Sonic_BubbleShieldDo:
	; Check again because shield control might be active
	btst	#Status_BublShield,status_secondary(a0)	; does Sonic have a Bubble Shield?
	beq.s	+			; if not, branch
	move.b	#1,(Shield+anim).w
+
	bclr	#Status_RollJump,status(a0)
	move.b	#1,double_jump_flag(a0)
	cmpi.b	#2,(Option_ShieldAbilityStyle).l
	bne.s	+
	cmpi.w	#$800,y_vel(a0)
	blt.s	+
	moveq	#0,d0
	move.w	y_vel(a0),d0
	asr.w	#3,d0
	add.w	d0,y_vel(a0)
	bra.s	++
+
	move.w	#$800,y_vel(a0)		; force Sonic down
+
	sfx		sfx_BubbleAttack			; play Bubble Shield attack sound

	tst.b	(Option_ShieldAbilityStyle).l
	bne.s	+
	move.w	#0,x_vel(a0)		; halt horizontal speed...
	move.w	#0,ground_vel(a0)	; ...both ground and air
	rts
+
	asr.w	#1,x_vel(a0)
	asr.w	#1,ground_vel(a0)
	rts

Sonic_HomingAttack:
	; Assist check
	cmpi.l	#Obj_Tails,(Sidekick+id).w
	bne.s	+
	move.b	(Ctrl_1_Held_Logical).w,d0
	andi.b	#button_up_mask,d0
	beq.w	+
	rts
+
	jsr		FindClosestTargetInFront
	bclr	#Status_RollJump,status(a0)
	move.l	a1,(HomingAttack_Object).l
	move.l	#Obj_HyperSonicKnux_Trail,(HyperSonicKnux_Trail+id).w
	sfx		sfx_Thok
	tst.l	(HomingAttack_Object).l
	bne.s	+
	move.w	#$800,x_vel(a0)
	clr.w	y_vel(a0)
	btst	#Status_Facing,status(a0)		; is Sonic facing left?
	beq.s	+				; if not, branch
	neg.w	x_vel(a0)					; reverse speed value, moving Sonic left
+
	move.b	#1,double_jump_flag(a0)
	rts

; ---------------------------------------------------------------------------

Sonic_InstaAndDrop:
	bsr.s	Sonic_InstaShield

Sonic_DropDashStart:
	cmpi.b	#2,(Option_SonicAbility).l
	beq.s	+
	cmpi.b	#3,(Option_SonicAbility).l
	beq.s	+
	rts
+
	bclr	#Status_RollJump,status(a0)
	move.b	#1,double_jump_flag(a0)
	move.b	#20,glidemode(a0)
	rts

Sonic_InstaShield:
	cmpi.b	#1,(Option_SonicAbility).l
	beq.s	Sonic_InstaShieldCont
	cmpi.b	#3,(Option_SonicAbility).l
	beq.s	Sonic_InstaShieldCont
	rts

Sonic_InstaShieldCont:
	btst	#Status_Shield,status_secondary(a0)	; does Sonic have an S2 shield (The Elementals were already filtered out at this point)?
	bne.s	locret_11A14				; if yes, branch
	move.b	#1,(Shield+anim).w
	bclr	#Status_RollJump,status(a0)
	move.b	#1,double_jump_flag(a0)
	sfx		sfx_InstaAttack			; play Insta-Shield sound
	rts

locret_11A14:
	rts

Sonic_ShieldControl:
	btst	#button_up,(Ctrl_1_Held_logical).w
	bne.w	Sonic_LightningShieldDo
	btst	#button_down,(Ctrl_1_Held_logical).w
	beq.w	Sonic_FireShieldDo
	bsr.w	Sonic_BubbleShieldDo
	move.b	#2,double_jump_flag(a0)
	rts

; ---------------------------------------------------------------------------

Sonic_CheckGoSuper:
	move.b	(Ctrl_6btn_1_Press_Logical).w,d0
	andi.b	#button_Y_mask,d0 ; is Y pressed?
	beq.w	return_1ABA4	; if not, return
	tst.b	(Super_Sonic_flag).w
	bne.w	Sonic_RevertToNormal
	
	cmpi.b	#7,(Emerald_count).w	; does Sonic have exactly 7 emeralds?
	bne.w	return_1ABA4			; if not, branch
	tst.b	(Update_HUD_timer).w	; has Sonic reached the end of the act?
	beq.w	return_1ABA4			; if yes, branch
	cmpi.w	#50,(Ring_count).w		; does Sonic have at least 50 rings?
	blo.w	return_1ABA4			; if not, branch
	bclr    #2,status(a0)
	bclr    #4,status(a0)
	move.b  #$13,y_radius(a0)
	move.b  #9,x_radius(a0)

Sonic_Transform:
	; HJW: not using a0 so that it can be called from monitor and still work
	move.b	#1,(Super_Sonic_palette).w
	move.b	#$F,(Palette_timer).w
	move.b	#1,(Super_Sonic_flag).w
	move.b	#$81,(MainCharacter+obj_control).w
	move.b	#AniIDSupSonAni_Transform,(MainCharacter+anim).w			; use transformation animation
	move.l	#Obj_SuperSonicStars,(SuperSonicStars+id).w ; load Obj_SuperSonicStars (super sonic stars object) at $FFFFD040
	move.w	#0,(MainCharacter+invincibility_time).w
	bset	#status_sec_isInvincible,(MainCharacter+status_secondary).w	; make Sonic invincible
	sfx	sfx_Transform				; Play transformation sound effect.

	move.l	a0,-(sp)		; Backup a0
	move.l	#MainCharacter,a0
	lea		(Sonic_top_speed).w,a2
	jsr		ApplySpeedSettings	; Fetch Speed settings
	move.l	(sp)+,a0		; Restore a0

	tst.b	(Option_SuperMusic).w	; Allow super music?
	bne.s	return_1ABA4			; If not, branch
	music	mus_SuperSonic				; load the Super Sonic song and return

; ---------------------------------------------------------------------------
return_1ABA4:
	rts
; End of subroutine Sonic_CheckGoSuper


; ---------------------------------------------------------------------------
; Subroutine doing the extra logic for Super Sonic
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1ABA6:
Sonic_Super:
	tst.b	(Super_Sonic_flag).w	; Ignore all this code if not Super Sonic
	beq.w	return_1AC3C
	tst.b	(Update_HUD_timer).w
	beq.s	Sonic_RevertToNormal ; ?
	subq.w	#1,(Super_Sonic_frame_count).w
	bpl.w	return_1AC3C
	move.w	#60,(Super_Sonic_frame_count).w	; Reset frame counter to 60
	tst.w	(Ring_count).w
	beq.s	Sonic_RevertToNormal
	ori.b	#1,(Update_HUD_rings).w
	cmpi.w	#1,(Ring_count).w
	beq.s	+
	cmpi.w	#10,(Ring_count).w
	beq.s	+
	cmpi.w	#100,(Ring_count).w
	bne.s	++
+
	ori.b	#$80,(Update_HUD_rings).w
+
	subq.w	#1,(Ring_count).w
	bne.s	return_1AC3C
; loc_1ABF2:
Sonic_RevertToNormal:
	move.b	#0,(MainCharacter+obj_control).w	; restore Sonic's movement
	move.b	#2,(Super_Sonic_palette).w	; Remove rotating palette
	move.w	#$28,(Palette_frame).w
	move.b	#0,(Super_Sonic_flag).w
	move.b	#1,next_anim(a0)	; Change animation back to normal ?
	move.w	#1,invincibility_time(a0)	; Remove invincibility
	lea		(Sonic_top_speed).w,a2	; Load Sonic_top_speed into a2
	jsr		ApplySpeedSettings	; Fetch Speed settings

return_1AC3C:
	rts
; End of subroutine Sonic_Super

Sonic_CheckPeelout:
	; Disable all moves in 2P
	tst.w	(Two_player_mode).w
	bne.w	return_Peelout1
	cmpi.b	#1,(Option_PeelOut).w
	beq.s	+
	cmpi.b	#3,(Option_PeelOut).w
	beq.s	+
	rts
+
	cmpi.b	#2,spindash_flag(a0)
	beq.s	Sonic_UpdatePeelout
	
	; Don't start peelout if not looking up or not pressing ABC
	cmpi.b	#AniIDSonAni_LookUp,anim(a0)
	bne.s	return_Peelout1
	
	move.b	(Ctrl_1_Press_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0
	beq.w	return_Peelout1
	
	; Play rev sound
	sfx	sfx_Spindash
	
	; Start peelout state
	move.b	#2,spindash_flag(a0)
	move.w	#0,spindash_counter(a0)
	
	; Push stack pointer back so we don't return to the movement function
	addq.l	#4,sp

return_Peelout1:
	rts

Sonic_UpdatePeelout:
	; Increment counter up to 30 (charge cap)
	cmpi.w	#30,spindash_counter(a0)
	bcc.s	Sonic_Charged
	addi.w	#1,spindash_counter(a0)
	
	; Do a failed release if up is released
	btst	#button_up,(Ctrl_1_Held_Logical).w
	bne.s	Sonic_NoRelease
	
	move.b	#0,spindash_flag(a0)
	move.w	#0,inertia(a0)
	; TODO: Stop charging sound
	rts

Sonic_Charged:
	; Do a proper release if up is released
	btst	#button_up,(Ctrl_1_Held_Logical).w
	bne.s	Sonic_NoRelease
	
	move.b	#0,spindash_flag(a0)
	sfx	sfx_Dash
	rts

Sonic_NoRelease:
	; Push stack pointer back so we don't return to the movement function
	addq.l	#4,sp
	
	; Make sure we're playing the running animation
	move.b	#AniIDSonAni_Walk,anim(a0)
	bclr	#5,status(a0)
	
	; Get peelout speed cap
	move.w	(Sonic_top_speed).w,d1
	asl.w	d1
	
	; Reduce cap if using speed shoes
	btst	#status_sec_hasSpeedShoes,status_secondary(a0)
	beq.s	Sonic_NoSpeedShoes
	move.w	(Sonic_top_speed).w,d0
	asr.w	d0
	sub.w	d0,d1

Sonic_NoSpeedShoes:
	; Accelerate left or right depending on our facing direction
	move.w	#$64,d0
	move.w	inertia(a0),d2
	
	btst	#0,status(a0)
	beq.s	Sonic_PeeloutRight
	
	sub.w	d0,d2
	neg.w	d1
	cmp.w	d1,d2
	bge.s	Sonic_CopySpeed
	move.w	d1,d2
	bra.s	Sonic_CopySpeed

Sonic_PeeloutRight:
	add.w	d0,d2
	cmp.w	d1,d2
	ble.s	Sonic_CopySpeed
	move.w	d1,d2

Sonic_CopySpeed:
	move.w	d2,inertia(a0)
	rts

; ---------------------------------------------------------------------------
; Subroutine to check for starting to charge a spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AC3E:
Sonic_CheckSpindash:
	tst.b	spindash_flag(a0)
	bne.s	Sonic_UpdateSpindash
	cmpi.b	#AniIDSonAni_Duck,anim(a0)
	bne.s	return_1AC8C
	move.b	(Ctrl_1_Press_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0
	beq.w	return_1AC8C
	move.b	#AniIDSonAni_Spindash,anim(a0)
	sfx	sfx_Spindash
	addq.l	#4,sp
	move.b	#1,spindash_flag(a0)
	move.w	#0,spindash_counter(a0)
	cmpi.b	#$C,air_left(a0)	; if he's drowning, branch to not make dust
	blo.s	+
	move.b	#2,(Sonic_Dust+anim).w
+
	bsr.w	Sonic_LevelBound
	bsr.w	AnglePos

return_1AC8C:
	rts
; End of subroutine Sonic_CheckSpindash


; ---------------------------------------------------------------------------
; Subrouting to update an already-charging spindash
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AC8E:
Sonic_UpdateSpindash:
	move.b	#AniIDSonAni_Spindash,anim(a0)

	move.b	(Ctrl_1_Held_Logical).w,d0
	btst	#button_down,d0
	bne.w	Sonic_ChargingSpindash

	; unleash the charged spindash and start rolling quickly:
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)
	addq.w	#5,y_pos(a0)	; add the difference between Sonic's rolling and standing heights
	move.b	#0,spindash_flag(a0)
	moveq	#0,d0
	move.b	spindash_counter(a0),d0
	add.w	d0,d0
	move.w	SpindashSpeeds(pc,d0.w),inertia(a0)
	tst.b	(Super_Sonic_flag).w
	beq.s	+
	move.w	SpindashSpeedsSuper(pc,d0.w),inertia(a0)
+
	move.w	inertia(a0),d0
	subi.w	#$800,d0
	add.w	d0,d0
	andi.w	#$1F00,d0
	neg.w	d0
	addi.w	#$2000,d0
	cmpi.b	#2,(Option_CameraStyle).w	; sonic cd camera
	beq.s	+
	move.w	d0,(Horiz_scroll_delay_val).w
+
	btst	#0,status(a0)
	beq.s	+
	neg.w	inertia(a0)
+
	bset	#Status_Roll,status(a0)
	move.b	#0,(Sonic_Dust+anim).w
	sfx	sfx_Dash
	bra.s	Obj_Sonic_Spindash_ResetScr
; ===========================================================================
; word_1AD0C:
SpindashSpeeds:
	dc.w  $800	; 0
	dc.w  $880	; 1
	dc.w  $900	; 2
	dc.w  $980	; 3
	dc.w  $A00	; 4
	dc.w  $A80	; 5
	dc.w  $B00	; 6
	dc.w  $B80	; 7
	dc.w  $C00	; 8
; word_1AD1E:
SpindashSpeedsSuper:
	dc.w  $B00	; 0
	dc.w  $B80	; 1
	dc.w  $C00	; 2
	dc.w  $C80	; 3
	dc.w  $D00	; 4
	dc.w  $D80	; 5
	dc.w  $E00	; 6
	dc.w  $E80	; 7
	dc.w  $F00	; 8
; ===========================================================================
; loc_1AD30:
Sonic_ChargingSpindash:			; If still charging the dash...
	tst.w	spindash_counter(a0)
	beq.s	+
	move.w	spindash_counter(a0),d0
	lsr.w	#5,d0
	sub.w	d0,spindash_counter(a0)
	bcc.s	+
	move.w	#0,spindash_counter(a0)
+
	move.b	(Ctrl_1_Press_Logical).w,d0
	andi.b	#button_B_mask|button_C_mask|button_A_mask,d0
	beq.w	Obj_Sonic_Spindash_ResetScr
	move.w	#(AniIDSonAni_Spindash<<8),anim(a0)
	sfx	sfx_Spindash
	addi.w	#$200,spindash_counter(a0)
	cmpi.w	#$800,spindash_counter(a0)
	blo.s	Obj_Sonic_Spindash_ResetScr
	move.w	#$800,spindash_counter(a0)

; loc_1AD78:
Obj_Sonic_Spindash_ResetScr:
	addq.l	#4,sp
	cmpi.w	#(224/2)-16,(Camera_Y_pos_bias).w
	beq.s	loc_1AD8C
	bhs.s	+
	addq.w	#4,(Camera_Y_pos_bias).w
+	subq.w	#2,(Camera_Y_pos_bias).w

loc_1AD8C:
	bsr.w	Sonic_LevelBound
	bsr.w	AnglePos
	rts
; End of subroutine Sonic_UpdateSpindash


; ---------------------------------------------------------------------------
; Subroutine to slow Sonic walking up a slope
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AD96:
Sonic_SlopeResist:
	cmpi.b	#5,(Option_PhysicsStyle).w
	beq.w	+
	cmpi.b	#2,(Option_PhysicsStyle).w
	bne.w	++
+
		move.b	angle(a0),d0
		addi.b	#$60,d0
		cmpi.b	#-$40,d0
		bcc.s	locret_12D00
		move.b	angle(a0),d0
		jsr	(CalcSine).l
		muls.w	#$20,d0
		asr.l	#8,d0
		tst.w	inertia(a0)
		beq.s	loc_12D02
		bmi.s	loc_12CFC
		tst.w	d0
		beq.s	locret_12CFA
		add.w	d0,inertia(a0)

locret_12CFA:
		rts
; ---------------------------------------------------------------------------

loc_12CFC:
		add.w	d0,inertia(a0)

locret_12D00:
		rts
; ---------------------------------------------------------------------------

loc_12D02:
		move.w	d0,d1
		bpl.s	loc_12D08
		neg.w	d1

loc_12D08:
		cmpi.w	#$D,d1
		bcs.s	locret_12D00
		add.w	d0,inertia(a0)
		rts
; End of subroutine Sonic_SlopeResist

+
	move.b	angle(a0),d0
	addi.b	#$60,d0
	cmpi.b	#$C0,d0
	bhs.s	return_1ADCA
	move.b	angle(a0),d0
	jsr	(CalcSine).l
	muls.w	#$20,d0
	asr.l	#8,d0
	tst.w	inertia(a0)
	beq.s	return_1ADCA
	bmi.s	loc_1ADC6
	tst.w	d0
	beq.s	+
	add.w	d0,inertia(a0)	; change Sonic's $14
+
	rts
; ---------------------------------------------------------------------------

loc_1ADC6:
	add.w	d0,inertia(a0)

return_1ADCA:
	rts

; ---------------------------------------------------------------------------
; Subroutine to push Sonic down a slope while he's rolling
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1ADCC:
Sonic_RollRepel:
	move.b	angle(a0),d0
	addi.b	#$60,d0
	cmpi.b	#$C0,d0
	bhs.s	return_1AE06
	move.b	angle(a0),d0
	jsr	(CalcSine).l
	muls.w	#$50,d0
	asr.l	#8,d0
	tst.w	inertia(a0)
	bmi.s	loc_1ADFC
	tst.w	d0
	bpl.s	loc_1ADF6
	asr.l	#2,d0

loc_1ADF6:
	add.w	d0,inertia(a0)
	rts
; ===========================================================================

loc_1ADFC:
	tst.w	d0
	bmi.s	loc_1AE02
	asr.l	#2,d0

loc_1AE02:
	add.w	d0,inertia(a0)

return_1AE06:
	rts
; End of function Sonic_RollRepel

; ---------------------------------------------------------------------------
; Subroutine to push Sonic down a slope
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AE08:
Sonic_SlopeRepel:
	cmpi.b	#5,(Option_PhysicsStyle).w
	beq.w	Sonic_S2SlopeRepel
	cmpi.b	#2,(Option_PhysicsStyle).w
	bne.w	+++
Sonic_S2SlopeRepel:	
		cmpi.b	#$2,anim(a0)
		beq.w	++	
		cmpi.b	#$D,anim(a0)
		beq.w	++
		tst.w	x_vel(a0)					; is character moving?
		beq.w	++							; if no, branch	
		btst	#1,(Ctrl_1_Held_Logical).w	; is down being pressed?
		bne.w	+							; if yes, branch
		move.b	#0,anim(a0)					; make them walk
		bra.w	++
+ ; note - some people might prefer ducking over rolling... Maybe make a preference option for that?			
		move.w   inertia(a0),d0
		bpl.s    Slope_ChkRollSpeed
		neg.w    d0

Slope_ChkRollSpeed: 
		cmpi.w    #$100,d0        ; is Sonic moving at $100 speed or faster?
		bhs.s    Slope_DoRoll    ; if not, branch
		move.b #$8,anim(a0) ; use ducking animation
		bra.w	+

Slope_DoRoll:
		jsr	Obj_Sonic_DoRoll
+	; the "real" start to SlopeRepel
		tst.b	stick_to_convex(a0)
		bne.s	locret_12D94
		tst.w	move_lock(a0)
		bne.s	loc_12DAC
		move.b	angle(a0),d0
		addi.b	#$18,d0
		cmpi.b	#$30,d0
		bcs.s	locret_12D94
		move.w	inertia(a0),d0
		bpl.s	loc_12D74
		neg.w	d0

loc_12D74:
		cmpi.w	#$280,d0
		bcc.s	locret_12D94
		move.w	#$1E,move_lock(a0)
		move.b	angle(a0),d0
		addi.b	#$30,d0
		cmpi.b	#$60,d0
		bcs.s	loc_12D96
		bset	#1,status(a0) ; in air status set

locret_12D94:
		rts
; ---------------------------------------------------------------------------

loc_12D96:
		cmpi.b	#$30,d0
		bcs.s	loc_12DA4
		addi.w	#$80,inertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_12DA4:
		subi.w	#$80,inertia(a0)
		rts
; ---------------------------------------------------------------------------

loc_12DAC:
		subq.w	#1,move_lock(a0)
		rts

+
	nop
	tst.b	stick_to_convex(a0)
	bne.s	return_1AE42
	tst.w	move_lock(a0)
	bne.s	loc_1AE44
	move.b	angle(a0),d0
	addi.b	#$20,d0
	andi.b	#$C0,d0
	beq.s	return_1AE42
	mvabs.w	inertia(a0),d0
	cmpi.w	#$280,d0
	bhs.s	return_1AE42
	clr.w	inertia(a0)
	bset	#1,status(a0)
	move.w	#$1E,move_lock(a0)

return_1AE42:
	rts
; ===========================================================================

loc_1AE44:
	subq.w	#1,move_lock(a0)
	rts		
; End of function Sonic_SlopeRepel

; ---------------------------------------------------------------------------
; Subroutine to return Sonic's angle to 0 as he jumps
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AE4A:
Sonic_JumpAngle:
	move.b	angle(a0),d0	; get Sonic's angle
	beq.s	Sonic_JumpFlip	; if already 0, branch
	bpl.s	loc_1AE5A	; if higher than 0, branch

	addq.b	#2,d0		; increase angle
	bcc.s	BranchTo_Sonic_JumpAngleSet
	moveq	#0,d0

BranchTo_Sonic_JumpAngleSet
	bra.s	Sonic_JumpAngleSet
; ===========================================================================

loc_1AE5A:
	subq.b	#2,d0		; decrease angle
	bcc.s	Sonic_JumpAngleSet
	moveq	#0,d0

; loc_1AE60:
Sonic_JumpAngleSet:
	move.b	d0,angle(a0)
; End of function Sonic_JumpAngle
	; continue straight to Sonic_JumpFlip

; ---------------------------------------------------------------------------
; Updates Sonic's secondary angle if he's tumbling
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AE64:
Sonic_JumpFlip:
	move.b	flip_angle(a0),d0
	beq.s	return_1AEA8
	tst.w	inertia(a0)
	bmi.s	Sonic_JumpLeftFlip
; loc_1AE70:
Sonic_JumpRightFlip:
	move.b	flip_speed(a0),d1
	add.b	d1,d0
	bcc.s	BranchTo_Sonic_JumpFlipSet
	subq.b	#1,flips_remaining(a0)
	bcc.s	BranchTo_Sonic_JumpFlipSet
	move.b	#0,flips_remaining(a0)
	moveq	#0,d0

BranchTo_Sonic_JumpFlipSet
	bra.s	Sonic_JumpFlipSet
; ===========================================================================
; loc_1AE88:
Sonic_JumpLeftFlip:
	tst.b	flip_turned(a0)
	bne.s	Sonic_JumpRightFlip
	move.b	flip_speed(a0),d1
	sub.b	d1,d0
	bcc.s	Sonic_JumpFlipSet
	subq.b	#1,flips_remaining(a0)
	bcc.s	Sonic_JumpFlipSet
	move.b	#0,flips_remaining(a0)
	moveq	#0,d0
; loc_1AEA4:
Sonic_JumpFlipSet:
	move.b	d0,flip_angle(a0)

return_1AEA8:
	rts
; End of function Sonic_JumpFlip

; ---------------------------------------------------------------------------
; Subroutine for Sonic to interact with the floor and walls when he's in the air
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1AEAA: Sonic_Floor:
Sonic_DoLevelCollision:
	move.l	#Primary_Collision,(Collision_addr).w
	cmpi.b	#$C,top_solid_bit(a0)
	beq.s	+
	move.l	#Secondary_Collision,(Collision_addr).w
+
	move.b	lrb_solid_bit(a0),d5
	move.w	x_vel(a0),d1
	move.w	y_vel(a0),d2
	jsr	(CalcAngle).l
	subi.b	#$20,d0
	andi.b	#$C0,d0
	cmpi.b	#$40,d0
	beq.w	Sonic_HitLeftWall
	cmpi.b	#$80,d0
	beq.w	Sonic_HitCeilingAndWalls
	cmpi.b	#$C0,d0
	beq.w	Sonic_HitRightWall
	bsr.w	CheckLeftWallDist
	tst.w	d1
	bpl.s	+
	sub.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0) ; stop Sonic since he hit a wall
+
	bsr.w	CheckRightWallDist
	tst.w	d1
	bpl.s	+
	add.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0) ; stop Sonic since he hit a wall
+
	bsr.w	Sonic_CheckFloor
	tst.w	d1
	bpl.w	return_1AF8A
	move.b	y_vel(a0),d2
	addq.b	#8,d2
	neg.b	d2
	cmp.b	d2,d1
	bge.s	+
	cmp.b	d2,d0
	blt.s	return_1AF8A
+
	add.w	d1,y_pos(a0)
	move.b	d3,angle(a0)
	move.b	d3,d0
	addi.b	#$20,d0
	andi.b	#$40,d0
	bne.s	loc_1AF68
	move.b	d3,d0
	addi.b	#$10,d0
	andi.b	#$20,d0
	beq.s	loc_1AF5A
	asr	y_vel(a0)
	bra.s	loc_1AF7C
; ===========================================================================

loc_1AF5A:
	move.w	#0,y_vel(a0)
	move.w	x_vel(a0),inertia(a0)
	bsr.w	Sonic_ResetOnFloor
	bsr.w	Sonic_ResetOnFloor_Ability
	rts
; ===========================================================================

loc_1AF68:
	move.w	#0,x_vel(a0) ; stop Sonic since he hit a wall
	; HJW: Mania doesn't cap this
	cmpi.b	#3,(Option_PhysicsStyle).w
	blt.s	loc_1AF7C
	cmpi.w	#$FC0,y_vel(a0)
	ble.s	loc_1AF7C
	move.w	#$FC0,y_vel(a0)

loc_1AF7C:
	bsr.w	Sonic_ResetOnFloor
	move.w	y_vel(a0),inertia(a0)
	tst.b	d3
	bpl.s	+
	neg.w	inertia(a0)
+
	bsr.w	Sonic_ResetOnFloor_Ability

return_1AF8A:
	rts
; ===========================================================================
; loc_1AF8C:
Sonic_HitLeftWall:
	bsr.w	CheckLeftWallDist
	tst.w	d1
	bpl.s	Sonic_HitCeiling ; branch if distance is positive (not inside wall)
	sub.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0) ; stop Sonic since he hit a wall
	move.w	y_vel(a0),inertia(a0)
	rts
; ===========================================================================
; loc_1AFA6:
Sonic_HitCeiling:
	bsr.w	Sonic_CheckCeiling
	tst.w	d1
	bpl.s	Sonic_HitFloor ; branch if distance is positive (not inside ceiling)
	sub.w	d1,y_pos(a0)
	tst.w	y_vel(a0)
	bpl.s	return_1AFBE
	move.w	#0,y_vel(a0) ; stop Sonic in y since he hit a ceiling

return_1AFBE:
	rts
; ===========================================================================
; loc_1AFC0:
Sonic_HitFloor:
	tst.w	y_vel(a0)
	bmi.s	return_1AFE6
	bsr.w	Sonic_CheckFloor
	tst.w	d1
	bpl.s	return_1AFE6
	add.w	d1,y_pos(a0)
	move.b	d3,angle(a0)
	move.w	#0,y_vel(a0)
	move.w	x_vel(a0),inertia(a0)
	bsr.w	Sonic_ResetOnFloor
	bsr.w	Sonic_ResetOnFloor_Ability

return_1AFE6:
	rts
; ===========================================================================
; loc_1AFE8:
Sonic_HitCeilingAndWalls:
	bsr.w	CheckLeftWallDist
	tst.w	d1
	bpl.s	+
	sub.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0)	; stop Sonic since he hit a wall
+
	bsr.w	CheckRightWallDist
	tst.w	d1
	bpl.s	+
	add.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0)	; stop Sonic since he hit a wall
+
	bsr.w	Sonic_CheckCeiling
	tst.w	d1
	bpl.s	return_1B042
	sub.w	d1,y_pos(a0)
	move.b	d3,d0
	addi.b	#$20,d0
	andi.b	#$40,d0
	bne.s	loc_1B02C
	move.w	#0,y_vel(a0) ; stop Sonic in y since he hit a ceiling
	rts
; ===========================================================================

loc_1B02C:
	move.b	d3,angle(a0)
	move.w	y_vel(a0),inertia(a0)
	bsr.w	Sonic_ResetOnFloor
	tst.b	d3
	bpl.s	+
	neg.w	inertia(a0)
+
	bsr.w	Sonic_ResetOnFloor_Ability

return_1B042:
	rts
; ===========================================================================
; loc_1B044:
Sonic_HitRightWall:
	bsr.w	CheckRightWallDist
	tst.w	d1
	bpl.s	Sonic_HitCeiling2
	add.w	d1,x_pos(a0)
	move.w	#0,x_vel(a0) ; stop Sonic since he hit a wall
	move.w	y_vel(a0),inertia(a0)
	rts
; ===========================================================================
; identical to Sonic_HitCeiling...
; loc_1B05E:
Sonic_HitCeiling2:
	bsr.w	Sonic_CheckCeiling
	tst.w	d1
	bpl.s	Sonic_HitFloor2
	sub.w	d1,y_pos(a0)
	tst.w	y_vel(a0)
	bpl.s	return_1B076
	move.w	#0,y_vel(a0) ; stop Sonic in y since he hit a ceiling

return_1B076:
	rts
; ===========================================================================
; identical to Sonic_HitFloor...
; loc_1B078:
Sonic_HitFloor2:
	tst.w	y_vel(a0)
	bmi.s	return_1B09E
	bsr.w	Sonic_CheckFloor
	tst.w	d1
	bpl.s	return_1B09E
	add.w	d1,y_pos(a0)
	move.b	d3,angle(a0)
	move.w	#0,y_vel(a0)
	move.w	x_vel(a0),inertia(a0)
	bsr.w	Sonic_ResetOnFloor
	bsr.w	Sonic_ResetOnFloor_Ability

return_1B09E:
	rts
; End of function Sonic_DoLevelCollision



; ---------------------------------------------------------------------------
; Subroutine to reset Sonic's mode when he lands on the floor
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1B0A0:
Sonic_ResetOnFloor:
	tst.b	pinball_mode(a0)
	bne.w	Sonic_ResetOnFloor_Part3
;=====================================================================================================================
; if up is being held while landing from a momentumless jump, play look up animation. 
; allows for activiting peelout immediately
; however, to do so properly requires a frame perfect input... (enjoy, speedrunners!)
;=====================================================================================================================	
	btst	#button_up,(Ctrl_1_Held_Logical).w	; is up being pressed?
	beq.s	.CheckIfDucking				; if not, branch
	move.b	#7,anim(a0)				; use look up animation
	bra.s	Sonic_ResetOnFloor_Part2	
;=====================================================================================================================
; if down is being held while landing from a momentumless jump, play ducking animation. 
; allows for activiting spindash immediately
; however, to do so properly requires a frame perfect input... (enjoy, speedrunners!)
;=====================================================================================================================
	.CheckIfDucking:	
		btst	#button_down,(Ctrl_1_Held_Logical).w	; is down being pressed?
		beq.s	.ReturnToWalkRunDash			; if not, branch
		tst.w	inertia(a0)				; is character moving?
		bne.s	.ContinueRolling			; if so, branch
		bclr	#2,status(a0)				; clear rolling status	
	        move.b	#$13,y_radius(a0)			; this increases Sonic's collision height to standing
	        move.b	#9,x_radius(a0)				; adjust Sonic's collision width to standing
		jsr	Sonic_Duck
		bra.w	Adjust_Y_Pos

	.ContinueRolling:	
        	jsr     Obj_Sonic_DoRoll			; make character roll
        	bra.w   Sonic_ResetOnFloor_Part3		; still need to clear some flags, etc.

	.ReturnToWalkRunDash:		
		move.b	#AniIDSonAni_Walk,anim(a0)
;=====================================================================================================================
; this code is called by the code that handles player standing on objects, like platforms or bridges
; some routines outside of Tails' code can call Sonic_ResetOnFloor_Part2
; when they mean to call Tails_ResetOnFloor_Part2, so fix that here
;=====================================================================================================================
; loc_1B0AC:
Sonic_ResetOnFloor_Part2: 
	        cmpi.l	#Obj_Tails,id(a0)			; is this object ID Sonic (Obj_Sonic)?
	        beq.w	Tails_ResetOnFloor_Part2		; if not, branch to the Tails version of this code
	        cmpi.l	#Obj_Knuckles,id(a0)			; is this object ID Knuckles?
	        beq.w	Knuckles_ResetOnFloor_Part2		; if it is, branch to the Knuckles version of this code
		btst	#2,status(a0)				; is rolling status set?
		beq.s	Sonic_ResetOnFloor_Part3		; if so, branch
		bclr	#2,status(a0)				; clear rolling status
		move.b	#$13,y_radius(a0)			; this increases Sonic's collision height to standing
		move.b	#9,x_radius(a0)				; adjust Sonic's collision width to standing
		tst.w	x_vel(a0)				; is character moving?
		bne.s	.ReturnToWalkRunDash			; if so, branch	

	.ReturnToIdle:	
		move.b	#$5,anim(a0)				; use standing/idle animation
		bra.s	Adjust_Y_Pos	

	.ReturnToWalkRunDash:		
		move.b	#AniIDSonAni_Walk,anim(a0)		; use running/walking/standing animation

	Adjust_Y_Pos:
		subq.w	#5,y_pos(a0)				; move Sonic up 5 pixels so the increased height doesn't push him into the ground    
;=====================================================================================================================
; clear flags, and signify a true reset on floor
;=====================================================================================================================
; loc_1B0DA:
Sonic_ResetOnFloor_Part3:      
	bclr	#1,status(a0)				; clear in air status
	bclr	#5,status(a0)				; clear pushing status
	bclr	#4,status(a0)				; clear rolljump status
	move.b	#0,jumping(a0)				; clear jumping flag
	move.w	#0,(Chain_Bonus_counter).w
	move.b	#0,flip_angle(a0)
	move.b	#0,flips_remaining(a0)
	clr.l	(HomingAttack_Object).l
;=====================================================================================================================
; if rolling status was already set, we want to branch away from the end of this code
; this prevents an issue where holding down would cause the character to duck rather than roll in most cases
;=====================================================================================================================
	btst    #2,status(a0)				; is status set to rolling?
	beq.s   return_1B11E  
;=====================================================================================================================
; clear a few more flags
;=====================================================================================================================
	move.b  #0,flip_turned(a0)
	move.w	#0,(Sonic_Look_delay_counter).w
	cmpi.b	#$14,anim(a0)
	bne.s	return_1B11E	
	move.b	#0,anim(a0)
	bra.s	return_1B11E
;=====================================================================================================================
; The end
;=====================================================================================================================
return_1B11E:	
	rts

; =============== S U B R O U T I N E =======================================

Sonic_ResetOnFloor_Ability:
	bsr.s	Sonic_DropDashRelease
	bsr.w	BubbleShield_Bounce
	clr.b	double_jump_flag(a0)
	move.b	#0,flip_turned(a0)
	rts

Sonic_DropDashRelease:
	cmpi.b	#2,(Option_SonicAbility).l
	beq.s	Sonic_DropDashRelease_Start
	cmpi.b	#3,(Option_SonicAbility).l
	beq.s	Sonic_DropDashRelease_Start
	jmp	Sonic_DropDashRelease_Ret

Sonic_DropDashRelease_Start:
	cmpi.l	#Obj_Sonic,id(a0)
	bne.w	Sonic_DropDashRelease_Ret

	tst.b	double_jump_flag(a0)
	beq.w	Sonic_DropDashRelease_Ret

	tst.b	glidemode(a0)
	bne.w	Sonic_DropDashRelease_Ret

	move.b	status_secondary(a0),d0
	andi.b	#Status_FireShield_mask|Status_LtngShield_mask|Status_BublShield_mask,d0 ; got a shield?
	bne.w	Sonic_DropDashRelease_Ret ; yep? begone

	move.w	#$800,d0	; [ dashspeed = 0x80000 ]
	move.w	#$C00,d1	; [ maxspeed = 0xC0000 ]

	; [ if ( v0->RightHeld == 1 ) ]
	btst	#button_right,(Ctrl_1_Held_Logical).w	; is right being pressed?
	beq.s	+			; if not, branch
	; [ v0->Direction = 0 ]
	bclr	#Status_Facing,status(a0)
+
	; [ if ( v0->LeftHeld == 1 ) ]
	btst	#button_left,(Ctrl_1_Held_Logical).w	; is left being pressed?
	beq.s	+			; if not, branch
	; [ v0->Direction = 1 ]
	bset	#Status_Facing,status(a0)
+

	; [ if ( v0->SuperMode == 2 ) ]
	tst.b	(Super_Sonic_flag).w	; Ignore this code if not Super Sonic
	beq.w	+
	move.w	#$C00,d0	; [ dashspeed = 0xC0000 ]
	move.w	#$D00,d1	; [ maxspeed = 0xD0000 ]
+
	; [ if ( v0->Direction ) ]
	btst	#Status_Facing,status(a0)		; is Sonic facing left?
	beq.s	Sonic_DropDashRelease_Right				; if not, branch

Sonic_DropDashRelease_Left:
	; [ if ( v0->XSpeed <= 0 ) ]
	tst.w	x_vel(a0)	; is Sonic moving left?
	bpl.s	++		; if not, branch
      
	; [ v6 = -maxspeed ]
	move.w	d1,d6
	neg.w	d6

	; [ v7 = (v0->GSpeed >> 2) - dashspeed ]
	moveq	#0,d5
	move.w	ground_vel(a0),d5
	asr.w	#2,d5
	sub.w	d0,d5

	; [ v0->GSpeed = v7 ]
	move.w	d5,ground_vel(a0)

	; [ if ( v7 < v6 ) ]
	cmp.w	d5,d6
	bge.s	+
	; [ v0->GSpeed = v6; ]
	move.w	d6,ground_vel(a0)
+
	bra.s Sonic_DropDashRelease_Release
+
    ; [ if ( v0->GroundAngle ) ]
	tst.b	angle(a0)
	beq.s	+
	; [ v0->GSpeed = (v0->GSpeed >> 1) - dashspeed ]
	asr.w	#1,ground_vel(a0)
	sub.w	d0,ground_vel(a0)
	bra.s Sonic_DropDashRelease_Release
+
	; [ dashspeed = -dashspeed ]
	neg.w	d0
	bra.s Sonic_DropDashRelease_ApplyVel

Sonic_DropDashRelease_Right:
    ; [ if ( v0->XSpeed >= 0 ) ]
	tst.w	x_vel(a0)	; is Sonic moving right? [ if ( v0->XSpeed <= 0 ) ]
	bmi.s	++		; if not, branch

	; [ v7 = (v0->GSpeed >> 2) - dashspeed ]
	; [ v5 = dashspeed + (v0->GSpeed >> 2) ]
	moveq	#0,d5
	move.w	ground_vel(a0),d5
	asr.w	#2,d5
	add.w	d0,d5

	; [ v0->GSpeed = v7 ]
	; [ v0->GSpeed = v5 ]
	move.w	d5,ground_vel(a0)

	; [ if ( v5 > maxspeed ) ]
	cmp.w	d5,d1
	bge.s	+
	; [ v0->GSpeed = maxspeed; ]
	move.w	d1,ground_vel(a0)
+
	bra.s Sonic_DropDashRelease_Release
+
    ; [ if ( v0->GroundAngle ) ]
	tst.b	angle(a0)
	beq.s	Sonic_DropDashRelease_ApplyVel
	; [ v0->GSpeed = dashspeed + (v0->GSpeed >> 1) ]
	asr.w	#1,ground_vel(a0)
	add.w	d0,ground_vel(a0)
	bra.s Sonic_DropDashRelease_Release

Sonic_DropDashRelease_ApplyVel:
    ; [ v0->GSpeed = dashspeed ]
	move.w	d0,ground_vel(a0)

Sonic_DropDashRelease_Release:
	move.w	#$1000,(Horiz_scroll_delay_val).w
	bsr.w	Reset_Player_Position_Array
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	move.b	#AniIDSonAni_Roll,anim(a0)
	addq.w	#5,y_pos(a0)	; add the difference between Sonic's rolling and standing heights
	bset	#Status_Roll,status(a0)

	move.b	#4,(Sonic_Dust+anim).w
	move.w	x_pos(a0),(Sonic_Dust+x_pos).w
	move.w	y_pos(a0),(Sonic_Dust+y_pos).w
	move.b	status(a0),(Sonic_Dust+status).w
	andi.b	#1,(Sonic_Dust+status).w

	sfx	sfx_Dash

Sonic_DropDashRelease_Ret:
	rts
; End of function 

; ===========================================================================
; =============== S U B R O U T I N E =======================================

BubbleShield_Bounce:
	tst.b	double_jump_flag(a0)
	beq.s	++
	cmpi.l  #Obj_Sonic,id(a0)
	bne.s	++
	cmpi.b	#4,(Option_SonicAbility).l
	beq.s	++
	cmpi.b	#5,(Option_SonicAbility).l
	bne.s	+
	cmpi.b	#2,double_jump_flag(a0)
	beq.w	BubbleShield_Bounce_Start
	rts
+
	;tst.b	(Super_Sonic_flag).w
	;bne.s	+
	btst	#Status_BublShield,status_secondary(a0)	; does character have a bubble shield?
	bne.w	BubbleShield_Bounce_Start	; if so, branch
+
	rts

BubbleShield_Bounce_Start:
	cmpi.b	#2,(Option_ShieldAbilityStyle).l
	bne.s	+
	cmpi.b	#32,angle(a0)	; approx 45 degrees
	bgt.w	loc_122AA_ret
	cmpi.b	#$FF-32,angle(a0)	; approx 45 degrees but the other way
	blt.w	loc_122AA_ret
+
	movem.l	d1-d2,-(sp)
	move.w	#$780,d2
	btst	#Status_Underwater,status(a0)
	beq.s	loc_12246
	move.w	#$400,d2

loc_12246:
	moveq	#0,d0
	move.b	angle(a0),d0
	subi.b	#$40,d0
	jsr	(CalcSine).l
	muls.w	d2,d1
	asr.l	#8,d1
	add.w	d1,x_vel(a0)
	muls.w	d2,d0
	asr.l	#8,d0
	add.w	d0,y_vel(a0)
	movem.l	(sp)+,d1-d2
	bset	#1,status(a0)
	bclr	#5,status(a0)
	move.b	#1,jumping(a0)
	clr.b	stick_to_convex(a0)
	move.b	#$E,y_radius(a0)
	move.b	#7,x_radius(a0)
	move.b	#2,anim(a0)
	bset	#Status_Roll,status(a0)
	move.b	y_radius(a0),d0
	subi.b	#$13,d0 ; make variable to support tails/different sized chars (default_y_radius)
	ext.w	d0
	;tst.b	(Reverse_gravity_flag).w
	;beq.s	loc_122AA
	;neg.w	d0

loc_122AA:
	sub.w	d0,y_pos(a0)
	btst	#Status_BublShield,status_secondary(a0)	; does character have a bubble shield?
	beq.w	+	; if not, branch
	move.b	#2,(Shield+anim).w
+
	sfx		sfx_BubbleAttack

loc_122AA_ret:
	rts
; End of function BubbleShield_Bounce

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he gets hurt
; ---------------------------------------------------------------------------
; loc_1B120: Obj_01_Sub_4:
Obj_Sonic_Hurt:
	tst.w	(Debug_mode_flag).w
	beq.s	Obj_Sonic_Hurt_Normal
	btst	#button_B,(Ctrl_1_Press).w
	beq.s	Obj_Sonic_Hurt_Normal
	move.w	#1,(Debug_placement_mode).w
	clr.b	(Control_Locked).w
	rts
; ---------------------------------------------------------------------------
; loc_1B13A:
Obj_Sonic_Hurt_Normal:
	tst.b	routine_secondary(a0)
	bmi.w	Sonic_HurtInstantRecover
	clr.l	(HomingAttack_Object).l
	jsr	(ObjectMove).l
	addi.w	#$30,y_vel(a0)
	btst	#6,status(a0)
	beq.s	+
	subi.w	#$20,y_vel(a0)
+
	cmpi.w	#-$100,(Camera_Min_Y_pos).w
	bne.s	+
	andi.w	#$7FF,y_pos(a0)
+
	bsr.w	Sonic_HurtStop
	bsr.w	Sonic_LevelBound
	bsr.w	Sonic_RecordPos
	bsr.w	Sonic_Water
	bsr.w	Sonic_Animate
	bsr.w	LoadSonicDynPLC
	jmp	(DisplaySprite).l
; ===========================================================================
; loc_1B184:
Sonic_HurtStop:
	lea	0.w,a2
	move.w	(Camera_Max_Y_pos_now).w,d0
	addi.w	#$E0,d0
	cmp.w	y_pos(a0),d0
	blt.w	JmpTo_KillCharacter
	bsr.w	Sonic_DoLevelCollision
	btst	#1,status(a0)
	bne.s	return_1B1C8
	moveq	#0,d0
	move.w	d0,y_vel(a0)
	move.w	d0,x_vel(a0)
	move.w	d0,inertia(a0)
	move.b	d0,obj_control(a0)
	move.b	#AniIDSonAni_Walk,anim(a0)
	subq.b	#2,routine(a0)	; => Obj_Sonic_Control
	move.w	#$78,invulnerable_time(a0)
	move.b	#0,spindash_flag(a0)

return_1B1C8:
	rts
; ===========================================================================
; makes Sonic recover control after being hurt before landing
; seems to be unused
; loc_1B1CA:
Sonic_HurtInstantRecover:
	subq.b	#2,routine(a0)	; => Obj_Sonic_Control
	move.b	#0,routine_secondary(a0)
	bsr.w	Sonic_RecordPos
	bsr.w	Sonic_Animate
	bsr.w	LoadSonicDynPLC
	jmp	(DisplaySprite).l
; ===========================================================================

; ---------------------------------------------------------------------------
; Sonic when he dies
; ...poor Sonic
; ---------------------------------------------------------------------------

; loc_1B1E6: Obj_01_Sub_6:
Obj_Sonic_Dead:
	tst.w	(Debug_mode_flag).w
	beq.s	+
	btst	#button_B,(Ctrl_1_Press).w
	beq.s	+
	move.w	#1,(Debug_placement_mode).w
	clr.b	(Control_Locked).w
	rts
+
	bsr.w	CheckGameOver
	jsr	(ObjectMoveAndFall).l
	bsr.w	Sonic_RecordPos
	bsr.w	Sonic_Animate
	bsr.w	LoadSonicDynPLC
	jmp	(DisplaySprite).l

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1B21C:
CheckGameOver:
	move.b	#1,(Scroll_lock).w
	move.b	#0,spindash_flag(a0)
	move.w	(Camera_Max_Y_pos_now).w,d0
	addi.w	#$100,d0
	cmp.w	y_pos(a0),d0
	bge.w	return_1B31A
	move.b	#8,routine(a0)	; => Obj_Sonic_Gone
	move.w	#60,restart_countdown(a0)
	addq.b	#1,(Update_HUD_lives).w	; update lives counter
	subq.b	#1,(Life_count).w	; subtract 1 from number of lives
	bne.s	Obj_Sonic_ResetLevel	; if it's not a game over, branch
	move.w	#0,restart_countdown(a0)
	move.l	#Obj_GameOver,(GameOver_GameText+id).w ; load Obj_GameOver (game over text)
	move.l	#Obj_GameOver,(GameOver_OverText+id).w ; load Obj_GameOver (game over text)
	move.b	#1,(GameOver_OverText+mapping_frame).w
	move.w	a0,(GameOver_GameText+parent).w
	clr.b	(Time_Over_flag).w
; loc_1B26E:
Obj_Sonic_Finished:
	clr.b	(Update_HUD_timer).w
	clr.b	(Update_HUD_timer_2P).w
	move.b	#8,routine(a0)	; => Obj_Sonic_Gone
	music	mus_GameOver
	moveq	#PLCID_GameOver,d0
	jmp	(LoadPLC).l
; End of function CheckGameOver

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when the level is restarted
; ---------------------------------------------------------------------------
; loc_1B28E:
Obj_Sonic_ResetLevel:
	tst.b	(Time_Over_flag).w
	beq.s	Obj_Sonic_ResetLevel_Part2
	move.w	#0,restart_countdown(a0)
	move.l	#Obj_TimeOver,(TimeOver_TimeText+id).w ; load Obj_GameOver
	move.l	#Obj_TimeOver,(TimeOver_OverText+id).w ; load Obj_GameOver
	move.b	#2,(TimeOver_TimeText+mapping_frame).w
	move.b	#3,(TimeOver_OverText+mapping_frame).w
	move.w	a0,(TimeOver_TimeText+parent).w
	bra.s	Obj_Sonic_Finished
; ---------------------------------------------------------------------------
Obj_Sonic_ResetLevel_Part2:
	tst.w	(Two_player_mode).w
	beq.s	return_1B31A
	move.b	#0,(Scroll_lock).w
	move.b	#$A,routine(a0)	; => Obj_Sonic_Respawning
	move.w	(Saved_x_pos).w,x_pos(a0)
	move.w	(Saved_y_pos).w,y_pos(a0)
	move.w	(Saved_art_tile).w,art_tile(a0)
	move.w	(Saved_Solid_bits).w,top_solid_bit(a0)
	clr.w	(Ring_count).w
	clr.b	(Extra_life_flags).w
	move.b	#0,obj_control(a0)
	move.b	#5,anim(a0)
	move.w	#0,x_vel(a0)
	move.w	#0,y_vel(a0)
	move.w	#0,inertia(a0)
	move.b	#Status_Roll,status(a0)
	move.w	#0,move_lock(a0)
	move.w	#0,restart_countdown(a0)

return_1B31A:
	rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he's offscreen and waiting for the level to restart
; ---------------------------------------------------------------------------
; loc_1B31C: Obj_01_Sub_8:
Obj_Sonic_Gone:
	tst.w	restart_countdown(a0)
	beq.s	+
	subq.w	#1,restart_countdown(a0)
	bne.s	+
	move.b	#1,(Level_Inactive_flag).w
+
	rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he's waiting for the camera to scroll back to where he respawned
; ---------------------------------------------------------------------------
; loc_1B330: Obj_01_Sub_A:
Obj_Sonic_Respawning:
	tst.w	(Camera_X_pos_diff).w
	bne.s	+
	tst.w	(Camera_Y_pos_diff).w
	bne.s	+
	move.b	#2,routine(a0)	; => Obj_Sonic_Control
+
	bsr.w	Sonic_Animate
	bsr.w	LoadSonicDynPLC
	jmp	(DisplaySprite).l
; ===========================================================================

; ---------------------------------------------------------------------------
; Subroutine to animate Sonic's sprites
; See also: AnimateSprite
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1B350:
Sonic_Animate:
	lea	(SonicAniData).l,a1
	tst.b	(Super_Sonic_flag).w
	beq.s	+
	lea	(SuperSonicAniData).l,a1
+
	moveq	#0,d0
	move.b	anim(a0),d0
	cmp.b	next_anim(a0),d0	; has animation changed?
	beq.s	SAnim_Do		; if not, branch
	move.b	d0,next_anim(a0)	; set to next animation
	move.b	#0,anim_frame(a0)	; reset animation frame
	move.b	#0,anim_frame_duration(a0)	; reset frame duration
	bclr	#5,status(a0)
; loc_1B384:
SAnim_Do:
	add.w	d0,d0
	adda.w	(a1,d0.w),a1	; calculate address of appropriate animation script
	move.b	(a1),d0
	bmi.s	SAnim_WalkRun	; if animation is walk/run/roll/jump, branch
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render_flags(a0)
	or.b	d1,render_flags(a0)
	subq.b	#1,anim_frame_duration(a0)	; subtract 1 from frame duration
	bpl.s	SAnim_Delay			; if time remains, branch
	move.b	d0,anim_frame_duration(a0)	; load frame duration
; loc_1B3AA:
SAnim_Do2:
	moveq	#0,d1
	move.b	anim_frame(a0),d1	; load current frame number
	move.b	1(a1,d1.w),d0		; read sprite number from script
	cmpi.b	#$F0,d0
	bhs.s	SAnim_End_FF		; if animation is complete, branch
; loc_1B3BA:
SAnim_Next:
	move.b	d0,mapping_frame(a0)	; load sprite number
	addq.b	#1,anim_frame(a0)	; go to next frame
; return_1B3C2:
SAnim_Delay:
	rts
; ===========================================================================
; loc_1B3C4:
SAnim_End_FF:
	addq.b	#1,d0		; is the end flag = $FF ?
	bne.s	SAnim_End_FE	; if not, branch
	move.b	#0,anim_frame(a0)	; restart the animation
	move.b	1(a1),d0	; read sprite number
	bra.s	SAnim_Next
; ===========================================================================
; loc_1B3D4:
SAnim_End_FE:
	addq.b	#1,d0		; is the end flag = $FE ?
	bne.s	SAnim_End_FD	; if not, branch
	move.b	2(a1,d1.w),d0	; read the next byte in the script
	sub.b	d0,anim_frame(a0)	; jump back d0 bytes in the script
	sub.b	d0,d1
	move.b	1(a1,d1.w),d0	; read sprite number
	bra.s	SAnim_Next
; ===========================================================================
; loc_1B3E8:
SAnim_End_FD:
	addq.b	#1,d0			; is the end flag = $FD ?
	bne.s	SAnim_End		; if not, branch
	move.b	2(a1,d1.w),anim(a0)	; read next byte, run that animation
; return_1B3F2:
SAnim_End:
	rts
; ===========================================================================
; loc_1B3F4:
SAnim_WalkRun:
	addq.b	#1,d0		; is the start flag = $FF ?
	bne.w	SAnim_Roll	; if not, branch
	moveq	#0,d0		; is animation walking/running?
	move.b	flip_angle(a0),d0	; if not, branch
	bne.w	SAnim_Tumble
	moveq	#0,d1
	move.b	angle(a0),d0	; get Sonic's angle
	bmi.s	+
	beq.s	+
	subq.b	#1,d0
+
	move.b	status(a0),d2
	andi.b	#1,d2		; is Sonic mirrored horizontally?
	bne.s	+		; if yes, branch
	not.b	d0		; reverse angle
+
	addi.b	#$10,d0		; add $10 to angle
	bpl.s	+		; if angle is $0-$7F, branch
	moveq	#3,d1
+
	andi.b	#$FC,render_flags(a0)
	eor.b	d1,d2
	or.b	d2,render_flags(a0)
	btst	#5,status(a0)
	bne.w	SAnim_Push
	lsr.b	#4,d0		; divide angle by 16
	andi.b	#6,d0		; angle must be 0, 2, 4 or 6
	mvabs.w	inertia(a0),d2	; get Sonic's "speed" for animation purposes
    if status_sec_isSliding = 7
	tst.b	status_secondary(a0)
	bpl.w	+
    else
	btst	#status_sec_isSliding,status_secondary(a0)
	beq.w	+
    endif
	add.w	d2,d2
+
	tst.b	(Super_Sonic_flag).w
	bne.s	SAnim_Super
	
	cmpi.b	#0,(Option_PeelOut).w
	beq.s	+
	cmpi.b	#3,(Option_PeelOut).w
	beq.s	+

	lea	(SonAni_PeelOut).l,a1	; use running animation
	cmpi.w	#$A00,d2		; is Sonic at running speed?
	bhs.s	++			; use running animation
+
	lea	(SonAni_Run).l,a1	; use running animation
	cmpi.w	#$600,d2		; is Sonic at running speed?
	bhs.s	+			; use running animation
	lea	(SonAni_Walk).l,a1	; if yes, branch
	add.b	d0,d0
+
	add.b	d0,d0
	move.b	d0,d3
	moveq	#0,d1
	move.b	anim_frame(a0),d1
	move.b	1(a1,d1.w),d0
	cmpi.b	#-1,d0
	bne.s	+
	move.b	#0,anim_frame(a0)
	move.b	1(a1),d0
+
	move.b	d0,mapping_frame(a0)
	add.b	d3,mapping_frame(a0)
	subq.b	#1,anim_frame_duration(a0)
	bpl.s	return_1B4AC
	neg.w	d2
	addi.w	#$800,d2
	bpl.s	+
	moveq	#0,d2
+
	lsr.w	#8,d2
	move.b	d2,anim_frame_duration(a0)	; modify frame duration
	addq.b	#1,anim_frame(a0)		; modify frame number

return_1B4AC:
	rts
; ===========================================================================
; loc_1B4AE:
SAnim_Super:
	lea	(SupSonAni_Run).l,a1	; use fast animation
	cmpi.w	#$800,d2		; is Sonic moving fast?
	bhs.s	SAnim_SuperRun		; if yes, branch
	lea	(SupSonAni_Walk).l,a1	; use slower animation
	add.b	d0,d0
	add.b	d0,d0
	bra.s	SAnim_SuperWalk
; ---------------------------------------------------------------------------
; loc_1B4C6:
SAnim_SuperRun:
	lsr.b	#1,d0
; loc_1B4C8:
SAnim_SuperWalk:
	move.b	d0,d3
	moveq	#0,d1
	move.b	anim_frame(a0),d1
	move.b	1(a1,d1.w),d0
	cmpi.b	#-1,d0
	bne.s	+
	move.b	#0,anim_frame(a0)
	move.b	1(a1),d0
+
	move.b	d0,mapping_frame(a0)
	add.b	d3,mapping_frame(a0)
	move.b	(Timer_frames+1).w,d1
	andi.b	#3,d1
	bne.s	+
	cmpi.b	#$B5,mapping_frame(a0)
	bhs.s	+
	addi.b	#$20,mapping_frame(a0)
+
	subq.b	#1,anim_frame_duration(a0)
	bpl.s	return_1B51E
	neg.w	d2
	addi.w	#$800,d2
	bpl.s	+
	moveq	#0,d2
+
	lsr.w	#8,d2
	move.b	d2,anim_frame_duration(a0)
	addq.b	#1,anim_frame(a0)

return_1B51E:
	rts
; ===========================================================================
; loc_1B520:
SAnim_Tumble:
	move.b	flip_angle(a0),d0
	moveq	#0,d1
	move.b	status(a0),d2
	andi.b	#1,d2
	bne.s	SAnim_Tumble_Left

	andi.b	#$FC,render_flags(a0)
	addi.b	#$B,d0
	divu.w	#$16,d0
	addi.b	#$5F,d0
	move.b	d0,mapping_frame(a0)
	move.b	#0,anim_frame_duration(a0)
	rts
; ===========================================================================
; loc_1B54E:
SAnim_Tumble_Left:
	andi.b	#$FC,render_flags(a0)
	tst.b	flip_turned(a0)
	beq.s	loc_1B566
	ori.b	#1,render_flags(a0)
	addi.b	#$B,d0
	bra.s	loc_1B572
; ===========================================================================

loc_1B566:
	ori.b	#3,render_flags(a0)
	neg.b	d0
	addi.b	#$8F,d0

loc_1B572:
	divu.w	#$16,d0
	addi.b	#$5F,d0
	move.b	d0,mapping_frame(a0)
	move.b	#0,anim_frame_duration(a0)
	rts
; ===========================================================================
; loc_1B586:
SAnim_Roll:
	subq.b	#1,anim_frame_duration(a0)	; subtract 1 from frame duration
	bpl.w	SAnim_Delay			; if time remains, branch
	addq.b	#1,d0		; is the start flag = $FE ?
	bne.s	SAnim_Push	; if not, branch
	mvabs.w	inertia(a0),d2
	lea	(SonAni_Roll2).l,a1
	cmpi.w	#$600,d2
	bhs.s	+
	lea	(SonAni_Roll).l,a1
+
	neg.w	d2
	addi.w	#$400,d2
	bpl.s	+
	moveq	#0,d2
+
	lsr.w	#8,d2
	move.b	d2,anim_frame_duration(a0)
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render_flags(a0)
	or.b	d1,render_flags(a0)
	bra.w	SAnim_Do2
; ===========================================================================

SAnim_Push:
	subq.b	#1,anim_frame_duration(a0)	; subtract 1 from frame duration
	bpl.w	SAnim_Delay			; if time remains, branch
	move.w	inertia(a0),d2
	bmi.s	+
	neg.w	d2
+
	addi.w	#$800,d2
	bpl.s	+
	moveq	#0,d2
+
	lsr.w	#6,d2
	move.b	d2,anim_frame_duration(a0)
	lea	(SonAni_Push).l,a1
	tst.b	(Super_Sonic_flag).w
	beq.s	+
	lea	(SupSonAni_Push).l,a1
+
	move.b	status(a0),d1
	andi.b	#1,d1
	andi.b	#$FC,render_flags(a0)
	or.b	d1,render_flags(a0)
	bra.w	SAnim_Do2
; ===========================================================================

; ---------------------------------------------------------------------------
; Animation script - Sonic
; ---------------------------------------------------------------------------
; off_1B618:
SonicAniData:			offsetTable
SonAni_Walk_ptr:		offsetTableEntry.w SonAni_Walk		;  0 ;   0
SonAni_Run_ptr:			offsetTableEntry.w SonAni_Run		;  1 ;   1
SonAni_Roll_ptr:		offsetTableEntry.w SonAni_Roll		;  2 ;   2
SonAni_Roll2_ptr:		offsetTableEntry.w SonAni_Roll2		;  3 ;   3
SonAni_Push_ptr:		offsetTableEntry.w SonAni_Push		;  4 ;   4
SonAni_Wait_ptr:		offsetTableEntry.w SonAni_Wait		;  5 ;   5
SonAni_Balance_ptr:		offsetTableEntry.w SonAni_Balance	;  6 ;   6
SonAni_LookUp_ptr:		offsetTableEntry.w SonAni_LookUp	;  7 ;   7
SonAni_Duck_ptr:		offsetTableEntry.w SonAni_Duck		;  8 ;   8
SonAni_Spindash_ptr:		offsetTableEntry.w SonAni_Spindash	;  9 ;   9
SonAni_Blink_ptr:		offsetTableEntry.w SonAni_Blink		; 10 ;  $A
SonAni_GetUp_ptr:		offsetTableEntry.w SonAni_GetUp		; 11 ;  $B
SonAni_Balance2_ptr:		offsetTableEntry.w SonAni_Balance2	; 12 ;  $C
SonAni_Stop_ptr:		offsetTableEntry.w SonAni_Stop		; 13 ;  $D
SonAni_Float_ptr:		offsetTableEntry.w SonAni_Float		; 14 ;  $E
SonAni_Float2_ptr:		offsetTableEntry.w SonAni_Float2	; 15 ;  $F
SonAni_Spring_ptr:		offsetTableEntry.w SonAni_Spring	; 16 ; $10
SonAni_Hang_ptr:		offsetTableEntry.w SonAni_Hang		; 17 ; $11
SonAni_Dash2_ptr:		offsetTableEntry.w SonAni_Dash2		; 18 ; $12
SonAni_Dash3_ptr:		offsetTableEntry.w SonAni_Dash3		; 19 ; $13
SonAni_Hang2_ptr:		offsetTableEntry.w SonAni_Hang2		; 20 ; $14
SonAni_Bubble_ptr:		offsetTableEntry.w SonAni_Bubble	; 21 ; $15
SonAni_DeathBW_ptr:		offsetTableEntry.w SonAni_DeathBW	; 22 ; $16
SonAni_Drown_ptr:		offsetTableEntry.w SonAni_Drown		; 23 ; $17
SonAni_Death_ptr:		offsetTableEntry.w SonAni_Death		; 24 ; $18
SonAni_Hurt_ptr:		offsetTableEntry.w SonAni_Hurt		; 25 ; $19
SonAni_Hurt2_ptr:		offsetTableEntry.w SonAni_Hurt		; 26 ; $1A
SonAni_Slide_ptr:		offsetTableEntry.w SonAni_Slide		; 27 ; $1B
SonAni_Blank_ptr:		offsetTableEntry.w SonAni_Blank		; 28 ; $1C
SonAni_Balance3_ptr:		offsetTableEntry.w SonAni_Balance3	; 29 ; $1D
SonAni_Balance4_ptr:		offsetTableEntry.w SonAni_Balance4	; 30 ; $1E
SupSonAni_Transform_ptr:	offsetTableEntry.w SupSonAni_Transform	; 31 ; $1F
SonAni_Lying_ptr:		offsetTableEntry.w SonAni_Lying		; 32 ; $20
SonAni_LieDown_ptr:		offsetTableEntry.w SonAni_LieDown	; 33 ; $21
SonAni_PeelOut_ptr:		offsetTableEntry.w SonAni_PeelOut	
SonAni_DropDash_ptr:		offsetTableEntry.w SonAni_DropDash

SonAni_Walk:	dc.b $FF, $F,$10,$11,$12,$13,$14, $D, $E,$FF
	rev02even
SonAni_Run:	dc.b $FF,$2D,$2E,$2F,$30,$FF,$FF,$FF,$FF,$FF
	rev02even
SonAni_Roll:	dc.b $FE,$3D,$41,$3E,$41,$3F,$41,$40,$41,$FF
	rev02even
SonAni_Roll2:	dc.b $FE,$3D,$41,$3E,$41,$3F,$41,$40,$41,$FF
	rev02even
SonAni_Push:	dc.b $FD,$48,$49,$4A,$4B,$FF,$FF,$FF,$FF,$FF
	rev02even
SonAni_Wait:
	dc.b   5,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
	dc.b   1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2
	dc.b   3,  3,  3,  3,  3,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5
	dc.b   5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  6,  6,  6
	dc.b   6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5,  5,  4,  4,  4
	dc.b   5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  6
	dc.b   6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5,  5,  4
	dc.b   4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5
	dc.b   5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  4,  4,  4,  5,  5
	dc.b   5,  4,  4,  4,  5,  5,  5,  4,  4,  4,  5,  5,  5,  4,  4,  4
	dc.b   5,  5,  5,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7,  8,  8
	dc.b   8,  9,  9,  9,$FE,  6
	rev02even
SonAni_Balance:	dc.b   9,$CC,$CD,$CE,$CD,$FF
	rev02even
SonAni_LookUp:	dc.b   5, $B, $C,$FE,  1
	rev02even
SonAni_Duck:	dc.b   5,$4C,$4D,$FE,  1
	rev02even
SonAni_Spindash:dc.b   0,$42,$43,$42,$44,$42,$45,$42,$46,$42,$47,$FF
	rev02even
SonAni_Blink:	dc.b   1,  2,$FD,  0
	rev02even
SonAni_GetUp:	dc.b   3, $A,$FD,  0
	rev02even
SonAni_Balance2:dc.b   3,$C8,$C9,$CA,$CB,$FF
	rev02even
SonAni_Stop:	dc.b   5,$D2,$D3,$D4,$D5,$FD,  0 ; halt/skidding animation
	rev02even
SonAni_Float:	dc.b   7,$54,$59,$FF
	rev02even
SonAni_Float2:	dc.b   7,$54,$55,$56,$57,$58,$FF
	rev02even
SonAni_Spring:	dc.b $2F,$5B,$FD,  0
	rev02even
SonAni_Hang:	dc.b   1,$50,$51,$FF
	rev02even
SonAni_Dash2:	dc.b  $F,$43,$43,$43,$FE,  1
	rev02even
SonAni_Dash3:	dc.b  $F,$43,$44,$FE,  1
	rev02even
SonAni_Hang2:	dc.b $13,$6B,$6C,$FF
	rev02even
SonAni_Bubble:	dc.b  $B,$5A,$5A,$11,$12,$FD,  0 ; breathe
	rev02even
SonAni_DeathBW:	dc.b $20,$5E,$FF
	rev02even
SonAni_Drown:	dc.b $20,$5D,$FF
	rev02even
SonAni_Death:	dc.b $20,$5C,$FF
	rev02even
SonAni_Hurt:	dc.b $40,$4E,$FF
	rev02even
SonAni_Slide:	dc.b   9,$4E,$4F,$FF
	rev02even
SonAni_Blank:	dc.b $77,  0,$FD,  0
	rev02even
SonAni_Balance3:dc.b $13,$D0,$D1,$FF
	rev02even
SonAni_Balance4:dc.b   3,$CF,$C8,$C9,$CA,$CB,$FE,  4
	rev02even
SonAni_Lying:	dc.b   9,  8,  9,$FF
	rev02even
SonAni_LieDown:	dc.b   3,  7,$FD,  0
	even
SonAni_PeelOut:	dc.b $FF,$D6,$D7,$D8,$D9,$FF,$FF,$FF,$FF,$FF
	rev02even
SonAni_DropDash: dc.b $00,$E6,$E8,$E7,$E9,$E6,$EA,$E7,$EB,$E6,$EC,$E7,$ED,$E6,$EE,$E7,$EF,$FF
	rev02even

; ---------------------------------------------------------------------------
; Animation script - Super Sonic
; (many of these point to the data above this)
; ---------------------------------------------------------------------------
SuperSonicAniData: offsetTable
	offsetTableEntry.w SupSonAni_Walk	;  0 ;   0
	offsetTableEntry.w SupSonAni_Run	;  1 ;   1
	offsetTableEntry.w SonAni_Roll		;  2 ;   2
	offsetTableEntry.w SonAni_Roll2		;  3 ;   3
	offsetTableEntry.w SupSonAni_Push	;  4 ;   4
	offsetTableEntry.w SupSonAni_Stand	;  5 ;   5
	offsetTableEntry.w SupSonAni_Balance	;  6 ;   6
	offsetTableEntry.w SonAni_LookUp	;  7 ;   7
	offsetTableEntry.w SupSonAni_Duck	;  8 ;   8
	offsetTableEntry.w SonAni_Spindash	;  9 ;   9
	offsetTableEntry.w SonAni_Blink		; 10 ;  $A
	offsetTableEntry.w SonAni_GetUp		; 11 ;  $B
	offsetTableEntry.w SonAni_Balance2	; 12 ;  $C
	offsetTableEntry.w SonAni_Stop		; 13 ;  $D
	offsetTableEntry.w SonAni_Float		; 14 ;  $E
	offsetTableEntry.w SonAni_Float2	; 15 ;  $F
	offsetTableEntry.w SonAni_Spring	; 16 ; $10
	offsetTableEntry.w SonAni_Hang		; 17 ; $11
	offsetTableEntry.w SonAni_Dash2		; 18 ; $12
	offsetTableEntry.w SonAni_Dash3		; 19 ; $13
	offsetTableEntry.w SonAni_Hang2		; 20 ; $14
	offsetTableEntry.w SonAni_Bubble	; 21 ; $15
	offsetTableEntry.w SonAni_DeathBW	; 22 ; $16
	offsetTableEntry.w SonAni_Drown		; 23 ; $17
	offsetTableEntry.w SonAni_Death		; 24 ; $18
	offsetTableEntry.w SonAni_Hurt		; 25 ; $19
	offsetTableEntry.w SonAni_Hurt		; 26 ; $1A
	offsetTableEntry.w SonAni_Slide		; 27 ; $1B
	offsetTableEntry.w SonAni_Blank		; 28 ; $1C
	offsetTableEntry.w SonAni_Balance3	; 29 ; $1D
	offsetTableEntry.w SonAni_Balance4	; 30 ; $1E
	offsetTableEntry.w SupSonAni_Transform	; 31 ; $1F
	offsetTableEntry.w SupSonAni_Run	;  32 ;   $20
	offsetTableEntry.w SonAni_Blank		;  33 ;   $21
	offsetTableEntry.w SonAni_Blank		;  34 ;   $22
	offsetTableEntry.w SonAni_DropDash	;  35 ;   $23

SupSonAni_Walk:		dc.b $FF,$77,$78,$79,$7A,$7B,$7C,$75,$76,$FF
	rev02even
SupSonAni_Run:		dc.b $FF,$B5,$B9,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	rev02even
SupSonAni_Push:		dc.b $FD,$BD,$BE,$BF,$C0,$FF,$FF,$FF,$FF,$FF
	rev02even
SupSonAni_Stand:	dc.b   7,$72,$73,$74,$73,$FF
	rev02even
SupSonAni_Balance:	dc.b   9,$C2,$C3,$C4,$C3,$C5,$C6,$C7,$C6,$FF
	rev02even
SupSonAni_Duck:		dc.b   5,$C1,$FF
	rev02even
SupSonAni_Transform:	dc.b   2,$6D,$6D,$6E,$6E,$6F,$70,$71,$70,$71,$70,$71,$70,$71,$FD,  0
	even

; ---------------------------------------------------------------------------
; Sonic pattern loading subroutine
; ---------------------------------------------------------------------------

; ||||||||||||||| S U B R O U T I N E |||||||||||||||||||||||||||||||||||||||

; loc_1B848:
LoadSonicDynPLC:

	moveq	#0,d0
	move.b	mapping_frame(a0),d0	; load frame number
; loc_1B84E:
LoadSonicDynPLC_Part2:
	cmp.b	(Sonic_LastLoadedDPLC).w,d0
	beq.s	return_1B89A
	move.b	d0,(Sonic_LastLoadedDPLC).w
	lea	(MapRUnc_Sonic).l,a2
	add.w	d0,d0
	adda.w	(a2,d0.w),a2
	move.w	(a2)+,d5
	subq.w	#1,d5
	bmi.s	return_1B89A
	move.w	#tiles_to_bytes(ArtTile_ArtUnc_Sonic),d4
; loc_1B86E:
SPLC_ReadEntry:
	moveq	#0,d1
	move.w	(a2)+,d1
	move.w	d1,d3
	lsr.w	#8,d3
	andi.w	#$F0,d3
	addi.w	#$10,d3
	andi.w	#$FFF,d1
	lsl.l	#5,d1
	addi.l	#ArtUnc_Sonic,d1
	move.w	d4,d2
	add.w	d3,d4
	add.w	d3,d4
	jsr	(QueueDMATransfer).l
	dbf	d5,SPLC_ReadEntry	; repeat for number of entries

return_1B89A:
	rts
; ===========================================================================

JmpTo_KillCharacter
	jmp	(KillCharacter).l

    if ~~removeJmpTos
	align 4
    endif
# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024
GET_OPPONENT_HINT       = 0xffff00ec

TIMER                   = 0xffff001c
ARENA_MAP               = 0xffff00dc

SHOOT_UDP_PACKET        = 0xffff00e0
GET_BYTECOINS           = 0xffff00e4
USE_SCANNER             = 0xffff00e8

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

.data
### Puzzle
puzzle:     .byte 0:268
solution:   .byte 0:256
#### Puzzle

has_puzzle: .word 0

flashlight_space: .word 0
scanner_wb: .byte 0 0 0 0
.text
main:
    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, BONK_INT_MASK # request bonk
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK           # puzzle interrupt bit
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12
    
    
    # Fill in your code here
movement:
    
    li $a0, 5
    jal set_speed

    li	$a0, 45			# face SE
	jal	set_orientation
	jal	wait

	li	$a0, 135		# face SW
	jal	set_orientation
	jal	wait

	li	$a0, 45		    # face SE
	jal	set_orientation
	jal	wait

	li	$a0, 315		# face NE
	jal	set_orientation
	jal	wait            # wait 2 cycles
    jal wait

    li $a0, 0           # initial scan angle
scan_for:
    li $t2, 360
    bge $a0, $t2, continue_movement       # exit once scanned a whole circle
    jal set_orientation

    la $t5, scanner_wb
    sw $t5, USE_SCANNER
    li $t6, 2           # HOST_MASK TYPE
    lb $t5, 2($t5)      # get scan_type
    bne $t6, $t5, skip_shoot
    li $t4, 1
    sw $t4, SHOOT_UDP_PACKET
skip_shoot:
    add $a0, $a0, 10    # increment angle by 10
    j scan_for

continue_movement:
    j movement
    jr      $ra

################################################################################
set_orientation:
	sw	$a0, ANGLE
	li	$t0, 1
	sw	$t0, ANGLE_CONTROL		# say it is an absolute angle
	jr	$ra

################################################################################

wait:
	li	$a0, 80000		# select a wait amount

wait_loop:	
	sub	$a0, $a0, 1
	bgt	$a0, $zero, wait_loop

	jr	$ra

################################################################################

set_speed: 
 	sw	$a0, VELOCITY		# set velocity
	jr	$ra


.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt



interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, RESPAWN_INT_MASK
    bne     $a0, 0, respawn_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    #Fill in your bonk handler code here
    
    # Make a random time generator
    # 1/3 change angle to 45(rel), 1/3 change angle to -45(rel), 1/3 change angle to 180(rel)

    lw $t5, TIMER   # get time for rng

    and $t5, $t5, 3         # and with 0x11

    li $t3, 0
    beq $t5, $t3, bonk_1
    li $t3, 1
    beq $t5, $t3, bonk_2
    li $t3, 2
    beq $t5, $t3, bonk_3

    li $t4, 45  # default angle change
    j done_if   

bonk_1:
    li $t4, 45  # initial angle before change
    j done_if

bonk_2:
    li $t4, -45  # initial angle before change
    j done_if

bonk_3:
    li $t4, 180  # initial angle before change
    j done_if
    
done_if:
    sw $t4, ANGLE   # assign to angle

    sw $0, ANGLE_CONTROL   # relative
    li $t4, 5
    sw $t4, VELOCITY


    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer interrupt code here
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your puzzle interrupt code here
    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK
    #Fill in your respawn handler code here
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

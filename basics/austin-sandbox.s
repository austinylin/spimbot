.data
  flag: .word 0
  puzzle: .space 324

  newline:.asciiz "\n"		# useful for printing commands
  star:	.asciiz "*"

.text
main:
  li    $t4, 0x4001 # flag for bonk interrupt set, and global interrupt enable
  mtc0  $t4, $12  # Enable interrupt mask (Status register)
  la    $t0, puzzle($zero)
  sw    $t0, 0xffff00e8($zero)
 #  
    loop:
      lw    $t0, flag
      #andi  $t0, $t0, 0x8
      bgt   $t0, $zero, solve_puzzle  # if $t0 > $zero then solve_puzzle
      j loop
 # 
  solve_puzzle:
    la    $a0, puzzle($zero)
    jal   print_board        # jump to print_board and save position to $ra
    jal   print_newline       # jump to print_board and save position to $ra
    sw    $zero, flag
    la    $t0, puzzle($zero)   
    sw    $t0, 0xffff00e8($zero)
    j     loop        # jump to loop
    
    
 

#################### PRINT_NEWLINE #################### 	
print_newline:
	lb   	$a0, newline($0)        	# read the newline char
	li   	$v0, 11        	# load the syscall option for printing chars
	syscall              	# print the char

	jr      $ra          	# return to the calling procedure


#################### PRINT_INT_AND_SPACE #################### 	
print_int_and_space:
	li   	$v0, 1         	# load the syscall option for printing ints
	syscall              	# print the element

	li   	$a0, 32        	# print a black space (ASCII 32)
	li   	$v0, 11        	# load the syscall option for printing chars
	syscall              	# print the char

	jr      $ra          	# return to the calling procedure


#################### SINGLETON #################### 	
is_singleton:
	li	$v0, 0
	beq	$a0, 0, is_singleton_done		# return 0 if value == 0
	sub	$a1, $a0, 1
	and	$a1, $a0, $a1
	bne	$a1, 0, is_singleton_done		# return 0 if (value & (value - 1)) == 0
	li	$v0, 1
is_singleton_done:
	jr	$ra


#################### GET_SINGLETON #################### 	
get_singleton:
	li	$v0, 0			# i
	li	$t1, 1
gs_loop:sll	$t2, $t1, $v0		# (1<<i)
	beq	$t2, $a0, get_singleton_done
	add	$v0, $v0, 1
	blt	$v0, 9, gs_loop		# repeat if (i < 9)
get_singleton_done:
	jr	$ra


#################### PRINT BOARD #################### 	
print_board:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# the function argument
	sw	$s3, 16($sp)		# the computed pointer (which is used for 2 calls)
	move	$s2, $a0

	li	$s0, 0			# i
pb_loop1:
	li	$s1, 0			# j
pb_loop2:
	mul	$t0, $s0, 9		# i*9
	add	$t0, $t0, $s1		# (i*9)+j
	sll	$t0, $t0, 2		# ((i*9)+j)*4
	add	$s3, $s2, $t0
	lw	$a0, 0($s3)
	jal	is_singleton		
	beq	$v0, 0, pb_star		# if it was not a singleton, jump
	lw	$a0, 0($s3)
	jal	get_singleton		
	add	$a0, $v0, 1		# print the value + 1
	li	$v0, 1
	syscall
	j	pb_cont

pb_star:		
	li	$v0, 4			# print a "*"
	la	$a0, star
	syscall

pb_cont:	
	add	$s1, $s1, 1		# j++
	blt	$s1, 9, pb_loop2

	li	$v0, 4			# at the end of a line, print a newline char.
	la	$a0, newline
	syscall	

	add	$s0, $s0, 1		# i++
	blt	$s0, 9, pb_loop1

	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20
	jr	$ra


.data     # interrupt handler data (separated just for readability)
save0:       .word 0
save1:       .word 0
v0:       .word 0

non_intrpt_str:   .asciiz "Non-interrupt exception\n"
puzzle_interrupt_str:   .asciiz "Puzzle Interrupt Detected!\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"

.ktext 0x80000080
interrupt_handler:
  .set noat
  move  $k1, $at    # Save $at
  .set at
  sw  $a0, save0    # Get some free registers
  sw  $a1, save1    # by storing them to a global variable
  sw  $v0, v0 
  
  mfc0  $k0, $13    # Get Cause register
  srl   $a0, $k0, 2   
  and   $a0, $a0, 0xf   # ExcCode field
  bne   $a0, 0, non_intrpt

interrupt_dispatch:     # Interrupt:
  mfc0  $k0, $13    # Get Cause register, again
  beq $k0, $zero, done  # handled all outstanding interrupts

  and   $a0, $k0, 0x4000  # is there a bonk interrupt?
  bne   $a0, 0, puzzle_ready_interrupt
  
          # add dispatch for other interrupt types here.

  li $v0, 4     # Unhandled interrupt types
  la $a0, unhandled_str
  syscall
  b done

puzzle_ready_interrupt:
  li $v0, 4     
  la $a0, puzzle_interrupt_str
  syscall       # print out an error message
  
  li    $a0, 1
  sw    $a0, flag
     
  sw  $a1, 0xffff0068($zero)    # acknowledge interrupt
  b   interrupt_dispatch    # see if other interrupts are waiting
  
non_intrpt:       # was some non-interrupt
  li $v0, 4     
  la $a0, non_intrpt_str
  syscall       # print out an error message
  b done

done:
  lw  $a0, save0
  lw  $a1, save1
  lw  $v0, v0 
  
  mfc0  $k0 $14     # EPC
  .set noat
  move  $at $k1     # Restore $at
  .set at
  rfe       # Return from exception handler
  jr  $k0
        nop


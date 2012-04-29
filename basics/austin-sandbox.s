.data
  flag: .word 0
  puzzle: .space 324

  newline:.asciiz "\n"    # useful for printing commands
  star: .asciiz "*"

.text
main:
  li    $t4, 0x4001 # flag for bonk interrupt set, and global interrupt enable
  mtc0  $t4, $12  # Enable interrupt mask (Status register)
  la    $t0, puzzle($zero)
  sw    $t0, 0xffff00e8($zero)
  loop:
    lw    $t0, flag
    #andi  $t0, $t0, 0x8
    bgt   $t0, $zero, solve_puzzle  # if $t0 > $zero then solve_puzzle
    j loop
 
solve_board:
	sub  	$sp, $sp, 12
	sw   	$ra, 0($sp)	# save $ra on stack
	sw   	$s0, 4($sp) 	# save $s0 on stack	<--- check out use of $s register!!
	sw    $s1, 8($sp)   # 

	move	$s0, $a0
main_loop:
	move	$a0, $s0
	jal	rule1
  move  $s1, $v0
  move  $a0, $s0
  jal rule2
  or $s1, $v0, $s1
	bne	$s1, 0, main_loop	# keep running rule1 until no more changes

	lw   	$ra, 0($sp) 	# restore $ra
	lw   	$s0, 4($sp) 	# restore $s0 
	lw    $s1, 8($sp)   # 

	add  	$sp, $sp, 12
	jr	$ra

solve_puzzle:
  la    $a0, puzzle($zero)
  jal   print_board        # jump to print_board and save position to $ra
  jal   print_newline       # jump to print_board and save position to $ra
  la    $a0, puzzle($zero)
  jal   solve_board        # jump to solve_board and save position to $ra
  la    $a0, puzzle($zero)
  jal   print_board        # jump to print_board and save position to $ra
  jal   print_newline       # jump to print_board and save position to $ra
  
  la    $a0, puzzle($zero)
  sw    $a0, 0xffff00ec($zero) #turn in the puzzle
 
  sw    $zero, flag
  la    $t0, puzzle($zero)   
  sw    $t0, 0xffff00e8($zero)
  j     loop        # jump to loop


#################### PRINT_NEWLINE ####################   
print_newline:
  lb    $a0, newline($0)          # read the newline char
  li    $v0, 11         # load the syscall option for printing chars
  syscall               # print the char

  jr      $ra           # return to the calling procedure


#################### PRINT_INT_AND_SPACE ####################   
print_int_and_space:
  li    $v0, 1          # load the syscall option for printing ints
  syscall               # print the element

  li    $a0, 32         # print a black space (ASCII 32)
  li    $v0, 11         # load the syscall option for printing chars
  syscall               # print the char

  jr      $ra           # return to the calling procedure


#################### SINGLETON ####################   
is_singleton:
  li  $v0, 0
  beq $a0, 0, is_singleton_done   # return 0 if value == 0
  sub $a1, $a0, 1
  and $a1, $a0, $a1
  bne $a1, 0, is_singleton_done   # return 0 if (value & (value - 1)) == 0
  li  $v0, 1
is_singleton_done:
  jr  $ra


#################### GET_SINGLETON ####################   
get_singleton:
  li  $v0, 0      # i
  li  $t1, 1
gs_loop:sll $t2, $t1, $v0   # (1<<i)
  beq $t2, $a0, get_singleton_done
  add $v0, $v0, 1
  blt $v0, 9, gs_loop   # repeat if (i < 9)
get_singleton_done:
  jr  $ra


#################### PRINT BOARD ####################   
print_board:
  sub $sp, $sp, 20
  sw  $ra, 0($sp)   # save $ra and free up 4 $s registers for
  sw  $s0, 4($sp)   # i
  sw  $s1, 8($sp)   # j
  sw  $s2, 12($sp)    # the function argument
  sw  $s3, 16($sp)    # the computed pointer (which is used for 2 calls)
  move  $s2, $a0

  li  $s0, 0      # i
pb_loop1:
  li  $s1, 0      # j
pb_loop2:
  mul $t0, $s0, 9   # i*9
  add $t0, $t0, $s1   # (i*9)+j
  sll $t0, $t0, 2   # ((i*9)+j)*4
  add $s3, $s2, $t0
  lw  $a0, 0($s3)
  jal is_singleton    
  beq $v0, 0, pb_star   # if it was not a singleton, jump
  lw  $a0, 0($s3)
  jal get_singleton   
  add $a0, $v0, 1   # print the value + 1
  li  $v0, 1
  syscall
  j pb_cont

pb_star:    
  li  $v0, 4      # print a "*"
  la  $a0, star
  syscall

pb_cont:  
  add $s1, $s1, 1   # j++
  blt $s1, 9, pb_loop2

  li  $v0, 4      # at the end of a line, print a newline char.
  la  $a0, newline
  syscall 

  add $s0, $s0, 1   # i++
  blt $s0, 9, pb_loop1

  lw  $ra, 0($sp)   # restore registers and return
  lw  $s0, 4($sp)
  lw  $s1, 8($sp)
  lw  $s2, 12($sp)
  lw  $s3, 16($sp)
  add $sp, $sp, 20
  jr  $ra

get_square_begin:
  div $v0, $a0, 3
  mul $v0, $v0, 3
  jr  $ra

board_address:
  mul $v0, $a1, 9   # i*9
  add $v0, $v0, $a2   # (i*9)+j
  sll $v0, $v0, 2   # ((i*9)+j)*4
  add $v0, $a0, $v0
  jr  $ra

rule1:
  sub $sp, $sp, 32    
  sw  $ra, 0($sp)   # save $ra and free up 7 $s registers for
  sw  $s0, 4($sp)   # i
  sw  $s1, 8($sp)   # j
  sw  $s2, 12($sp)    # board
  sw  $s3, 16($sp)    # value
  sw  $s4, 20($sp)    # k
  sw  $s5, 24($sp)    # changed
  sw  $s6, 28($sp)    # temp
  move  $s2, $a0
  li  $s5, 0      # changed = false

  li  $s0, 0      # i = 0
r1_loop1:
  li  $s1, 0      # j = 0
r1_loop2:
  move  $a0, $s2    # board
  move  $a1, $s0    # i
  move  $a2, $s1    # j
  jal board_address
  lw  $s3, 0($v0)   # value = board[i][j]
  move  $a0, $s3    
  jal is_singleton
  beq $v0, 0, r1_loop2_bot  # if not a singleton, we can go onto the next iteration

  li  $s4, 0      # k = 0
r1_loop3:
  beq $s4, $s1, r1_skip_row # skip if (k == j)
  move  $a0, $s2    # board
  move  $a1, $s0    # i
  move  $a2, $s4    # k
  jal board_address
  lw  $t0, 0($v0)   # board[i][k]
  and $t1, $t0, $s3   
  beq $t1, 0, r1_skip_row
  not $t1, $s3
  and $t1, $t0, $t1   
  sw  $t1, 0($v0)   # board[i][k] = board[i][k] & ~value
  li  $s5, 1      # changed = true

r1_skip_row:
  beq $s4, $s0, r1_skip_col # skip if (k == i)
  move  $a0, $s2    # board
  move  $a1, $s4    # k
  move  $a2, $s1    # j
  jal board_address
  lw  $t0, 0($v0)   # board[k][j]
  and $t1, $t0, $s3   
  beq $t1, 0, r1_skip_col
  not $t1, $s3
  and $t1, $t0, $t1   
  sw  $t1, 0($v0)   # board[k][j] = board[k][j] & ~value
  li  $s5, 1      # changed = true

r1_skip_col:  
  add $s4, $s4, 1   # k++
  blt $s4, 9, r1_loop3

## doubly nested loop
  move  $a0, $s0    # i
  jal get_square_begin
  move  $s6, $v0    # ii
  move  $a0, $s1    # j
  jal get_square_begin  # jj
  move  $t0, $s6    # k = ii
  add   $s6, $v0, 3   # jj + GRIDSIZE
  add $t1, $t0, 3   # ii + GRIDSIZE

r1_loop4_outer:
  sub $t2, $s6, 3   # l = jj

r1_loop4_inner:
  bne $t0, $s0, r1_loop4_1
  beq $t2, $s1, r1_loop4_bot

r1_loop4_1: 
  mul $v0, $t0, 9   # k*9
  add $v0, $v0, $t2   # (k*9)+l
  sll $v0, $v0, 2   # ((k*9)+l)*4
  add $v0, $s2, $v0   # &board[k][l]
  lw  $v1, 0($v0)   # board[k][l]
    and $t3, $v1, $s3   # board[k][l] & value
  beq $t3, 0, r1_loop4_bot

  not $t3, $s3
  and $v1, $v1, $t3   
  sw  $v1, 0($v0)   # board[k][l] = board[k][l] & ~value
  li  $s5, 1      # changed = true

r1_loop4_bot: 
  add $t2, $t2, 1   # l++
  blt $t2, $s6, r1_loop4_inner

  add $t0, $t0, 1   # k++
  blt $t0, $t1, r1_loop4_outer


r1_loop2_bot: 
  add $s1, $s1, 1   # j++
  blt $s1, 9, r1_loop2

  add $s0, $s0, 1   # i++
  blt $s0, 9, r1_loop1

  move  $v0, $s5    # return changed
  lw  $ra, 0($sp)   # restore registers and return
  lw  $s0, 4($sp)
  lw  $s1, 8($sp)
  lw  $s2, 12($sp)
  lw  $s3, 16($sp)
  lw  $s4, 20($sp)
  lw  $s5, 24($sp)
  lw  $s6, 28($sp)
  add $sp, $sp, 32
  jr  $ra

## bool
## rule2(int board[GRID_SQUARED][GRID_SQUARED]) {
##  bool changed = false;
 ## for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
##	 for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
##		int value = board[i][j];
##		if (is_singleton(value)) {
##		  continue;
##		}
##		
##		int j_sum = 0, i_sum = 0;
##		for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
##		  if (k != j) {
##			 j_sum |= board[i][k]; 		  // summarize row
##		  }
##		  if (k != i) {
##			 i_sum |= board[k][j];       // summarize column
##		  }
##		}
##		if (ALL_VALUES != j_sum) {
##		  board[i][j] = ALL_VALUES & ~j_sum;
##		  changed = true;
##		  continue;
##		} else if (ALL_VALUES != i_sum) {
##		  board[i][j] = ALL_VALUES & ~i_sum;
##		  changed = true;
##		  continue;
##		}
##
##		// elimnate from square
##		int ii = get_square_begin(i);
##		int jj = get_square_begin(j);
##		int sum = 0;
##		for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
##		  for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
##			 if ((k == i) && (l == j)) {
##				continue;
##			 }
##			 sum |= board[k][l];
##		  }
##		}
##
##		if (ALL_VALUES != sum) {
##		  board[i][j] = ALL_VALUES & ~sum;
##		  changed = true;
##		} 
##	 }
##  }
##  return changed;
##}

rule2:
	sub	$sp, $sp, 36						## move the stack pointer
	sw	$ra, 0($sp)						## store the ra register and free up s registers
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

									## put the parameter into the s register
	move 	$s5, $a0						## board
	li	$s0, 0							## i
	li	$s1, 0							## j
	li	$s2, 0							## k
	li	$s3, 0							## l
	li	$s4, 0							## changed = false
	li  $t1, 1   # $t1 = 1
	
	sll	$s6, $t1, 9
	sub	$s6, $s6, 1						## ALL_VALUES 


rule_2_Ifor:
	
	bge	$s0, 9, rule_2_done					## for (int i = 0 ; i < GRID_SQUARED ; ++ i) 

rule_2_Jfor:

	bge	$s1, 9, rule_2_Ifor_increment				## for (int j = 0 ; j < GRID_SQUARED ; ++ j) 
									
	move	$a0, $s5						# board
	move 	$a1, $s0						# i
	move	$a2, $s1						# j
	jal	board_address

	lw	$s7, 0($v0)						## get the value
	move 	$a0, $s7

	jal	is_singleton						## if (is_singleton(value)) {

	beq	$v0, 1, rule_2_Jfor_increment				## continue

	li	$t0, 0							## i_sum
	li	$t1, 0							## j_sum

rule_2_Kfor:

	bge	$s2, 9, rule_2_done_k_loop				## for (int k = 0 ; k < GRID_SQUARED ; ++ k) 

	beq	$s2, $s1, rule_2_kif2					## if (k != j)
	move	$a0, $s5
	move	$a1, $s0
	move	$a2, $s2
	jal	board_address
	lw	$t5, 0($v0) 
	or	$t1, $t5, $s7						## j_sum |= board[i][k];

rule_2_kif2:

	beq	$s2, $s0, rule_2_Kfor_increment				## if (k != i) 
	move	$a0, $s5
	move	$a1, $s2
	move 	$a2, $s1
	jal 	board_address
	lw	$t5, 0($v0)
	or	$t0, $t5, $s7						## i_sum |= board[k][j];

	
rule_2_Kfor_increment:

	add 	$s2, $s2, 1						## k++
	j	rule_2_Kfor						## go do the K loop again


rule_2_done_k_loop:	

	beq	$s6, $t1, rule_2_if2					## if (ALL_VALUES != j_sum
									##board[i][j] = ALL_VALUES & ~j_sum;
	move	$a0, $s5
	move	$a1, $s0
	move	$a2, $s1
	sub	$sp, $sp, 8
	sw	$t0, 36($sp)
	sw	$t1, 40($sp)
	jal	board_address
	lw	$t0, 36($sp)
	lw	$t1, 40($sp)
	add	$sp, $sp, 8
	not	$t1, $t1
	and 	$t1, $t1, $s6
	lw	$t1, 0($v0)
	
	
	li	$s4, 1							##changed = true;
	j	rule_2_Jfor_increment					## continue

rule_2_if2:

	beq	$s5, $t0, rule_2_over_if				## else if (ALL_VALUES != i_sum)
									##board[i][j] = ALL_VALUES & ~i_sum	
	move	$a0, $s5
	move	$a1, $s0
	move 	$a2, $s1
	sub 	$sp, $sp, 4
	sw	$t0, 36($sp)
	jal	board_address
	lw	$t0, 36($sp)
	add	$sp, $sp, 4
	not	$t0, $t0
	and	$t0, $t0, $s6
	lw	$t0, 0($v0) 
	

	li	$s4, 1							##changed = true;
	j	rule_2_Jfor_increment					## continue

rule_2_over_if:

	move	$a0, $s0						## int ii = get_square_begin(i)
	jal 	get_square_begin
	move 	$s2, $v0
	move 	$t0, $v0						##ii

	move 	$a0, $s1						## int jj = get_square_begin(j)
	jal	get_square_begin
	move	$s3, $v0
	move	$t1, $v0						## jj

	li	$t3, 0							## sum = 0

rule_2_iiLoop:
	add	$t3, $t0, 3
	bge	$s2, $t3, rule_2_iiLoop_done				## for (int k = ii ; k < ii + GRIDSIZE ; ++ k) 
rule_2_jjLoop:
	
	add	$t4, $t1, 3
	bge	$s3, $t4, rule_2_incrementii				## for (int l = jj ; l < jj + GRIDSIZE ; ++ l)

	bne	$s2, $s0, over_jjif					## if ((k == i) && (l == j))	
	bne	$s3, $s1, over_jjif
	j	rule_2_Jfor_increment					## continue

over_jjif:
	mul	$t6, $s2, 9		# i*9				## sum |= board[k][l]
	add	$t6, $t6, $s3		# (i*9)+j
	sll	$t6, $t6, 2		# ((i*9)+j)*4
	add	$t6, $a0, $s5

	lw	$t7, 0($t6)
	or	$t3, $t3, $t7						## sum |= board[k][l];									

rule_2_incrementjj:
	add	$s3,$s3,1						## l++
	j	rule_2_jjLoop						## do the inner part of the loop again

rule_2_incrementii:
	add	$s2, $s2, 1						## k++
	li	$s3, 0							## l = 0
	j	rule_2_iiLoop						## do the loop again

rule_2_iiLoop_done:
	beq	$s6,$t3, rule_2_Jfor_increment				## if (ALL_VALUES != sum)
	move	$a0, $s5						## board[i][j] = ALL_VALUES & ~sum;
	move	$a1, $s0
	move	$a2, $s1
	sub	$sp, $sp, 4
	sw	$t3, 36($sp)
	jal	board_address
	lw	$t3, 36($sp)
	add	$sp, $sp,4
	not	$t3, $t3
	lw	$t0, 0($v0)
	and	$t0, $t0, $t3
	lw	$t0, 0($v0)

rule_2_Jfor_increment:
	
	add	$s1, $s1, 1						## j++
	j	rule_2_Jfor						## to back to inner for loop

rule_2_Ifor_increment:

	add	$s0, $s0, 1						##i++
	li	$s1, 0							##j = 0
	j	rule_2_Ifor						## go back to the for loop


rule_2_done:
	lw	$ra, 0($sp)						##restore the s registers and the stack pointer and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	
	add 	$sp,$sp,36
	move	$v0, $s4						## return changed
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


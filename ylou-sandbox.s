#~~~~~~~~~~~~~~~~~~~ DATA SECTION ~~~~~~~~~~~~~~~~~~~#

.data
    three:  .float 3.0
    five:   .float 5.0
    PI:     .float 3.14159
    F180:   .float 180.0
    newline:.asciiz "\n"        # useful for printing commands
    star:   .asciiz "*"
    # BOARD 1 IS THE COMPLETED BOARD
    board1: .word 128 8 256 16 32 64 4 2 1 64 32 4 1 128 2 8 16 256 1 2 16 4 8 256 32 64 128 32 16 1 64 256 4 2 128 8 4 256 2 128 16 8 64 1 32 8 128 64 32 2 1 16 256 4 2 1 128 8 4 16 256 32 64 16 4 32 256 64 128 1 8 2 256 64 8 2 1 32 128 4 16
    # BOARD 2 JUST HAS ONE ROW MISSING
    board2: .word 511 511 511 511 511 511 511 511 511 64 32 4 1 128 2 8 16 256 1 2 16 4 8 256 32 64 128 32 16 1 64 256 4 2 128 8 4 256 2 128 16 8 64 1 32 8 128 64 32 2 1 16 256 4 2 1 128 8 4 16 256 32 64 16 4 32 256 64 128 1 8 2 256 64 8 2 1 32 128 4 16
    # BOARD 2 JUST HAS ONE COLUMN MISSING
    board3: .word 511 8 256 16 32 64 4 2 1 511 32 4 1 128 2 8 16 256 511 2 16 4 8 256 32 64 128 511 16 1 64 256 4 2 128 8 511 256 2 128 16 8 64 1 32 511 128 64 32 2 1 16 256 4 511 1 128 8 4 16 256 32 64 511 4 32 256 64 128 1 8 2 511 64 8 2 1 32 128 4 16
    board4: # BOARD 4 HAS 3 SQUARES THAT HAVE 1 NUMBER MISSING TO TEST THE SQUARE PART.
    .word 128 8 256 511 511 511 511 511 511 
    .word 64 32 4 511 511 511 511 511 511 
    .word 511 2 16 511 511 511 511 511 511
    .word 511 511 511 64 511 256 511 511 511 
    .word 511 511 511 128 32 4 511 511 511 
    .word 511 511 511 8 16 2 511 511 511 
    .word 511 511 511 511 511 511 128 32 16 
    .word 511 511 511 511 511 511 64 8 511 
    .word 511 511 511 511 511 511 1 2 256
    # board 5 is the actual test for this MP
    board5: .word 128 511 511 16 511 511 4 2 511 64 511 4 1 511 511 8 511 511 1 2 511 511 511 256 511 511 128 32 16 511 511 256 4 511 128 511 511 256 511 511 511 511 511 1 511 511 128 511 32 2 511 511 256 4 2 511 511 8 511 511 511 32 64 511 511 32 511 511 128 1 511 2 511 64 8 511 511 32 511 511 16

    flag: .word 0x8

#~~~~~~~~~~~~~~~~~~~ TEXT SECTION ~~~~~~~~~~~~~~~~~~~#

.text
#################### MAIN ####################   
main:   
    sub     $sp, $sp, 24            # save $s registers on stack
    sw      $s0, 0($sp)             #
    sw      $s1, 4($sp)             #
    sw      $s2, 8($sp)             #
    sw      $s3, 12($sp)            #
    sw      $s4, 16($sp)            #
    sw      $ra, 20($sp) 
  
    # flag for bonk, kick, sudoku, and timer and global interrupt enable
    li      $t4, 0xF001     
    mtc0    $t4, $12            # Enable interrupt mask (Status register)
    
loop:
    lw      $t0, flag
    
    andi    $t1, $t0, 0x8
    bgt     $t1, $zero, drive_kick # if $t0 > $zero then solve_puzzle

    j loop

#+++++++++ SOLVE PUZZLE BRANCH +++++++++#
solve_puzzle:
    j     loop 
    
#+++++++++ DRIVE AND KICK BRANCH +++++++++#
drive_kick:
    li      $s0, 0                # ball counter
ball_search:
    sw      $s0, 0xffff00d0         # set query to ball counter

    lw      $s1, 0xffff0020         # spimbot x coordinate
    lw      $s2, 0xffff0024         # spimbot y coordinate

    lw      $s3, 0xffff00d4         # ball x coordinate
    lw      $s4, 0xffff00d8         # ball y coordinate

    beq     $s3, -1, search_end        # if the ball is not on map, check next ball

    sub     $a0, $s3, $s1           # delta x
    sub     $a1, $s4, $s2           # delta y

    jal arctan              # calculates the turn angle for spimbot to ball

    sw      $v0, 0xffff0014($0) # set angle
    li      $v0, 1                  # set absolute angle
    sw      $v0, 0xffff0018($0)     #
    
    li      $s1, 10                 #
    sw      $s1, 0xffff0010     # set spimbot velocity
    
kick_check:                         # spimbot will stop when he kicks a ball
    lw      $s1, 0xffff0010         # load spimbot velocity
    bne     $s1, 0, kick_check      # if he hasn't been stopped, keep polling
    
search_end:
    add     $s0, $s0, 1             # ball counter ++
    # REMEMBER TO CHANGE THIS EVERY QUARTER
    bgt     $s0, 2, end             # no more balls, quit
    j       ball_search

end:    # never reached, but here for yucks.
    lw      $s0, 0($sp)             # restore registers from stack
    lw      $s1, 4($sp)             
    lw      $s2, 8($sp)             
    lw      $s3, 12($sp)            
    lw      $s4, 16($sp)
    lw      $ra, 20($sp)   
                
    add     $sp, $sp, 24        
    jr      $ra

#################### ARCTAN ####################   
arctan:                  # a0 = delta_x, a1 = delta_y
                         # t0 = abs(a0), t1 = abs(a1)
    abs     $t0, $a0     # t0 = |delta_x|
    abs     $t1, $a1     # t1 = |delta_y|
    li      $v0, 0       # v0 = angle
    ble     $t1, $t0, no_TURN_90

                                   # if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $v0, $a1       # temp = y
    sub     $a1, $0, $a0          # y = -x
    move    $a0, $v0        # x = temp
    li      $v0, 90               # angle = 90.0

no_TURN_90:
    bge     $a0, $0, pos_x       # skip if (x >= 0.0)
    addi    $v0, $v0, 180

pos_x:  
    mtc1    $a0, $f0
    mtc1    $a1, $f1
    cvt.s.w $f0, $f0           # convert from ints to floats
    cvt.s.w $f1, $f1

    div.s   $f0, $f1, $f0      # float v = (float) y / (float) x;
    mul.s   $f1, $f0, $f0      # v^^2
    mul.s   $f2, $f1, $f0      # v^^3
    l.s     $f3, three($0)     # load 3.0
    div.s   $f3, $f2, $f3      # v^^3/3
    sub.s   $f6, $f0, $f3      # v - v^^3/3
    mul.s   $f4, $f1, $f2      # v^^5
    l.s     $f5, five($0)      # load 5.0
    div.s   $f5, $f4, $f5      # v^^5/5
    add.s   $f6, $f6, $f5      # value = v - v^^3/3 + v^^5/5

    l.s     $f8, PI($0)        # load PI
    div.s   $f6, $f6, $f8      # value / PI
    l.s     $f7, F180($0)      # load 180.0
    mul.s   $f6, $f6, $f7      # 180.0 * value / PI

    cvt.w.s $f6, $f6           # convert "delta" back to integer
    mfc1    $a0, $f6
    add     $v0, $v0, $a0      # angle += delta

    jr      $ra

solve_board:
    sub     $sp, $sp, 8
    sw      $ra, 0($sp) # save $ra on stack
    sw      $s0, 4($sp)     # save $s0 on stack <--- check out use of $s register!!
    move    $s0, $a0
main_loop:
    move    $a0, $s0
    jal     rule1
    bne     $v0, 0, main_loop   # keep running rule1 until no more changes

    lw      $ra, 0($sp)     # restore $ra
    lw      $s0, 4($sp)     # restore $s0 
    add     $sp, $sp, 8
    jr      $ra

#################### PRINT_NEWLINE ####################     
print_newline:
    lb      $a0, newline($0)            # read the newline char
    li      $v0, 11            # load the syscall option for printing chars
    syscall                  # print the char

    jr      $ra              # return to the calling procedure


#################### PRINT_INT_AND_SPACE ####################     
print_int_and_space:
    li      $v0, 1             # load the syscall option for printing ints
    syscall                  # print the element

    li      $a0, 32            # print a black space (ASCII 32)
    li      $v0, 11            # load the syscall option for printing chars
    syscall                  # print the char

    jr      $ra              # return to the calling procedure


#################### SINGLETON ####################     
is_singleton:
    li      $v0, 0
    beq     $a0, 0, is_singleton_done       # return 0 if value == 0
    sub     $a1, $a0, 1
    and     $a1, $a0, $a1
    bne     $a1, 0, is_singleton_done       # return 0 if (value & (value - 1)) == 0
    li      $v0, 1
is_singleton_done:
    jr      $ra


#################### GET_SINGLETON ####################     
get_singleton:
    li      $v0, 0          # i
    li      $t1, 1
gs_loop:
    sll     $t2, $t1, $v0       # (1<<i)
    beq     $t2, $a0, get_singleton_done
    add     $v0, $v0, 1
    blt     $v0, 9, gs_loop     # repeat if (i < 9)
get_singleton_done:
    jr      $ra


#################### PRINT BOARD ####################     
print_board:
    sub     $sp, $sp, 20
    sw      $ra, 0($sp)     # save $ra and free up 4 $s registers for
    sw      $s0, 4($sp)     # i
    sw      $s1, 8($sp)     # j
    sw      $s2, 12($sp)        # the function argument
    sw      $s3, 16($sp)        # the computed pointer (which is used for 2 calls)
    move    $s2, $a0

    li      $s0, 0          # i
pb_loop1:
    li      $s1, 0          # j
pb_loop2:
    mul     $t0, $s0, 9     # i*9
    add     $t0, $t0, $s1       # (i*9)+j
    sll     $t0, $t0, 2     # ((i*9)+j)*4
    add     $s3, $s2, $t0
    lw      $a0, 0($s3)
    jal     is_singleton        
    beq     $v0, 0, pb_star     # if it was not a singleton, jump
    lw      $a0, 0($s3)
    jal     get_singleton       
    add     $a0, $v0, 1     # print the value + 1
    li      $v0, 1
    syscall
    j       pb_cont

pb_star:      
    li      $v0, 4          # print a "*"
    la      $a0, star
    syscall

pb_cont:  
    add     $s1, $s1, 1     # j++
    blt     $s1, 9, pb_loop2

    li      $v0, 4          # at the end of a line, print a newline char.
    la      $a0, newline
    syscall 

    add     $s0, $s0, 1     # i++
    blt     $s0, 9, pb_loop1

    lw      $ra, 0($sp)     # restore registers and return
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    lw      $s2, 12($sp)
    lw      $s3, 16($sp)
    add     $sp, $sp, 20
    jr      $ra


  ## int get_square_begin(int index) {
  ##   return (index/GRIDSIZE) * GRIDSIZE;
  ## }

get_square_begin:
    div     $v0, $a0, 3
    mul     $v0, $v0, 3
    jr      $ra

  # ALL your code goes below this line.
  #
  # We will delete EVERYTHING above the line; DO NOT delete 
  # the line.
  #
  # ---------------------------------------------------------------------

  ## bool
  ## rule1(int board[9][9]) {
  ##   bool changed = false;
  ##   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
  ##      for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
  ##        int value = board[i][j];
  ##        if (singleton(value)) {
  ##          for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
  ##             // eliminate from row
  ##             if (k != j) {
  ##                if (board[i][k] & value) {
  ##                  changed = true;
  ##                }
  ##                board[i][k] &= ~value;
  ##             }
  ##             // eliminate from column
  ##             if (k != i) {
  ##                if (board[k][j] & value) {
  ##                  changed = true;
  ##                }
  ##                board[k][j] &= ~value;
  ##             }
  ##          }
  ## 
  ##          // eliminate from square
  ##          int ii = get_square_begin(i);
  ##          int jj = get_square_begin(j);
  ##          for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
  ##               for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
  ##                if ((k == i) && (l == j)) {
  ##                  continue;
  ##                }
  ##                if (board[k][l] & value) {
  ##                  changed = true;
  ##                }
  ##                board[k][l] &= ~value;
  ##               }
  ##          }
  ##        }
  ##      }
  ##   }
  ##   return changed;
  ## }

board_address:
    mul     $v0, $a1, 9     # i*9
    add     $v0, $v0, $a2       # (i*9)+j
    sll     $v0, $v0, 2     # ((i*9)+j)*4
    add     $v0, $a0, $v0
    jr      $ra

rule1:
    sub     $sp, $sp, 32        
    sw      $ra, 0($sp)     # save $ra and free up 7 $s registers for
    sw      $s0, 4($sp)     # i
    sw      $s1, 8($sp)     # j
    sw      $s2, 12($sp)        # board
    sw      $s3, 16($sp)        # value
    sw      $s4, 20($sp)        # k
    sw      $s5, 24($sp)        # changed
    sw      $s6, 28($sp)        # temp
    move    $s2, $a0
    li      $s5, 0          # changed = false

    li      $s0, 0          # i = 0
r1_loop1:
    li      $s1, 0          # j = 0
r1_loop2:
    move    $a0, $s2        # board
    move    $a1, $s0        # i
    move    $a2, $s1        # j
    jal     board_address
    lw      $s3, 0($v0)     # value = board[i][j]
    move    $a0, $s3        
    jal     is_singleton
    beq     $v0, 0, r1_loop2_bot    # if not a singleton, we can go onto the next iteration

    li      $s4, 0          # k = 0
r1_loop3:
    beq     $s4, $s1, r1_skip_row   # skip if (k == j)
    move    $a0, $s2        # board
    move    $a1, $s0        # i
    move    $a2, $s4        # k
    jal     board_address
    lw      $t0, 0($v0)     # board[i][k]
    and     $t1, $t0, $s3       
    beq     $t1, 0, r1_skip_row
    not     $t1, $s3
    and     $t1, $t0, $t1       
    sw      $t1, 0($v0)     # board[i][k] = board[i][k] & ~value
    li      $s5, 1          # changed = true

r1_skip_row:
    beq     $s4, $s0, r1_skip_col   # skip if (k == i)
    move    $a0, $s2        # board
    move    $a1, $s4        # k
    move    $a2, $s1        # j
    jal     board_address
    lw      $t0, 0($v0)     # board[k][j]
    and     $t1, $t0, $s3       
    beq     $t1, 0, r1_skip_col
    not     $t1, $s3
    and     $t1, $t0, $t1       
    sw      $t1, 0($v0)     # board[k][j] = board[k][j] & ~value
    li      $s5, 1          # changed = true

r1_skip_col:  
    add     $s4, $s4, 1     # k++
    blt     $s4, 9, r1_loop3

  ## doubly nested loop
    move    $a0, $s0        # i
    jal     get_square_begin
    move    $s6, $v0        # ii
    move    $a0, $s1        # j
    jal     get_square_begin    # jj
    move    $t0, $s6        # k = ii
    add     $s6, $v0, 3     # jj + GRIDSIZE
    add     $t1, $t0, 3     # ii + GRIDSIZE

r1_loop4_outer:
    sub     $t2, $s6, 3     # l = jj

r1_loop4_inner:
    bne     $t0, $s0, r1_loop4_1
    beq     $t2, $s1, r1_loop4_bot

r1_loop4_1:   
    mul     $v0, $t0, 9     # k*9
    add     $v0, $v0, $t2       # (k*9)+l
    sll     $v0, $v0, 2     # ((k*9)+l)*4
    add     $v0, $s2, $v0       # &board[k][l]
    lw      $v1, 0($v0)     # board[k][l]
    and     $t3, $v1, $s3       # board[k][l] & value
    beq     $t3, 0, r1_loop4_bot

    not     $t3, $s3
    and     $v1, $v1, $t3       
    sw      $v1, 0($v0)     # board[k][l] = board[k][l] & ~value
    li      $s5, 1          # changed = true

r1_loop4_bot: 
    add     $t2, $t2, 1     # l++
    blt     $t2, $s6, r1_loop4_inner

    add     $t0, $t0, 1     # k++
    blt     $t0, $t1, r1_loop4_outer

r1_loop2_bot: 
    add     $s1, $s1, 1     # j++
    blt     $s1, 9, r1_loop2

    add     $s0, $s0, 1     # i++
    blt     $s0, 9, r1_loop1

    move    $v0, $s5        # return changed
    lw      $ra, 0($sp)     # restore registers and return
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    lw      $s2, 12($sp)
    lw      $s3, 16($sp)
    lw      $s4, 20($sp)
    lw      $s5, 24($sp)
    lw      $s6, 28($sp)
    add     $sp, $sp, 32
    jr      $ra

#~~~~~~~~~~~~~~~~~~~ KERNEL DATA SECTION ~~~~~~~~~~~~~~~~~~~#

.kdata 
save:             .space 64
kstack_bot:       .space 1000       # allocate some space for a kernel stack
kstack:           .word 0           # this is the top of stack (stack grows down)
non_intrpt_str:   .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"

.ktext 0x80000080
interrupt_handler:
.set noat
    move    $k1, $at            # Save $at
.set at
    la      $k0, save

    sw      $a0, 0($k0)         # Get some free registers
    sw      $a1, 4($k0)         # by storing them to a global variable
    
    mfc0    $k0, $13            # Get Cause register
    srl     $a0, $k0, 2     
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt

interrupt_dispatch:             # Interrupt:
    mfc0    $k0, $13            # Get Cause register, again
    beq     $k0, $zero, done    # handled all outstanding interrupts

    and     $a0, $k0, 0x1000    # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt  

    and     $a0, $k0, 0x2000    # is there a kick interrupt?
    bne     $a0, 0, kick_interrupt  

    and     $a0, $k0, 0x4000    # is there a kick interrupt?
    bne     $a0, 0, timer_interrupt  

    and     $a0, $k0, 0x8000    # is there a kick interrupt?
    bne     $a0, 0, sudoku_interrupt  

    li      $v0, 4              # unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    b       done

#~~~~~~~~~~~~~~~~~~~ INTERRUPT HANDLER SECTION ~~~~~~~~~~~~~~~~~~~#

#################### BONK INTERRUPT ####################  
bonk_interrupt:
    li      $a1, 1
    sw      $a1, 0xffff0060($zero)  # acknowledge interrupt

    b       interrupt_dispatch  # see if other interrupts are waiting

#################### KICK INTERRUPT ####################  
kick_interrupt:
    li      $a1, 1
    sw      $a1, 0xffff0064($zero)      # acknowledge interrupt

    b       interrupt_dispatch      # see if other interrupts are waiting

#################### TIMER INTERRUPT ####################  
timer_interrupt:
    li      $a1, 1
    sw      $a1, 0xffff0068($zero)      # acknowledge interrupt

    b       interrupt_dispatch

#################### SUDOKU INTERRUPT ####################  
sudoku_interrupt:
    li      $a1, 1
    sw      $a1, 0xffff006c($zero)      # acknowledge interrupt

    b       interrupt_dispatch

#################### NON INTERRUPT ####################  
non_intrpt:             # was some non-interrupt
    li      $v0, 4          
    la      $a0, non_intrpt_str
    syscall             # print out an error message
    b       done

done:
    la      $k0, save
    lw      $a0, 0($k0)     # Restore regsiters
    lw      $a1, 4($k0)     #

    mfc0    $k0 $14         # EPC
.set noat
    move    $at $k1         # Restore $at
.set at
    rfe             # Return from exception handler
    jr      $k0
    nop
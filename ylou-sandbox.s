#~~~~~~~~~~~~~~~~~~~ DATA SECTION ~~~~~~~~~~~~~~~~~~~#

.data
    three:  .float 3.0
    five:   .float 5.0
    PI:     .float 3.14159
    F180:   .float 180.0
    newline:.asciiz "\n"        # useful for printing commands
    star:   .asciiz "*"

    puzzle_flag: .word 0
    puzzle: .space 324
 

#~~~~~~~~~~~~~~~~~~~ TEXT SECTION ~~~~~~~~~~~~~~~~~~~#

.text
#################### MAIN ####################   
main:     
    # flag for bonk, kick, sudoku, and timer and global interrupt enable
    li      $t4, 0xF001     
    mtc0    $t4, $12            # Enable interrupt mask (Status register)
    la      $t0, puzzle($zero)
    sw      $t0, 0xffff00e8($zero)
    loop:
    jal drive_kick # if $t0 > $zero then solve_puzzle
    j loop

#+++++++++ SOLVE PUZZLE BRANCH +++++++++#

solve_puzzle:
  la    $a0, puzzle($zero)
  jal   solve_board        # jump to solve_board and save position to $ra
  
  la    $a0, puzzle($zero)
  sw    $a0, 0xffff00ec($zero) #turn in the puzzle
 
  sw    $zero, puzzle_flag
  la    $t0, puzzle($zero)   
  sw    $t0, 0xffff00e8($zero)
  j     kick_check       # jump to loop

solve_board:
  sub   $sp, $sp, 16
  sw    $ra, 0($sp) # save $ra on stack
  sw    $s0, 4($sp)   # save $s0 on stack <--- check out use of $s register!!
  sw    $s1, 8($sp)
  sw  $s2, 12($sp)    

  move  $s0, $a0
main_loop:
  move  $a0, $s0
  jal rule1     ##changed = rule1(main_board)
  move  $s1, $v0
  move  $a0, $s0
  jal   rule2     ##changed |= rule2(main_board)
  move  $s2, $v0      
  or  $s1, $s1, $s2   
  beq $s1, 1, main_loop ##do while(changed)

  lw    $ra, 0($sp)   # restore $ra
  lw    $s0, 4($sp)   # restore $s0 
  lw    $s1, 8($sp)     ## restore $s1
  lw  $s2, 12($sp)  ##restore $s2

  add   $sp, $sp, 16
  jr  $ra
    
#+++++++++ DRIVE AND KICK BRANCH +++++++++#
drive_kick:
    sub     $sp, $sp, 24            # save $s registers on stack
    sw      $s0, 0($sp)             #
    sw      $s1, 4($sp)             #
    sw      $s2, 8($sp)             #
    sw      $s3, 12($sp)            #
    sw      $s4, 16($sp)            #
    sw      $ra, 20($sp) 

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
   
    lw      $t0, puzzle_flag
    bgt     $t0, $zero, solve_puzzle

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


rule2:
  sub $sp, $sp, 48            ## move the stack pointer
  sw  $ra, 0($sp)           ## store the ra register and free up s registers
  sw  $s0, 4($sp)
  sw  $s1, 8($sp)
  sw  $s2, 12($sp)
  sw  $s3, 16($sp)
  sw  $s4, 20($sp)
  sw  $s5, 24($sp)
  sw  $s6, 28($sp)
  sw  $s7, 32($sp)

                  ## put the parameter into the s register
  li  $s0, 0              ## i
  li  $s1, 0              ## j
  li  $s2, 0              ## k
  li  $s3, 0              ## l
  li  $s4, 0              ## changed = false
  move  $s5, $a0            ##board
  

                  ## $s7 holds board[i][j] for each iteration of the loop
  li  $t0, 1
  li  $t1, 9
  sll $s6, $t0, $t1
  sub $s6, $s6, 1           ## ALL_VALUES 


rule_2_Ifor:
  
  bge $s0, 9, rule_2_done         ## for (int i = 0 ; i < GRID_SQUARED ; ++ i) 

rule_2_Jfor:
  
  li  $s2, 0
  li  $s3, 0
  bge $s1, 9, rule_2_Ifor_increment       ## for (int j = 0 ; j < GRID_SQUARED ; ++ j) 
                  
  move  $a0, $s5            # board
  move  $a1, $s0            # i
  move  $a2, $s1            # j
  jal board_address

  lw  $s7, 0($v0)           ## board[i][j]
  move  $a0, $s7

  jal is_singleton            ## if (is_singleton(value)) {

  li  $t0, 1
  beq $v0, $t0, rule_2_Jfor_increment       ## continue

  li  $t0, 0              ## i_sum
  li  $t1, 0              ## j_sum

rule_2_Kfor:
  
  bge $s2, 9, rule_2_done_k_loop        ## for (int k = 0 ; k < GRID_SQUARED ; ++ k) 

  beq $s2, $s1, rule_2_kif2         ## if (k != j)
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s2
  sw  $t0, 36($sp)
  sw  $t1, 40($sp)
  jal board_address           ##get place of board[i][k]
  lw  $t0, 36($sp)            ##restore i_sum
  lw  $t1, 40($sp)            ##restore j_sum
  lw  $t5, 0($v0)             ##board[i][k]
  or  $t1, $t1, $t5           ## j_sum |= board[i][k];

rule_2_kif2:

  beq $s2, $s0, rule_2_Kfor_increment       ## if (k != i) 
  move  $a0, $s5
  move  $a1, $s2
  move  $a2, $s1
  sw  $t0, 36($sp)            ##store i_sum
  sw  $t1, 40($sp)            ##store j_sum
  jal   board_address           ##get place of board[k][j]
  lw  $t0, 36($sp)            ## restore i_sum
  lw  $t1, 40($sp)            ## restore j_sum
  lw  $t5, 0($v0)           ## value of board[k][j]
  or  $t0, $t0, $t5           ## i_sum |= board[k][j];

  
rule_2_Kfor_increment:

  add   $s2, $s2, 1           ## k++
  j rule_2_Kfor           ## go do the K loop again


rule_2_done_k_loop: 

  beq $s6, $t1, rule_2_if2          ## if (ALL_VALUES != j_sum
                  ##board[i][j] = ALL_VALUES & ~j_sum;
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s1
  sw  $t0, 36($sp)            ## store i_sum
  sw  $t1, 40($sp)            ## store j_sum
  jal board_address           ## get place of board[i][j]
  lw  $t0, 36($sp)            ## restore i_sum
  lw  $t1, 40($sp)            ## restore j_sum
  not $t3, $t1            ## ~j_sum           
  and   $t3, $t3, $s6           ## ALL_VALUES & ~j_sum
  sw  $t3, 0($v0)           ## load it at board[i][j]
  
  
  li  $s4, 1              ##changed = true;
  j rule_2_Jfor_increment         ## continue

rule_2_if2:

  beq $s6, $t0, rule_2_over_if        ## else if (ALL_VALUES != i_sum)
                  ##board[i][j] = ALL_VALUES & ~i_sum 
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s1
  sw  $t0, 36($sp)            ##store i_sum
  sw  $t1, 40($sp)            ## store j_sum
  jal board_address           ## get place of board[i][j]
  lw  $t0, 36($sp)            ## restore i_sum
  lw  $t1, 40($sp)            ## restore j_sum
  not $t3, $t0            ## ~i_sum
  and $t3, $t3, $s6           ## ALL_VALUES & i_sum
  sw  $t3, 0($v0)             ## store it at board[i][j]
  

  li  $s4, 1              ##changed = true;
  j rule_2_Jfor_increment         ## continue

rule_2_over_if:

  move  $a0, $s0            ## int ii = get_square_begin(i)
  jal   get_square_begin
  move  $s2, $v0

  move  $a0, $s1            ## int jj = get_square_begin(j)
  jal get_square_begin
  move  $s3, $v0
  move  $t0, $s2            ## ii
  move  $t1, $v0            ## jj

  li  $t3, 0              ## sum = 0

rule_2_iiLoop:
  add $t5, $t0, 3
  bge $s2, $t5, rule_2_iiLoop_done        ## for (int k = ii ; k < ii + GRIDSIZE ; ++ k) 
rule_2_jjLoop:
  
  add $t4, $t1, 3
  bge $s3, $t4, rule_2_incrementii        ## for (int l = jj ; l < jj + GRIDSIZE ; ++ l)

  bne $s2, $s0, over_jjif         ## if ((k == i) && (l == j))  
  bne $s3, $s1, over_jjif
  j rule_2_Jfor_increment         ## continue

over_jjif:

  move  $a0, $s5
  move  $a1, $s2
  move  $a2, $s3
  sw  $t3, 36($sp)
  sw  $t0, 40($sp)
  sw  $t1, 44($sp)
  
                  ## sum |= board[k][l]
  
  jal board_address
  lw  $t3, 36($sp)
  lw  $t0, 40($sp)
  lw  $t1, 44($sp)

  lw  $t7, 0($v0)
  or  $t3, $t7, $t3           ## sum |= board[k][l];                  

rule_2_incrementjj:
  add $s3,$s3,1           ## l++
  j rule_2_jjLoop           ## do the inner part of the loop again

rule_2_incrementii:
  add $s2, $s2, 1           ## k++
  move  $s3, $t1            ## l = jj
  j rule_2_iiLoop           ## do the loop again

rule_2_iiLoop_done:
  beq $s6,$t3, rule_2_Jfor_increment        ## if (ALL_VALUES != sum)
  move  $a0, $s5            ## board[i][j] = ALL_VALUES & ~sum;
  move  $a1, $s0
  move  $a2, $s1
  sw  $t3, 36($sp)
  jal board_address
  lw  $t3, 36($sp)
  not $t3, $t3
  and $t0, $s6, $t3
  sw  $t0, 0($v0)

rule_2_Jfor_increment:
  
  add $s1, $s1, 1           ## j++
  j rule_2_Jfor           ## to back to inner for loop

rule_2_Ifor_increment:

  add $s0, $s0, 1           ##i++
  li  $s1, 0              ##j = 0
  li  $s2, 0              ##k = 0
  li  $s3, 0              ##l = 0
  j rule_2_Ifor           ## go back to the for loop


rule_2_done:
  move  $v0, $s4            ## return changed
  lw  $ra, 0($sp)           ##restore the s registers and the stack pointer and return
  lw  $s0, 4($sp)
  lw  $s1, 8($sp)
  lw  $s2, 12($sp)
  lw  $s3, 16($sp)
  lw  $s4, 20($sp)
  lw  $s5, 24($sp)
  lw  $s6, 28($sp)
  lw  $s7, 32($sp)
  
  add   $sp,$sp,48
  # move  $v0, $s4            ## return changed
  jr  $ra

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

    and     $a0, $k0, 0x8000    # is there a kick interrupt?
    bne     $a0, 0, timer_interrupt  

    and     $a0, $k0, 0x4000    # is there a kick interrupt?
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
   li  $a1, 0
search_loop:                    # check every ball for kicking
    bgt $a1, 10, search_loop_done

    sw  $a1, 0xffff00d0         # set query to a1
    lw  $a0, 0xffff00e4         # can the ball be kicked?

    beq $a0, 1, search_loop_done    # if it can, we are done searching
    
    add $a1, $a1, 1                 # check next ball
    b   search_loop

search_loop_done:
    sw  $a1, 0xffff00d0         # set query to ball counter

    lw  $a0, 0xffff00d4         # ball x coordinate
    li  $a1, 300                # goal x coordinate
    sub $a0, $a1, $a0           # delta x

    lw  $a1, 0xffff00d8         # ball y coordinate
    li  $k0, 150                # goal y coordinate
    sub $a1, $k0, $a1           # delta y

    la      $k0, save       # save all the caller-saved registers used 
    sw  $ra, 8($k0)         # in the arctan call.   
    sw  $v0, 12($k0)            # honestly, we should save all of the caller
    sw  $t0, 16($k0)            # saved registers
    sw      $t1, 20($k0)            
    s.s     $f0, 24($k0)            # save the floating point registers used
    s.s     $f1, 28($k0)            # by arctan, for good measure.
    s.s     $f2, 32($k0)            
    s.s     $f3, 36($k0)            # s.s is a load into a floating point register
    s.s     $f4, 40($k0)            
    s.s     $f5, 44($k0)            
    s.s     $f6, 48($k0)            
    s.s     $f7, 52($k0)            
    s.s     $f8, 56($k0)            
    sw      $sp, 60($k0)            # save stack pointer
    la  $sp, kstack     # use the kernel stack (always start from top)

    la      $t0, arctan             
    jalr    $t0             # calculate kick angle
    sw  $v0, 0xffff00c4($zero)      # set kick orientation

    lw      $ra, 8($k0)         # restore all registers used in the arctan call
    lw  $v0, 12($k0)            
    lw  $t0, 16($k0)
    lw  $t1, 20($k0)
    l.s     $f0, 24($k0)            # restore the floating point registers used
    l.s     $f1, 28($k0)            # by arctan
    l.s     $f2, 32($k0)            
    l.s     $f3, 36($k0)            # l.f is a load into a floating point register
    l.s     $f4, 40($k0)            
    l.s     $f5, 44($k0)            
    l.s     $f6, 48($k0)            
    l.s     $f7, 52($k0)            
    l.s     $f8, 56($k0)            
    lw      $sp, 60($k0)            # restore  stack pointer

    li  $a1, 99
    sw  $a1, 0xffff00c8($zero)      # set the energy

    li  $a1, 1
    sw  $a1, 0xffff0064($zero)      # acknowledge interrupt

    b   interrupt_dispatch      # see if other interrupts are waiting


#################### TIMER INTERRUPT ####################  
timer_interrupt:
    li      $a1, 1
    sw      $a1, 0xffff006c($zero)      # acknowledge interrupt

    b       interrupt_dispatch

#################### SUDOKU INTERRUPT ####################  
sudoku_interrupt:
  li    $a0, 1
  sw    $a0, puzzle_flag

    li      $a1, 1
    sw      $a1, 0xffff0068($zero)      # acknowledge interrupt

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
## bool
## rule2(int board[GRID_SQUARED][GRID_SQUARED]) {
##  bool changed = false;
 ## for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
##   for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
##    int value = board[i][j];
##    if (is_singleton(value)) {
##      continue;
##    }
##    
##    int j_sum = 0, i_sum = 0;
##    for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
##      if (k != j) {
##       j_sum |= board[i][k];      // summarize row
##      }
##      if (k != i) {
##       i_sum |= board[k][j];       // summarize column
##      }
##    }
##    if (ALL_VALUES != j_sum) {
##      board[i][j] = ALL_VALUES & ~j_sum;
##      changed = true;
##      continue;
##    } else if (ALL_VALUES != i_sum) {
##      board[i][j] = ALL_VALUES & ~i_sum;
##      changed = true;
##      continue;
##    }
##
##    // elimnate from square
##    int ii = get_square_begin(i);
##    int jj = get_square_begin(j);
##    int sum = 0;
##    for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
##      for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
##       if ((k == i) && (l == j)) {
##        continue;
##       }
##       sum |= board[k][l];
##      }
##    }
##
##    if (ALL_VALUES != sum) {
##      board[i][j] = ALL_VALUES & ~sum;
##      changed = true;
##    } 
##   }
##  }
##  return changed;
##}

board_address:
  mul $v0, $a1, 9   # i*9
  add $v0, $v0, $a2   # (i*9)+j
  sll $v0, $v0, 2   # ((i*9)+j)*4
  add $v0, $a0, $v0
  jr  $ra

rule2:
  sub $sp, $sp, 36            ## move the stack pointer
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
  move  $s5, $a0            ## board
  li  $s0, 0              ## i
  li  $s1, 0              ## j
  li  $s2, 0              ## k
  li  $s3, 0              ## l
  li  $s4, 0              ## changed = false
  
  sll $s6, 1, 9
  sub $s6, $s6 1            ## ALL_VALUES 


rule_2_Ifor:
  
  bge $s0, 9, rule_2_done         ## for (int i = 0 ; i < GRID_SQUARED ; ++ i) 

rule_2_Jfor:

  bge $s1, 9, rule_2_Ifor_increment       ## for (int j = 0 ; j < GRID_SQUARED ; ++ j) 
                  
  move  $a0, $s5            # board
  move  $a1, $s0            # i
  move  $a2, $s1            # j
  jal board_address

  lw  $s7, 0($v0)           ## get the value
  move  $a0, $s7

  jal is_singleton            ## if (is_singleton(value)) {

  beq $v0, 1, rule_2_Jfor_increment       ## continue

  li  $t0, 0              ## i_sum
  li  $t1, 0              ## j_sum

rule_2_Kfor:

  bge $s2, 9, rule_2_done_k_loop        ## for (int k = 0 ; k < GRID_SQUARED ; ++ k) 

  beq $s2, $s1, rule_2_kif_2          ## if (k != j)
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s2
  jal board_address
  lw  $t5, 0($v0) 
  or  $t1, $t5, $s7           ## j_sum |= board[i][k];

rule_2_kif2:

  beq $s2, $s0, rule_2_Kfor_increment       ## if (k != i) 
  move  $a0, $s5
  move  $a1, $s2
  move  $a2, $s1
  jal   board_address
  lw  $t5, 0($v0)
  or  $t0, $t5, $s7           ## i_sum |= board[k][j];

  
rule_2_Kfor_increment:

  add   $s2, $s2, 1           ## k++
  j rule_2_Kfor           ## go do the K loop again


rule_2_done_k_loop: 

  beq $s6, $t1, rule_2if2         ## if (ALL_VALUES != j_sum
                  ##board[i][j] = ALL_VALUES & ~j_sum;
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s1
  sub $sp, $sp, 8
  sw  $t0, 36($sp)
  sw  $t1, 40($sp)
  jal board_address
  lw  $t0, 36($sp)
  lw  $t1, 40($sp)
  add $sp, $sp, 8
  not $t1, $t1
  and   $t1, $t1, $s6
  lw  $t1, 0($v0)
  
  
  li  $s4, 1              ##changed = true;
  j rule_2_Jfor_increment         ## continue

rule_2_if2:

  beq $s5, $t0, rule_2_over_if        ## else if (ALL_VALUES != i_sum)
                  ##board[i][j] = ALL_VALUES & ~i_sum 
  move  $a0, $s5
  move  $a1, $s0
  move  $a2, $s1
  sub   $sp, $sp, 4
  sw  $t0, 36($sp)
  jal board_address
  lw  $t0, 36($sp)
  add $sp, $sp, 4
  not $t0, $t0
  and $t0, $t0, $s6
  lw  $t0, 0($v0) 
  

  li  $s4, 1              ##changed = true;
  j rule_2_Jfor_increment         ## continue

rule_2_over_if:

  move  $a0, $s0            ## int ii = get_square_begin(i)
  jal   get_square_begin
  move  $s2, $v0
  move  $t0, $v0            ##ii

  move  $a0, $s1            ## int jj = get_square_begin(j)
  jal get_square_begin
  move  $s3, $v0
  move  $t1, $v0            ## jj

  li  $t3, 0              ## sum = 0

rule_2_iiLoop:
  add $t3, $t0, 3
  bge $s2, $t3, rule_2_iiLoop_done        ## for (int k = ii ; k < ii + GRIDSIZE ; ++ k) 
rule_2_jjLoop:
  
  add $t4, $t1, 3
  bge $s3, $t4, rule_2_incrementii        ## for (int l = jj ; l < jj + GRIDSIZE ; ++ l)

  bne $s2, $s0, over_jjif         ## if ((k == i) && (l == j))  
  bne $s3, $s1, over_jjif
  j rule_2_Jfor_increment         ## continue

over_jjif:
  mul $t6, $s2, 9   # i*9       ## sum |= board[k][l]
  add $t6, $t6, $s3   # (i*9)+j
  sll $t6, $t6, 2   # ((i*9)+j)*4
  add $t6, $a0, $s5

  lw  $t7, 0($t6)
  or  $t3, $t7            ## sum |= board[k][l];                  

rule_2_incrementjj:
  add $s3,$s3,1           ## l++
  j rule_2_jjLoop           ## do the inner part of the loop again

rule_2_incrementii:
  add $s2, $s2, 1           ## k++
  li  $s3, 0              ## l = 0
  j rule_2_iiLoop           ## do the loop again

rule_2_iiLoop_done:
  beq $s6,$t3, rule_2_Jfor_increment        ## if (ALL_VALUES != sum)
  move  $a0, $s5            ## board[i][j] = ALL_VALUES & ~sum;
  move  $a1, $s0
  move  $a2, $s1
  sub $sp, $sp, 4
  sw  $t3, 36($sp)
  jal board_address
  lw  $t3, 36($sp)
  add $sp, $sp,4
  not $t3, $t3
  lw  $t0, 0($v0)
  and $t0, $t0, $t3
  lw  $t0, 0($v0)

rule_2_Jfor_increment:
  
  add $s1, $s1, 1           ## j++
  j rule_2_Jfor           ## to back to inner for loop

rule_2_Ifor_increment:

  add $s0, $s0, 1           ##i++
  li  $s1, 0              ##j = 0
  j rule_2_Ifor           ## go back to the for loop


rule_2_done:
  lw  $ra, 0($sp)           ##restore the s registers and the stack pointer and return
  lw  $s0, 4($sp)
  lw  $s1, 8($sp)
  lw  $s2, 12($sp)
  lw  $s3, 16($sp)
  lw  $s4, 20($sp)
  lw  $s5, 24($sp)
  lw  $s6, 28($sp)
  lw  $s7, 32($sp)
  
  add   $sp,$sp,36
  move  $v0, $s4            ## return changed
  jr  $ra
  




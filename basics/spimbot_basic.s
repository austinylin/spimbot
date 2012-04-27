######################################################################
##    Write your solution for problem 3 from MP#4 in this file      ##
######################################################################
  .data
    kickflag: .word 0
    main_loop_text: .asciiz "Main Loop Dealing with Ball:"
    re_loop_text: .asciiz "Storing Ball for Reloop:"
    
    new_line: .asciiz "\n"
  .text
main: 

  li    $t4, 0x1001 # flag for bonk interrupt set, and global interrupt enable
  or    $t4, $t4, 0x2000 # enable kick oppertunity (kickable) interrupt
  mtc0  $t4, $12  # Enable interrupt mask (Status register)
  
  sub   $sp, $sp, 12   # $sp = $sp - 12
  sw    $ra, 0($sp)
  sw    $s0, 4($sp)
  sw    $s1, 8($sp)
  
    
  li    $s0, 2    #number of balls
  li    $s1, 99   # placeholder
  
  main_loop:
    sw    $zero, kickflag
    
    sw    $s0, 0xffff00d0($zero)  #ball select
  
    lw    $t0, 0xffff00e0($zero)  #did we already handle this ball, by accident perhaps (i.e. we ran into it while trying to kick another ball)
    beq   $t0, $zero, main_inc_and_loop
    
    lw    $t0, 0xffff0020($zero)
  
    lw    $t1, 0xffff0024($zero)
  
    lw    $t2, 0xffff00d4($zero)  #get ball x position

    lw    $t3, 0xffff00d8($zero)  #get ball y position
  
    sub   $a0, $t2, $t0   # $a0 = $s0 - $s2
    sub   $a1, $t3, $t1   # $a1 = $s1 - $s3
  
    jal   arctan        # jump to artan and save position to $ra
    
    sw    $v0, 0xffff0014($zero)    # set angle
    li    $t0, 1
    sw    $t0, 0xffff0018($zero)  # send the turn command
  
    #calculate kick angle

    li    $t0, 300
    li    $t1, 150
  
    lw    $t2, 0xffff00d4($zero)  #get ball x position

    lw    $t3, 0xffff00d8($zero)  #get ball y position

    sub   $a0, $t0, $t2   # $a0 = $t0 - $t2
    sub   $a1, $t1, $t3   # $a1 = $t1 - $t3
  
    jal   arctan        # jump to arctan and save position to $ra
    sw    $v0, 0xffff00c4($zero) #kick oreintation/angle

    li    $t0, 10
    sw    $t0, 0xffff0010($zero)    # drive
    
    main_wait_loop:
      lw    $t0, kickflag
      beq   $t0, 1, main_kick_ball
      beq   $t0, 2, main_kick_other_ball
      j     main_wait_loop
      
    main_inc_and_loop:
      sw    $zero, kickflag   #reset kickflag
      beq   $s0, $zero, main_done    
      sub   $s0, $s0, 1   # number of balls left - 1
      j     main_loop

  main_done:
    bne   $s1, 99, main_s1_reloop  # if $s1 is not our placeholder value 99 then we had to skip a ball earlier, lets go back and take care of it
    lw    $ra, 0($sp)
    lw    $s0, 4($sp)
    lw    $s1, 8($sp)
    add   $sp, $sp, 12
  
  main_inf:
    j main_inf
    
  main_s1_reloop:      
    move  $s0, $s1
    j     main_loop        # jump to main_loop
    
  main_kick_ball:
    li    $t0, 1    
    sw    $t0, 0xffff0010($zero)    # slow down    
    li    $t0, 100
    sw    $t0, 0xffff00c8($zero)    #kick ball
    sw    $zero, 0xffff0010($zero)    # stop
    beq   $s0, $s1, clear_s1_reloop  # if $s0 == $s1 then clear_s1_reloop
    j     main_inc_and_loop        # jump to main_inc_and_loop
    
  main_kick_other_ball:
    sw    $zero, 0xffff0010($zero)    # stop
  
    beq   $s0, $zero, main_loop #if we are on the last ball and something weird happens, try re calcuating the angles
    move  $s1, $s0
    sub   $s0, $s0, 1   # $s0 = $s0 - 1
    j     main_loop
    
  clear_s1_reloop:
    li    $s1, 99
    j     main_inc_and_loop        # jump to main_inc_and_loop
    

#### Code to compute angle ####

.data
three:  .float 3.0
five:   .float 5.0
PI: .float 3.14159
F180:   .float 180.0

.text

# use a Taylor series approximation to compute arctan(x,y)

arctan:                      # a0 = delta_x, a1 = delta_y
                             # t0 = abs(a0), t1 = abs(a1)
  abs   $t0, $a0       # t0 = |delta_x|
  abs   $t1, $a1       # t1 = |delta_y|
  li    $v0, 0         # v0 = angle
  ble   $t1, $t0, no_TURN_90

                             # if (abs(y) > abs(x)) { rotate 90 degrees }
  move  $v0, $a1       # temp = y
  sub   $a1, $0, $a0   # y = -x
  move  $a0, $v0       # x = temp
  li    $v0, 90        # angle = 90.0

no_TURN_90:
  bge   $a0, $0, pos_x       # skip if (x >= 0.0)
  addi  $v0, $v0, 180

pos_x:  mtc1  $a0, $f0
  mtc1  $a1, $f1
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

  jr    $ra

  .data     # interrupt handler data (separated just for readability)
  save0:       .word 0
  save1:       .word 0
  v0:       .word 0
  
  non_intrpt_str:   .asciiz "Non-interrupt exception\n"
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

    and   $a0, $k0, 0x1000  # is there a bonk interrupt?
    bne   $a0, 0, bonk_interrupt  

    and   $a0, $k0, 0x2000  # is there a bonk interrupt?
    bne   $a0, 0, kickable_interrupt
    
            # add dispatch for other interrupt types here.

    li $v0, 4     # Unhandled interrupt types
    la $a0, unhandled_str
    syscall
    b done

  bonk_interrupt:
    li    $a0, 2
    sw    $a0, kickflag
    sw  $a1, 0xffff0060($zero)    # acknowledge interrupt

    b   interrupt_dispatch    # see if other interrupts are waiting

  kickable_interrupt:
    #make sure ball is kickable, set kick flag, be done
    sw    $zero, kickflag
    lw    $a0, 0xffff00e4($zero)
    beq   $a0, $zero, kickable_interrupt_cant_kick  # if $a0 == $zero then cant_kick
      li    $a0, 1
      sw    $a0, kickflag 
      j kickable_interrupt_done
      
    kickable_interrupt_cant_kick:
      li    $a0, 2
      sw    $a0, kickflag
     
    kickable_interrupt_done:
      sw    $a0, 0xffff0064($zero)    # acknowledge interrupt
      b     interrupt_dispatch    # see if other interrupts are waiting
       
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
.data
  print_int: 0xffff0080
  
.text

main:
    sw $zero, print_int(0)
  
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

  and   $a0, $k0, 0x2000  # is there a kickable interrupt?
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


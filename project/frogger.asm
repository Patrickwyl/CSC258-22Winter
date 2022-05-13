#####################################################################
#
# CSC258H5S Winter 2022 Assembly Final Project
# University of Toronto, St. George
#
# Student: Yulin Wang, 1003942326
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
# - Display has 32 x 32 pixels coordinate system
# - 4*32 = 128 bytes per pixel line 
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 5
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Add sound effects for movement, losing lives, collisions, and reaching the goal. (Easy)
# 2. Have objects in different rows move at different speeds. (Easy)
# 3. Display the number of lives remaining. (Easy)
# 4. Display a death/respawn animation each time the player loses a frog. (Easy)
# 5. Display the player's score at the top right side of the screen. (Hard)
#
# Any additional information that the TA needs to know:
# Thank you for being a nice TA through this semester!
# - use adsw to control the frog move
# - use r to restart the game
# - use esc to exit the game
#####################################################################
# variables
.data
	displayAddress: .word 0x10008000
	str_end_game: .asciiz  "!!! Game Over!!!"
	
	
	# Use coordinate system in pixel units; 32 * 32 Display
	# frog location
    	frog_x_start: .word 12		# forog's initial location x coordinate in pixel
    	frog_y_start: .word 28		# forog's initial location y coordinate in pixel
    	frog_x: .word 12		# store forog's current location x coordinate
    	frog_y: .word 28		# store forog's current location y coordinate
    	
    	# colour variables
    	yellow: .word 0xffff00		# vehicles
    	green: .word 0x00ff00		# goal; start
    	lightblue: .word 0xADD8E6	# water
    	black: .word 0x000000		# road
    	brown: .word 0x946B00		# logs
    	grey: .word 0x808080		# safe
    	pink: .word 0xFF00FF		# frog
    	
    	# create space in memeory to store each row of vehicles and road
    	vehicles_row_1: .space 512	# 4 pixel lines
	vehicles_row_2: .space 512	# 4 pixel lines
    	
    	# create space in memeory to store each row of logs and water
    	logs_row_1: .space 512		# 4 pixel lines
	logs_row_2: .space 512		# 4 pixel lines
	
    	# number of lives
    	num_lives: .word 3		# initialize the number of lives remaining
    	
    	# score
    	score: .word 0			# initialize the times of winning the game to 0
    	
    	# signal of collision
    	collision_signal: .word 0	# 1 means there is a collision
    	
    	# set different speeds for different vehicle/log rows
    	v_vehicle_1: .word 1		# 1 left pixel move per update
    	v_vehicle_2: .word 2		# 2 right pixel moves per update
    	v_log_1: .word 1		# 2 left pixel moves per update
    	v_log_2: .word 2		# 2 right pixel moves per update
    	
    	# array of the offset values of the filled goal region
    	filled_goal_offsets: .word 0:8
    	
# instructions    
.text
start_game:
	# sound effect for starting the game
	li $v0, 31
	addi $a0, $zero, 58	# pitch
	addi $a1, $zero, 2000	# durarion 2 seconds
	addi $a2, $zero, 125	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	lw $s0, displayAddress	# $s0 stores the base address for display
	
######################### Fill callocate memory for vehicle and log rows #########################
allocate_spaces:
# fill the memory for the first vehicle row		
	lw $a1, yellow		# $a1 stores the yellow colour code for vehicles
	lw $a2, black		# $a2 stores the black colour code for road
	la $t1, vehicles_row_1
	add $a0, $zero, $t1
	jal fill_allocated_row
	
	# fill the memory for the second vehicle row		
	lw $a1, black		# $a1 stores the black colour code for road 
	lw $a2, yellow		# $a2 stores the yellow colour code for vehicles
	la $t1, vehicles_row_2
	add $a0, $zero, $t1
	jal fill_allocated_row

	# fill the memory for the first log row
	lw $a1, lightblue	# $a1 stores the lightblue colour code for water
	lw $a2, brown		# $a2 stores the brown colour code for logs
	la $t1, logs_row_1
	add $a0, $zero, $t1
	jal fill_allocated_row
	
	# fill the memory for the second log row
	lw $a1, brown		# $a1 stores the brown colour code for logs
	lw $a2, lightblue	# $a2 stores the lightblue colour code for water
	la $t1, logs_row_2
	add $a0, $zero, $t1
	jal fill_allocated_row
######################### Fill callocate memory for vehicle and log rows #########################
	

# central processing loop
refresh: 
	# check keyboard input and update the location of the frog accordingly
	lw $t8, 0xffff0000 		# check the contents of the memory location
	beq $t8, 1, keyboard_input 	# if key is pressed, jump to get this key
	
	jal check_collision		# check for collision events 
	
	jal check_goal			# check if it reaches the goal region
	
	jal update_logs_vehicles	# update the location of logs and vehicles
	
	jal draw_background		# redraw the screen
	
	jal draw_frog			# redraw the frog
	
	# sleep
	li $v0, 32
	li $a0, 300			# sleep for 0.3 seconds
	syscall	
	
	# if all lives are lost, end the game
	lw $t1, num_lives
	bne $t1, 0, continue_game

end_game:	
	# print "!!! Game Over!!!"
	la $a0, str_end_game
	li $v0, 4
	syscall
	j Exit

continue_game:	
	j refresh			# go back to check for keyboard input
	
	
######################### Fetching keyboard Input #########################	
# Respond to kryborad inputs - update the location of the frog accordingly
keyboard_input: 
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
		
	lw $t1, 0xffff0004 		# load the ASCII value of the key in the next integer in memory

       	beq $t1, 0x61, respond_to_A 	# check to see if "a" was just pressed
       	beq $t1, 0x64, respond_to_D 	# check to see if "d" was just pressed
       	beq $t1, 0x77, respond_to_W 	# check to see if "w" was just pressed
       	beq $t1, 0x73, respond_to_S 	# check to see if "s" was just pressed
       	beq $t1, 0x1B, respond_to_ESC   # check to see if "esc" was just pressed
	beq $t1, 0x72, respond_to_R	# check to see if "r" was just pressed
       		
       	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
            
respond_to_A: 
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 1000	# durarion 1 second
	addi $a2, $zero, 115	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
        
        lw $t1, frog_x		# load frog_x
	addi $t1, $t1, -4	# move left by 4 pixels
	sw $t1, frog_x		# store new frog_x
        
        jal draw_frog
        
        # pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
        
        jr $ra   
        
respond_to_D: 
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 1000	# durarion 1 second
	addi $a2, $zero, 115	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
        
        lw $t1, frog_x		# load frog_x
	addi $t1, $t1, 4	# move right by 4 pixels
	sw $t1, frog_x		# store new frog_x
	
	jal draw_frog
        
        # pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
        
        jr $ra  
        
respond_to_W: 
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 1000	# durarion 1 second
	addi $a2, $zero, 115	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
        
        lw $t1, frog_y		# load frog_y
	addi $t1, $t1, -4	# move upward by 4 pixels
	sw $t1, frog_y		# store new frog_y
	
	jal draw_frog
        
        # pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
        
        jr $ra  
        
respond_to_S: 
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 1000	# durarion 1 second
	addi $a2, $zero, 115	# instrument
	addi $a3, $zero, 66	# volume
	syscall	
	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
        
        lw $t1, frog_y		# load frog_y
	addi $t1, $t1, 4	# move downward by 4 pixels
	sw $t1, frog_y		# store new frog_y
	
        jal draw_frog
        
        # pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
        
        jr $ra  

respond_to_ESC: 
	j Exit 			# terminate the game
	
respond_to_R:
	jal reset_frog		# reset the frog location
	jal reset_lives		# reset the number of lives to 3
	jal reset_score		# reset the game score to 0
	j start_game		# restart the game
######################### Fetching keyboard Input #########################


######################### Draw the background #########################
draw_background:

	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
# Goal section - green
draw_goal: 
	lw $t1, green 		# $t1 stores the green colour code for goal region
	addi $a0, $zero, 8	# set height = 8 pixels
	addi $a1, $zero, 32	# set width = 32 pixels
	add $a2, $zero, $t1     # set rectangle's colour to green
	add $a3, $zero, $s0     # set address of top left corner
	jal draw_rectangle      # call function draw_rectangle
       
# Safe section - grey
draw_safe: 
	lw $t1, grey		# $t1 stores the grey colour code for safe region
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 32	# set width = 32 pixels
	add $a2, $zero, $t1     # set rectangle's colour to grey
	add $a3, $s0, 2048      # set address of top left corner; byte offset = 2048
	jal draw_rectangle      # call function draw_rectangle  

# Start section - green
draw_start: 
	lw $t1, green 		# $t1 stores the green colour code for starting region
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 32	# set width = 32 pixels
	add $a2, $zero, $t1     # set rectangle's colour to green
	add $a3, $s0, 3584      # set address of top left corner; byte offset = 3584
	jal draw_rectangle      # call function draw_rectangle
	
# Draw road-black and vehicles-yellow
draw_raod_vehicles:	
	# draw the first vehicle row from allocated memory
	li $a0, 3072		# byte offset from base adrress for display to top left corner
	la  $a1, vehicles_row_1
	jal draw_allocated_row
	
	# draw the second vehicle row from allocated memory
	li $a0, 2560		# byte offset from base adrress for display to top left corner
	la  $a1, vehicles_row_2
	jal draw_allocated_row
	    
# Draw water-lightblue and logs-brown
draw_water_logs:
	# draw the first log row from allocated memory
	li $a0, 1536		# byte offset from base adrress for display to top left corner
	la  $a1, logs_row_1
	jal draw_allocated_row
	
	# draw the second log row from allocated memory
	li $a0, 1024		# byte offset from base adrress for display to top left corner
	la  $a1, logs_row_2
	jal draw_allocated_row
	
# mark the reached goal region as filled with pink
draw_filled_goal:
	lw $t0, displayAddress	# $t0 stores the address for display
	lw $t1, pink		# $t1 stores the pink colour
	
	add $t4, $zero, $zero
	lw $t5, filled_goal_offsets($t4)	# load offset value
	add $t0, $t0, $t5	# add offset
	
	beq $t5, 0, end_draw_background
	
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 4	# set width = 4 pixels
	add $a2, $zero, $t1     # set square's colour to pink
	add $a3, $zero, $t0      # set address of top left corner;
	jal draw_rectangle      # call function draw_rectangle

end_draw_background:		
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra			
######################### Draw the background #########################


######################### Draw the frog #########################	
# Draw the frog - pink
draw_frog:  

	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress	# $t0 stores the address for display
        lw $t1, pink		# $t1 stores the pink colour code for frog      
        
        lw $t2, frog_x		# $t2 stores frog_x
	lw $t3, frog_y		# $t3 stores frog_y
	add $a0, $zero, $t2	# x_coordinate = frog_x
	add $a1, $zero, $t3	# y_coordinate =  frog_y
	jal calculate_offset	# calculate byte offset from top left
	
	add $t0, $t0, $v0	# add offset; $t0 stores the position offset of frog 
        
	sw $t1, 0($t0)
	
	addi $t0, $t0, 12
	sw $t1, 0($t0)
	
	addi $t0, $t0, 116
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 120
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 120
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	addi $t0, $t0, 4
	sw $t1, 0($t0)
	
	jal display_lives		# update display of number of lives remaining
	
	jal display_score		# update the current player's score

end_draw_frog:

	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4

	jr $ra
######################### Draw the frog #########################


######################### Update location of the logs and vehicles #########################
update_logs_vehicles:

	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Have objects in different rows move at different speeds.

	# load speeds
	lw $s1, v_vehicle_1
    	lw $s3, v_vehicle_2
    	lw $s5, v_log_1
    	lw $s7, v_log_2
	
# move the first vehicle row
add $s4, $zero, $zero			# set index value $s4 to 0
move_vehicles_row_1:
	beq $s4, $s1, end_move_vehicles_row_1
	
	la $t1, vehicles_row_1
	add $a0, $zero, $t1
	jal move_to_left
	
	addi $s4, $s4, 1		# Increment $s4 by 1
	j move_vehicles_row_1
	
end_move_vehicles_row_1:	
	
# move the second vehicle row
add $s4, $zero, $zero			# set index value $s4 to 0
move_vehicles_row_2:
	beq $s4, $s3, end_move_vehicles_row_2
	
	la $t1, vehicles_row_2
	add $a0, $zero, $t1
	jal move_to_right
	
	addi $s4, $s4, 1		# Increment $s4 by 1
	j move_vehicles_row_2
	
end_move_vehicles_row_2:

# move the first log row	
add $s4, $zero, $zero			# set index value $s4 to 0
move_logs_row_1:
	beq $s4, $s5, end_move_logs_row_1	
	
	la $t1, logs_row_1
	add $a0, $zero, $t1
	jal move_to_left

	addi $s4, $s4, 1		# Increment $s4 by 1	
	j move_logs_row_1
	
end_move_logs_row_1:

# move the first log row
add $s4, $zero, $zero			# set index value $s4 to 0
move_logs_row_2:	
	beq $s4, $s7, end_move_logs_row_2
	
	la $t1, logs_row_2
	add $a0, $zero, $t1
	jal move_to_right
	
	addi $s4, $s4, 1		# Increment $s4 by 1	
	j move_logs_row_2
	
end_move_logs_row_2:

	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra 
######################### Update location of the logs and vehicles #########################	


######################### Display the number of lives remaining #########################
display_lives:
	lw $t0, displayAddress			# $t0 stores the address for display
	li $t1, 0xff0000			# $t1 stores the red colour code
	lw $t2, num_lives 			# $t2 stores the remaining nuber of lives

	add $t3, $zero, $zero			# set index value $t3 to 0
	
	beq $t2, $t3, end_draw_lives 		# if lost all lives, do not draw

draw_lives_loop:

	beq $t3, $t2, end_draw_lives
	
	sw $t1, 0($t0) 				# paint the pixel as red

	addi, $t3, $t3, 1			# increament $t3 by 1
	addi $t0, $t0, 8			# increament $t0 by 8; skip one pixel
	
	j draw_lives_loop

end_draw_lives:
	jr $ra
######################### Display the number of lives remaining #########################


######################### Display the score for current player #########################
display_score:
	lw $t0, displayAddress			# $t0 stores the address for display
	addi $t0, $t0, 124			# start from the top right right of the screen
	lw $t1, pink				# $t1 stores the pink colour code
	lw $t2, score 				# $t2 stores the current score

	add $t3, $zero, $zero			# set index value $t3 to 0

draw_score_loop:

	beq $t3, $t2, end_draw_score 
	
	sw $t1, 0($t0) 				# paint the pixel as pink

	addi, $t3, $t3, 1			# increament $t3 by 1
	addi $t0, $t0, -8			# decrease $t0 by 8; skip one pixel
	
	j draw_score_loop

end_draw_score:
	jr $ra
######################### Display the score for current player #########################


# reset frog location
reset_frog:
	lw $t1, frog_x_start
	lw $t2, frog_y_start
	sw $t1, frog_x
	sw $t2, frog_y
	jr $ra

# reset number of lives
reset_lives:
	addi $t1, $zero, 3
	sw $t1, num_lives
	jr $ra

# reset score of the game to 0
reset_score:
	addi $t1, $zero, 0
	sw $t0, score
	jr $ra	

######################### Function to draw a rectangle #########################
# input arguments: 
# $a0: height in pixels; 
# $a1: width in pixels;  
# $a2: colour
# $a3: address of top left corner of the rectangle
draw_rectangle:
	add $t1, $zero, $zero	# Set index value ($t1) to zero
# loop to draw each pixel line
draw_rect_loop:
	beq $t1, $a0, end_rect  # If $t1 == height ($a0), jump to end

	add $t2, $zero, $zero	# Set index value ($t2) to zero
# loop to draw a line:
draw_line_loop:
	beq $t2, $a1, end_draw_line  # If $t2 == width ($a1), jump to end
	sw $a2, 0($a3)		# Draw a pixel at memory location $t0 with colour $a2
	addi $a3, $a3, 4	# Increment $a3 by 4
	addi $t2, $t2, 1	# Increment $t2 by 1
	j draw_line_loop	# Jump to start of line drawing loop
end_draw_line:

# calculate the offset to the first pixel of the next line
	add $t3, $zero, 32      # $t3 = 32
	sub $t4, $t3, $a1       # pixels from rectangle's right side to the next line
	sll $t4, $t4, 2		# multiply $t4 by 4; bytes offest: 4 * pixel offset

	add $a3, $a3, $t4	# Set $a3 to the first pixel of the next line.
			
	addi $t1, $t1, 1	# Increment $t1 by 1
	j draw_rect_loop	# Jump to start of rectangle drawing loop
	
end_rect:

	jr $ra			# jump back to the calling program
######################### Function to draw a rectangle #########################


######################### Function to calculate byte offset values from top left #########################
# offset in bytes = 4x + 128y
# input arguments:
# $a0: x coordinate in pixels
# $a1: y corrdinate in pixels
# return output:
# $v0: byte offset values from top left
calculate_offset:
	sll $a0, $a0, 2		# multiply x coordinate by 4
	sll $a1, $a1, 7		# multiply x coordinate by 128
	add $v0, $a0, $a1       # add x offset and y offset to $v0

	jr $ra		        # jump back to the calling program
######################### Function to calculate byte offset values from top left #########################

         
######################### Function to fill allocated row #########################
# input arguments:
# $a0: address of the allocated memory
# $a1: colour code for the object/background 
# $a2: colour code for the object/background 
fill_allocated_row:
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	add $s1, $a0, $zero	# $s1 stores the address of the allocated memory
	add $s2, $a1, $zero	# $s2 stores colour for the object/background 
	add $s3, $a2, $zero	# $s3 stores colour for the object/background 

	# fill the memory for the first 4*8 rectangle with first colour
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 8	# set width = 8 pixels
	add $a2, $zero, $s2     # set rectangle's colour
	add $a3, $s1, $zero     # set address of top left corner
	jal draw_rectangle      # call function draw_rectangle  
	
	# fill the memory for the second 4*8 rectangle with second colour
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 8	# set width = 8 pixels
	add $a2, $zero, $s3     # set rectangle's colour
	add $a3, $s1, 32        # set address of top left corner
	jal draw_rectangle      # call function draw_rectangle 
	
	# fill the memory for the third 4*8 rectangle with first colour
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 8	# set width = 8 pixels
	add $a2, $zero, $s2     # set rectangle's colour
	add $a3, $s1, 64	# set address of top left corner
	jal draw_rectangle      # call function draw_rectangle   
	       
	# fill the memory for the fourth 4*8 rectangle with second colour
	addi $a0, $zero, 4	# set height = 4 pixels
	addi $a1, $zero, 8	# set width = 8 pixels
	add $a2, $zero, $s3     # set rectangle's colour
	add $a3, $s1, 96        # set address of top left corner
	jal draw_rectangle      # call function draw_rectangle 
	
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra
######################### Function to fill allocated row #########################


#########################  Function to draw rectangle from allocated space ######################### 
# input arguments: 
# $a0: byte offset from base adrress for display
# $a1: starting address of allocated space
draw_allocated_row:
	lw $t0, displayAddress		# $t0 stores the base address for display	
	add $t1, $t0, $a0		# $t1 stores starting adress of drawing
	add $t2, $zero, $zero		# set index value $t2 to 0
	addi $t3, $zero, 512		# loop through 4 pixel lines
		
draw_allocated_loop: 
	beq $t2, $t3, end_draw_allocated
	lw $t4, 0($a1)			# load colour from memory location $a1
	sw $t4, 0($t1) 			# draw a pixel at memory location $t1 with corresponding colour $t4
	addi $a1, $a1, 4		# Increment $a1 by 4 bytes  
	addi $t2, $t2, 4		# Increment $t2 by 4 bytes
	add $t1, $t1, 4			# Increment $t1 by 4 bytes
	j draw_allocated_loop	
	
end_draw_allocated:
	jr $ra
#########################  Function to draw rectangle from allocated space ######################### 


#########################  Function to move allocated memory to right by one pixel ######################### 
# input arguments:
# $a0: address of the allocated memroy space
move_to_right:
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	add $s2, $a0, $zero
	
	# move the first pixel line 
	add $t1, $s2, $zero
	add $a0, $zero, $t1
	jal move_line_right
	
	# move the second pixel line 
	addi $t1, $s2, 128
	add $a0, $zero, $t1
	jal move_line_right
	
	# move the third pixel line 
	addi $t1, $s2, 256
	add $a0, $zero, $t1
	jal move_line_right
	
	# move the second pixel line 
	addi $t1, $s2, 384
	add $a0, $zero, $t1
	jal move_line_right
	
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra	
#########################  Function to move allocated memory to right by one pixel ######################### 


#########################  Function to move allocated memory to left by one pixel ######################### 
# input arguments:
# $a0: address of the allocated memroy space
move_to_left:
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	add $s2, $a0, $zero
	
	# move the first pixel line 
	add $t1, $s2, $zero
	add $a0, $zero, $t1
	jal move_line_left
	
	# move the second pixel line 
	addi $t1, $s2, 128
	add $a0, $zero, $t1
	jal move_line_left
	
	# move the third pixel line 
	addi $t1, $s2, 256
	add $a0, $zero, $t1
	jal move_line_left
	
	# move the second pixel line 
	addi $t1, $s2, 384
	add $a0, $zero, $t1
	jal move_line_left
	
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra	
#########################  Function to move allocated memory to left by one pixel ######################### 


#########################  Function to move one pixel line to right by one pixel ######################### 
# input arguments:
# $a0: address of the first pixel of the line
move_line_right: 
	lw $t1, 124($a0)		# $t1 stores colour at the last pixel 
	
	addi $t2, $zero, 0		# set index value $t2 to 0
	addi $t4, $zero, 128		# loop through 32 pixels
	
line_right_loop:   	  
	beq $t2, $t4, end_move_line_right

	lw $t3, 0($a0)			# $t3 stores colour at $a0	
	sw $t1, 0($a0)			# draw a pixel at memory $a0 with colour $t1
	add $t1, $t3, $zero             # $t1 store the same colour as $t3
	
	addi $t2, $t2, 4                # increment $t2 by 4 bytes
	addi $a0, $a0, 4		# increment $a0 by 4 bytes
	j line_right_loop	
	
end_move_line_right:	
	jr $ra
#########################  Function to move one pixel line to right by one pixel ######################### 


#########################  Function to move one pixel line to left by one pixel ######################### 
# input arguments:
# $a0: address of the first pixel of the line
move_line_left: 
	lw $t1, 0($a0)			# $t1 stores colour at the first pixel 
	
	addi $a0, $a0, 124              # loop start from the last pixel
	addi $t2, $zero, 124		# set index value $t2 to 124
	addi $t4, $zero, 0		# loop through 32 pixels	
	
line_left_loop:   	  
	beq $t2, $t4, end_move_line_left

	lw $t3, 0($a0)			# $t3 stores colour at $a0	
	sw $t1, 0($a0)			# draw a pixel at memory $a0 with colour $t1
	add $t1, $t3, $zero             # $t1 store the same colour as $t3
	
	addi $t2, $t2, -4               # decrease $t2 by 4 bytes
	addi $a0, $a0, -4		# decrease $a0 by 4 bytes
	j line_left_loop	
	
end_move_line_left:	
 	sw $t1, 0($a0)			# store colour $t1 at the first pixel
	jr $ra
#########################  Function to move one pixel line to left by one pixel ######################### 


#########################  Function to check collision ######################### 
check_collision:
	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# load current location of the frog in pixel
	lw $s1, frog_x
	lw $s2, frog_y
	
	# when the frog is in the road area - check collision with car
	addi, $t1, $zero, 24			# $t1 stores y-coordinate of the first vehicle row
	addi, $t2, $zero, 20			# $t2 stores y-coordinate of the second vehicle row	
	beq $s2, $t1, check_first_vehicle_row	# if $s2 == 24, check the first vehicle row
	beq $s2, $t2, check_second_vehicle_row	# if $s2 == 20, check the second vehicle row
	
	# when the frog is in the water area - check collision with water
	addi, $t5, $zero, 12			# $t1 stores y-coordinate of the first log row
	addi, $t6, $zero, 8			# $t2 stores y-coordinate of the second log row	
	beq $s2, $t5, check_first_log_row	# if $s2 == 24, check the first log row
	beq $s2, $t6, check_second_log_row	# if $s2 == 20, check the second log row
	
	j no_collision

check_first_vehicle_row:
	la $t1, vehicles_row_1			# load the first vehicle row
	sll $t2, $s1, 2				# $t2 = $s1 * 4
	add $t1, $t1, $t2			# calculate the offset from the first pixel of the first vehicle row 
	lw $t3, 0($t1)				# $t3 stores the colour at the top left frog location of the row
	add $a0, $t3, $zero
	jal collision_detection

	j end_check_collision

check_second_vehicle_row:
	la $t1, vehicles_row_2			# load the second vehicle row
	sll $t2, $s1, 2				# calculate the offset from the first pixel of the second vehicle row 
	add $t1, $t1, $t2			
	lw $t3, 0($t1)				# $t3 stores the colour at the top left frog location of the row
	add $a0, $t3, $zero
	jal collision_detection
	
	j end_check_collision
	
check_first_log_row:
	la $t1, logs_row_1			# load the first log row
	sll $t2, $s1, 2				# calculate the offset from the first pixel of the first log row 
	add $t1, $t1, $t2			
	lw $t3, 0($t1)				# $t3 stores the colour at the top left frog location of the row
	add $a0, $t3, $zero
	jal collision_detection

	j end_check_collision

check_second_log_row:
	la $t1, logs_row_2			# load the second log row
	sll $t2, $s1, 2				# calculate the offset from the first pixel of the second log row 
	add $t1, $t1, $t2			
	lw $t3, 0($t1)				# $t3 stores the colour at the top left frog location of the row
	add $a0, $t3, $zero
	jal collision_detection
	
	j end_check_collision
	
end_check_collision:
	lw $t1, collision_signal
	addi $t2, $zero, 1
	bne $t1, $t2, no_collision

collision:
	# loose one life
	lw $t3, num_lives
	addi, $t3, $t3, -1
	sw $t3, num_lives
	
	jal death_animation
	
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 2000	# durarion 2 seconds
	addi $a2, $zero, 26	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	add $t4, $zero, $zero
	sw $t4, collision_signal	# set collision_signal back to 0
	
	jal reset_frog

no_collision:
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra

# when the frog is in the water area - check collision with water
# first vehicle row 
#########################  Function to check collision ######################### 


#########################  Function to detect collision for one pixel ######################### 
# input arguments:
# $a0: the colour of the detecting pixel

collision_detection:
	lw $t1, yellow			# colour of vehicles
	lw $t2, lightblue		# colour of water
	
	beq $a0, $t1, collision_happen
	bne $a0, $t2, collision_end
	
collision_happen:
	addi $t3, $zero, 1
	sw $t3, collision_signal	# set collision_signal to 1
	
collision_end:	
	jr    $ra
#########################  Function to detect collision for one pixel ######################### 


#########################  Function to display death animation ######################### 
death_animation:	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	lw $t0, displayAddress	# $t0 stores the address for display
        lw $t1, pink		# $t1 stores the pink colour code for frog      
        
        lw $t2, frog_x		# $t2 stores frog_x
	lw $t3, frog_y		# $t3 stores frog_y
	add $a0, $zero, $t2	# x_coordinate = frog_x
	add $a1, $zero, $t3	# y_coordinate =  frog_y
	jal calculate_offset	# calculate byte offset from top left
	
	add $t0, $t0, $v0	# add offset; $t0 stores the position offset of frog 
		
	sw $t1, 0($t0)
	sw $t1, 12($t0)
	sw $t1, 132($t0)
	sw $t1, 136($t0)
	sw $t1, 260($t0)
	sw $t1, 264($t0)
	sw $t1, 384($t0)
	sw $t1, 396($t0)
	
	# sleep 1.5 seconds
	li $v0, 32
	li $a0, 1500
	syscall	
	
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra	
#########################  Function to display death animation ######################### 


######################### If the frog reaches an empty goal region, mark that region as filled ######################### 
check_goal:	
	# move stack pointer a word and push ra onto the stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
        lw $t2, frog_x		# $t2 stores frog_x
	lw $t3, frog_y		# $t3 stores frog_y
	
	addi $t4, $zero, 4	
	bne $t3, $t4, not_reach_goal # check if the frog reaches the goal area
	
reach_goal:	
	add $a0, $zero, $t2	# x_coordinate = frog_x
	add $a1, $zero, $t3	# y_coordinate =  frog_y
	jal calculate_offset	# calculate byte offset from top left
	
	add $t2, $zero, $zero
	sw $v0, filled_goal_offsets($t2)	# store offset to array
	
	# sound effect
	li $v0, 31
	addi $a0, $zero, 66	# pitch
	addi $a1, $zero, 1000	# durarion 1 second
	addi $a2, $zero, 127	# instrument
	addi $a3, $zero, 66	# volume
	syscall
	
	jal reset_frog		# reset the location of the frog
	
	# add one score
	lw $t3, score
	addi, $t3, $t3, 1
	sw $t3, score
	
not_reach_goal:
	# pop the word off the stack and move the stack pointer by a word
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	
	jr $ra	
#########################  Function to display death animation ######################### 

Exit:
	li $v0, 10 			# terminate the program gracefully
	syscall

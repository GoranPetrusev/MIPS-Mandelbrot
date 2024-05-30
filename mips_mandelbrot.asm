.data
frame_buffer: .space 0x80000

# dimensions
f_width: .float 511.0
f_height: .float 255.0

.text
la $t0, frame_buffer 	# Load adress of frame buffer, also points to the current pixel
li $t1, 0x20000 		# 512x256 pixels counter
li $s0, 0x00ffffff		# White color
li $t7, 32				# Max iterations

li $t5, 0x40800000	# load 4.0 into f8 with floating point representation
mtc1 $t5, $f8
li $t5, 0x40000000	# load 2.0 into f7 with floating point representation
mtc1 $t5, $f7
li $t5, 0x3f800000	# load 1.0 into f6 with floating point representation
mtc1 $t5, $f6
li $t5, 0x3f000000	# load 0.5 into f6 with floating point representation
mtc1 $t5, $f5

la $s1, frame_buffer	# Constant pointer to the start of the frame buffer

fill:
	## Calculate current framer buffer offset
	# t2 : curr_px
	sub $t2, $t0, $s1
	div $t2, $t2, 4


	## Map from a 1D pixel buffer array to a 2D (x,y) coordinate system where the origin is in the top left
	# t3 : y
	# t4 : x

	# Find y	(curr_px / width)
	div $t3, $t2, 512	# t3 = curr_px / 512

	# Find x	(curr_px - y * width)
	mul $t4, $t3, 512	# t4 = y * 512
	sub $t4, $t2, $t4	# t4 = curr_px - t4



	## Map (x,y) coordinates onto complex plane

	# x [0, 512) -> rx (-2.0, 2.0)
	# Move t4 into f4 and convert into a single precision float
	mtc1 $t4, $f4
	cvt.s.w $f4, $f4
	# Get in range (0.0, 1.0)
	l.s $f1, f_width
	div.s $f4, $f4, $f1
	# Get in range (0.0, 4.0)
	mul.s $f4, $f4, $f8
	# Get in range (-2.0, 2.0)
	sub.s $f4, $f4, $f7
	# Get in range (-2.5, 1.5)
	sub.s $f4, $f4, $f5
	
	# y [0, 256) -> ry [-1.0, 1.0]
	# Move t3 into f3 and convert into a single precision float
	mtc1 $t3, $f3
	cvt.s.w $f3, $f3
	# Get in range from (0.0, 1.0)
	l.s $f1, f_height
	div.s $f3, $f3, $f1
	# Get in range (0.0, 2.0)
	mul.s $f3, $f3, $f7
	# Get in range (-1.0, 1.0)
	sub.s $f3, $f3, $f6


	## Run mandelbrot escape algorithm for current position
	# reset registers
	li $t5, 0 # iteration counter
	mul.s $f9, $f9, $f31 # temporary x
	mul.s $f10, $f10, $f31 # current x
	mul.s $f11, $f11, $f31 # current y
	mul.s $f20, $f20, $f31 # tmp
	mul.s $f21, $f21, $f31 # tmp
	mul.s $f22, $f22, $f31 # tmp
	# f3 - starting y
	# f4 - starting x
	
	run:
		# temporary x value
		mul.s $f20, $f10, $f10	# x * x
		mul.s $f21, $f11, $f11	# y * y		
		add.s $f22, $f21, $f20	# distance from origin point (start_x, start_y)
		sub.s $f9, $f20, $f21	# x^2 - y^2
		add.s $f9, $f9, $f4		# tmp_x + start_x
		
		# new y value
		mul.s $f20, $f10, $f11	# x * y
		mul.s $f20, $f20, $f7	# x * y * 2.0
		add.s $f11, $f20, $f3	# x * y * 2.0 + start_y
		
		# new x value
		mov.s $f10, $f9
		
		addi $t5, $t5, 1	# iteration++
		
		## escape conditions
		# f22 - distance from origin, f8 - stored 4.0
		c.lt.s $f22, $f8
		bc1f escape

		# t5 - current iteration, t7 - max iteration (32)
		slt $t6, $t5, $t7
		beqz $t6, escape
		
		j run
	escape:
	
	## Color pixels
	bnez $t6, coloring_skip
	sw $s0, 0($t0)

	coloring_skip:
	addi $t0, $t0, 4
	addi $t1, $t1, -1
	
bnez $t1, fill

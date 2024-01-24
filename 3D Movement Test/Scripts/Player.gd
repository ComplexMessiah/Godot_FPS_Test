extends CharacterBody3D

# Player Nodes
@onready var neck = $neck
@onready var head = $neck/head
@onready var eyes = $neck/head/eyes
@onready var standing_coll_shape = $standing_coll_shape
@onready var crouching_coll_shape = $crouching_coll_shape
@onready var crouchjump_coll_shape = $crouchjump_coll_shape
@onready var headbonk_raycast = $headbonk_raycast
@onready var crouchjump_raycast = $crouchjump_raycast

# Speed Vars
var current_speed = 5.0

var walk_speed = 5.0
var sprint_speed = 8.0
var crouchwalk_speed = 3.0
var slide_speed = 10.0

# States
var walking = false
var sprinting = false
var crouching = false
var crouchjumping = false
var free_looking = false
var sliding = false

# Headbob vars
const headbob_sprinting_speed = 22.0
const headbob_walking_speed = 14.0
const headbob_crouching_speed = 10.0

const headbob_sprinting_intensity = 0.2
const headbob_walking_intensity = 0.1
const headbob_crouching_intensity = 0.05

var headbob_curr_intensity = 0.0
var headbob_vector = Vector2.ZERO
var headbob_index = 0.0

#Slide vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO

# Movement vars
var crouching_depth = -0.5

const jump_velocity = 4.5

var lerp_speed = 10.0
var air_lerp_speed = 1.0

var freelook_tilt = 6

# Input vars
var direction = Vector3.ZERO
const mouse_sens = 0.25

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Runs once on scene load
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
# Captures inputs
func _input(event):
	# Mouselook & Freelook logic
	if event is InputEventMouseMotion:
		if free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
			neck.rotation.y = clamp(neck.rotation.y,deg_to_rad(-120),deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

# Runs on every physics tick
func _physics_process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	
	#Get movement input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	# Handles Crouchjumping
	if Input.is_action_pressed("crouch") && not is_on_floor():
		# Handle crouchjumping for jump height gain
		crouchjumping = true
		walking = false
		sprinting = false
		crouching = false
		
		standing_coll_shape.disabled = true
		crouching_coll_shape.disabled = true
		crouchjump_coll_shape.disabled = false
		
		# Handles crouching
	elif Input.is_action_pressed("crouch") && is_on_floor() || sliding:
		current_speed = lerp(current_speed,crouchwalk_speed,delta*lerp_speed)
		head.position.y = lerp(head.position.y,0.0 + crouching_depth, delta * lerp_speed)
		
		standing_coll_shape.disabled = true
		crouching_coll_shape.disabled = false
		crouchjump_coll_shape.disabled = true
		
		walking = false
		sprinting = false
		crouching = true
		crouchjumping = false
		
		# Slide start logic
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			free_looking = true
		
	elif !headbonk_raycast.is_colliding():
		
	# Standing
		crouching_coll_shape.disabled = true
		standing_coll_shape.disabled = false
		crouchjump_coll_shape.disabled = true
		
		head.position.y = lerp(head.position.y,0.0,delta*lerp_speed)
		
	# Sprinting
		if Input.is_action_pressed("sprint"):
			current_speed = lerp(current_speed,sprint_speed,delta*lerp_speed)
			
			walking = false
			sprinting = true
			crouching = false
			crouchjumping = false
			
		else:
			# Walking
			current_speed = lerp(current_speed,walk_speed,delta*lerp_speed)
					
			walking = true
			sprinting = false
			crouching = false
			crouchjumping = false
			
	# Handles freelook
	if sliding:
		free_looking = true
		eyes.rotation.z = -deg_to_rad(neck.rotation.y*freelook_tilt)
	else: 
		free_looking = false
		neck.rotation.y = lerp(neck.rotation.y,0.0,delta*lerp_speed)
		eyes.rotation.z = lerp(eyes.rotation.z,0.0,delta*lerp_speed)
		
	# Handles sliding timer
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false
			free_looking = false
		
	# Handles headbob
	if sprinting:
		headbob_curr_intensity = headbob_sprinting_intensity
		headbob_index += headbob_sprinting_speed*delta
	elif walking:
		headbob_curr_intensity = headbob_walking_intensity
		headbob_index += headbob_walking_speed*delta
	elif crouching:
		headbob_curr_intensity = headbob_crouching_intensity
		headbob_index += headbob_crouching_speed*delta
		
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		headbob_vector.y = sin(headbob_index)
		headbob_vector.x = sin(headbob_index*0.5)+0.5
		
		eyes.position.y = lerp(eyes.position.y,headbob_vector.y*(headbob_curr_intensity*0.5),delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x,headbob_vector.x*headbob_curr_intensity,delta*lerp_speed)
		
	else:
		eyes.position.y = lerp(eyes.position.y,0.0,delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x,0.0,delta*lerp_speed)

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		sliding = false
		
	# Handle crouchjump collision
	if !is_on_floor() && crouchjump_raycast.is_colliding:
		standing_coll_shape.position.y = standing_coll_shape.position.y + 0.5

	# Get the input direction and handle the movement/deceleration.
	if is_on_floor():
		direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*lerp_speed)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*air_lerp_speed)
		
	if sliding:
		direction = (transform.basis * Vector3(slide_vector.x,0,slide_vector.y)).normalized()
		current_speed = (slide_timer + 0.2) * slide_speed
		
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
		
	move_and_slide()

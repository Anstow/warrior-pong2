package
{
	import net.flashpunk.Entity;
	
	public class Player extends Entity
	{
		public var vel : Vector.<Number>;
		public var id : int;
		public var muted : Boolean;

		public var input : GameInput;

		public var aimEntity : AimEntity;
		public var angle : Number = 0;
		private var image : MyPreRotation;
		public var fireCounter : Number = 0;

		private var noBallsFired : int;
		public var modeAim:Boolean = true;

		public function Player(ident:int, pos:Array, inp:GameInput, muted:Boolean) {
			// Set the initial velocity of the player
			vel = new Vector.<Number>(2, true);
			vel[0] = 0;
			vel[1] = 0;
			// set the id of the player
			id  = ident;
			input = inp;
			// set collide type
			type = "player" + id;
			this.muted = muted;
			// set possition
			super(pos[0], pos[1]);
			// Set the hitbox
			setHitbox(GC.playerWidth, GC.playerHeight);
			// Add sprites
			image = GC.getClippedImg(GC.playerGraphicsBoxes[ident]);
			addGraphic(image);

			noBallsFired = GC.playerStartBallsFired;
			aimEntity = new AimEntity([x,y], ident);
			if (world) world.add(aimEntity);
		}
		
		override public function update():void {
			super.update();

			checkInput();
			shooting();
			updateSim();
			checkCollisions(); // this may be a misnomer updateSim also does a fair bit of collision checking.
		}

		override public function added():void {
			super.added();
			if (aimEntity) world.add(aimEntity);
		}

		override public function removed():void {
			if (aimEntity) world.remove(aimEntity);
		}

		public function checkInput():void {
			// Check for input
			if (modeAim) {
				if (input.check("left_target"+id)) {
					// Target left
					angle += GC.targettingAngleChange;
					// clamp the angle to the region
					if (angle > GC.targettingAngleClamp) angle = GC.targettingAngleClamp;
					aimEntity.setAngle(angle);
				}
				if (input.check("right_target"+id)) {
					// Target right
					angle -= GC.targettingAngleChange;
					if (angle < -GC.targettingAngleClamp) angle = -GC.targettingAngleClamp;
					aimEntity.setAngle(angle);
				}
			} else {
				if (input.check("left"+id)) {
					vel[0] -= GC.moveSpeed;
				}
				if (input.check("right"+id)) {
					vel[0] += GC.moveSpeed;
				}
			}
			if (input.pressed("switch_mode" + id)) {
				modeAim = !modeAim;
			}
		}

		public function updateSim():void {
			// Damp the velocity to get smoother movement
			vel[0] *= GC.playerDamp[0];
			vel[1] *= GC.playerDamp[1];

			// Avoid anoying pass by reference
			var remainingVel : Array = [vel[0],vel[1]];
			// If we are moving (sufficiently fast) move!
			while (remainingVel[0]*remainingVel[0] + remainingVel[1]*remainingVel[1] > 0.01) {
				var collisionData : Array = Level.CalculateCollideTimes([0,0], remainingVel, [left,right,top,bottom]);
				if (collisionData) {
					// We have collided so move to the colision point
					x += remainingVel[0]*collisionData[0]; y += remainingVel[1]*collisionData[0];
					switch (collisionData[1])
					{
						case 0:
							// We have hit the left wall
							// bounce, remove the current movement and repeat
							remainingVel[0] *= GC.playerBounce[0] * (1 - collisionData[0]);
							remainingVel[1] *= (1 - collisionData[0]);
							// Set the velocity for the next frame
							vel[0] *= GC.playerBounce[0];
							break;
						case 1:
							// We have hit the right wall
							// bounce, remove the current movement and repeat
							remainingVel[0] *= GC.playerBounce[1] * (1 - collisionData[0]);
							remainingVel[1] *= (1 - collisionData[0]);
							// Set the velocity for the next frame
							vel[0] *= GC.playerBounce[1];
							break;
						case 2:
							// We have hit the bottom wall
							// bounce, remove the current movement and repeat
							remainingVel[0] *= (1 - collisionData[0]);
							remainingVel[1] *= GC.playerBounce[2] * (1 - collisionData[0]);
							// Set the velocity for the next frame
							vel[1] *= GC.playerBounce[2];
							break;
						case 3:
							// We have hit the bottom wall
							// bounce, remove the current movement and repeat
							remainingVel[0] *= (1 - collisionData[0]);
							remainingVel[1] *= GC.playerBounce[3] * (1 - collisionData[0]);
							// Set the velocity for the next frame
							vel[1] *= GC.playerBounce[3];
							break;
						default:
							// Ok this shouldn't have happened lets pretend it didn't and just update normally
							remainingVel = [0,0];
							break;
					}
				} else {
					// We haven't collided
					x += remainingVel[0]; y += remainingVel[1];
					remainingVel = [0,0];
				}
			}
			// Resorting to terrible clampling
			// TODO: don't rely on something quite so terrible
			if (left < 0) {
				x = originX;
				vel[0] *= -1;
			} else if (right > GC.windowWidth) {
				x = GC.windowWidth + originX - width;
				vel[0] *= -1;
			}
			if (top < 0) {
				y = originY;
				vel[1] *= -1;
			} else if (bottom > GC.windowHeight) {
				y = GC.windowHeight + originY - height;
				vel[1] *= -1;
			}

			if (aimEntity) {
				aimEntity.setPos([x,y]);
			}
		}

		public function shooting():void {
			fireCounter++;
			if (fireCounter == GC.invFireRate) {
				fireCounter = 0;
				shoot();
			}
		}

		public function shoot():void {
			if (world) {
				var a : Number = angle - GC.shotSpread * (noBallsFired-1) / 2.0;
				var b : Number = angle - GC.shotStartOffset * (noBallsFired-1) / 2.0;
				var pos:Array = aimEntity.getPos();
				pos[0] += Math.sin(angle)*GC.shotStartRadius;
				pos[1] += Math.cos(angle)*GC.shotStartRadius;
				for (var i:int = 0; i < noBallsFired; i++) {
					world.add(
							new Ball(
								[pos[0] - Math.sin(b + i*GC.shotStartOffset)*GC.shotStartRadius, pos[1] - Math.cos(b + i*GC.shotStartOffset)*GC.shotStartRadius],
							   	[-Math.sin(a + i*GC.shotSpread)*GC.ballSpeed, -Math.cos(a + i*GC.shotSpread)*GC.ballSpeed],
							   	muted, id));
				}
			}
		}

		public function checkCollisions():void {
		}

		// Getter, setters for powerup properties
		public function get NoBallsFired():uint {
			return noBallsFired;
		}

		public function set NoBallsFired(balls:uint):void {
			// Do some bounds checking
			if (balls >= GC.playerMinBallsFired && balls <= GC.playerMaxBallsFired) {
				noBallsFired = balls;
			}
		}
	}
}

// vim: foldmethod=indent:cindent

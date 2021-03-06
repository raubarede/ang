# Creative Commons BY-SA :  Regis d'Aubarede <regis.aubarede@gmail.com>
###########################################################################
#   ANG.RB : planetoide game
#--------------------------------------------------------------------------
# install ruby
# install Gosu	> gem install gosu
# download this > git http://github.com/rdaubarede/ang.git
# run			> ruby main.rb
# do your own version :
#      > loop { edit/main.rb ; ruby main.rb }
# make your disribution :
#      > ocra main.rb
#
###########################################################################
require 'rubygems'
require 'gosu'

# KK=0.5
# SX=1280/KK
# SY=900/KK
KK=0.5
SX=640/KK
SY=480/KK

module ZOrder
  Background, Stars, Player, UI = [0,1,2,3]
end
class Numeric
	def minmax(min,max=nil)
	  (max=min;min=-min) if !max
	  return self if self>=min && self<=max
	  return(min) if self<min
	  return(max)
	end
end
class Range ; def rand() self.begin+Kernel.rand((self.end-self.begin).abs) end ; end

def e(a,b) (20.0/(a-b)).minmax(-10,+10) end

def newton_xy(p1,p2,a,b)
 k=1.0/40000
 dx,dy=[a.x-b.x,a.y-b.y]
 d=Math::sqrt(dx ** 2 + dy ** 2)
 #f=(k*p1*p2/(d*d)).minmax(100) : k/d**2 not good for gameplay
 f=(k*p1*p2/(d)).minmax(10)
 teta=Math.atan2(dy,dx)   
 [-f*Math.cos(teta),-f*Math.sin(teta)]
end

###########################################################################
#                        P l a y e r
###########################################################################
# move by arrow keyboard acceleration commande, 
# eat star, move with current speed, and attractive planets
class Player
  attr_reader :x,:y,:r
  attr_accessor  :score
  def initialize(window,animation)
    @animation = animation
    @app=window
	@r=15
	@pos=1
	self.restart()
  end
  def restart
    @vel_x = @vel_y = @angle = @vangle = 0.0
    @x = SX/2
	@y = SY/2
    @score = 2000
	@lxy=[]
  end
  def clear
    @pos=1
  end
  def warp(x, y)    @x, @y = x, y  ; end
  def turn_left()    @pos=3 ;  @vangle -= 0.3 ; end
  def turn_right()   @pos=4 ;  @vangle += 0.3 ; end  
  def accelerate(s)
    @pos= s ? 0 : 2
    @score-=3
    @vel_x += Gosu::offset_x(@angle, s ? 0.1 : -0.1)
    @vel_y += Gosu::offset_y(@angle, s ? 0.1 : -0.1)
  end
  
  def move(stars)
    @x += @vel_x
    @y += @vel_y
	@vel_x *= -1 if @x >= SX || @x <= 0 
	@vel_y *= -1 if @y >= SY || @y <= 0
	@x -= 10 if @x >= SX   && @vel_x == 0
	@y -= 10 if @y >= SY  && @vel_y == 0
	@x += 10 if @x <= 0   && @vel_x == 0
	@y += 10 if @y <= 0   && @vel_y == 0
    
    #@vel_x *= 0.998
    #@vel_y *= 0.998
	@angle+=@vangle
	@vangle=@vangle*95.0/100
	@lxy << [@x,@y] if @vel_x!=0 && @vel_y!=0
	vx,vy=newton(stars)
	@vel_x+=vx
	@vel_y+=vy
    @vel_x.minmax(-50,+50)
    @vel_y.minmax(-50,+50)
  end
  def  newton(stars)
	vx = vy = 0.0
	stars.each  do |star|
	  next if star.type
	  d=Gosu::distance(@x,@y,star.x,star.y)-15-star.r
	  dx,dy=*newton_xy(15*15,star.r*star.r,self,star)
	  vx+=dx
	  vy+=dy
	end
	[vx,vy]
  end

  def draw(app,stars)
	img = @animation[@pos]
    img.draw_rot(@x, @y, ZOrder::Player, @angle)  # (@x, @y, ZOrder::Stars, 0, 0.5,0.5 ,@r/10, @r/10,@color)  
	#@image.draw_rot(@x, @y, ZOrder::Player, @angle)
    x,y=newton(stars) ; app.draw_line(@x,@y, 0xffffffff,@x+x*1000,@y+y*1000,0xffffffff)  # debug: mark gravity force
	if app.is_pending
		@lxy.each_cons(2) { |p0,p1| app.draw_line(p0[0],p0[1], 0xffffff00 ,p1[0],p1[1], 0xffffff00 ) if p1} rescue nil
	elsif @lxy.size>100
		@lxy[(-1*[300,@lxy.size].min)..-1].each_cons(2) { |p0,p1| 
			app.draw_line(p0[0],p0[1], 0x33ffff00 ,p1[0],p1[1], 0x33ffff00 ) if p1
		} rescue nil
	end
	@lxy=@lxy[-5000..-1] if @lxy.size>10000
  end
  
  def collect_stars(stars)
    stars.reject!  do |star|
      if Gosu::distance(@x, @y, star.x, star.y) < (15+star.r) then
		if star.type
			@score += 70
			true
		else
			if @vel_x !=0 || @vel_y!=0			
				@score -= 10
				@x -= 15*@vel_x
				@y -= 15*@vel_y
			else
				@x += (-10..+10).rand
				@y += (-10..+10).rand
			end
			@vel_x=0
			@vel_y=0
			false
		end
	  else
		false
      end
    end
	@app.looser if @score<=0
	@app.winner(@score) if 0 == (stars.select { |s| s.type }.size )
  end
  
end


###########################################################################
#                        S t a r 
###########################################################################
class Star
  attr_reader :x, :y, :type,:r
  
  def initialize(ls,type,animation)
    @animation = animation
	@ls=ls
	@type=type
	@r=@type ? 10 : (20..60).rand()
	@color = Gosu::Color.new(0xff000000 )
    @color.red =   type ? 255 : 0
    @color.green = type ? 0   : 200 
    @color.blue =  type ? 0   : 200
    @x = (SX/5..(SX-SX/5)).rand
    @y = (SY/5..(SY-SY/5)).rand
  end
  def move(player)
	expand(player)
  end
  def draw()
    img = @animation[self.type ? 1 : 0 ]
    img.draw_rot(@x, @y, ZOrder::Stars, 0, 0.5,0.5 ,@r/10, @r/10,@color)
  end
  def expand(p) 
    ox,oy=@x,@y
	@ls.each do |s| 
		next if s==self
		(@x+=e(@x,s.x) ; @y+=e(@y,s.y) ) if Gosu::distance(@x,@y,s.x,s.y)< ((s.type && self.type) ? 100 : 0 )
	end
	d=Gosu::distance(@x,@y,p.x,p.y)-@r-p.r
	if @type 
	   (@x+=-e(p.x,@x)/0.5 ; @y+=-e(p.y,@y)/0.5 )  if   d> 20 && d < 180 
	else
	   (@x+=e(p.x,@x)/5.0 ; @y+=e(p.y,@y)/5.0 )  if   d> 20 && d < 0 
	end
	@x=ox if @x>600 || @x<40
	@y=oy if @y>440 || @y<40
  end
end

###########################################################################
#                        W i n d o w
###########################################################################

class GameWindow < Gosu::Window
   attr_reader :star,:ping
  def initialize
    super((SX*KK).to_i, (SY*KK).to_i, false)
    self.caption = "Gosu Tutorial Game"
    
	@lp=[]; 100.times { x=rand(SX) ; y=rand(SY); @lp<<x;@lp<<y }
    @player_anim=  Gosu::Image::load_tiles(self, "Starfighter2.bmp", 50,50, false)
    @player = Player.new(self,@player_anim)
    @player.warp(320, 240)
    @font = Gosu::Font.new(self, Gosu::default_font_name, (20/KK).round)
    @font2 = Gosu::Font.new(self, Gosu::default_font_name, (40/KK).round)

    @star_anim = Gosu::Image::load_tiles(self, "Star.png", 25,25, false)
	@ping=0
	@start=0
	@mouse=nil
    self.go("Start")
  end

	######################## Game global state 
	
	def looser() ego("Loose") end
	def winner(n) ego("Winne #{n}") end
	def ego(text)
	    puts "ego #{text}"
		@text=text
		@start=@ping+50
		Thread.new { sleep 2 ; self.go("Start") }
	end
	def go(text)
		@start=@ping+200
		@text=text
		@stars = Array.new
		3.times { @stars.push( Star.new(@stars,false,@star_anim) ) }
		10.times { @stars.push( Star.new(@stars,true,@star_anim) ) }
		@player.restart
	end
	def is_pending() (@start > @ping) end
	
	######################## Global interactions  : mouse/keyboard
	
	def interactions()
		@player.turn_left    if button_down? Gosu::KbLeft       or button_down? Gosu::GpLeft 
		@player.turn_right   if button_down? Gosu::KbRight      or button_down? Gosu::GpRight
		@player.accelerate(true)   if button_down? Gosu::KbUp   or button_down? Gosu::GpButton0
		@player.accelerate(false)  if button_down? Gosu::KbDown or button_down? Gosu::GpButton1
		#mouse_control
	end
	def  mouse_control
		n=[mouse_x,mouse_y]
		@mouse=n unless @mouse
		dx=n[0]-@mouse[0]
		dy=n[1]-@mouse[1]
		if Math.hypot(dx,dy)>D
			@player.turn_left  if dx<-D
			@player.turn_right  if dx>D
			@player.accelerate(true)  if dy<-D
			@player.accelerate(false) if dx>D
		end
		@mouse=n
	end
	def button_down(id)
		if id == Gosu::KbEscape
		  if @player.score==0
			close
		  else
		    @player.score=0
		  end
		end
	end
	
	######################## Global draw : update()/draw() are invoked continuously by Gosu engine
	
	def update
		@ping+=1
		return if @ping<@start
		@player.clear()
		interactions()
		@player.move(@stars)
		@player.collect_stars(@stars)    
		@stars.each { |star| star.move(@player) }
	end
	
	def draw
		scale(KK,KK) {
			draw_background
			@player.draw(self,@stars)
			@stars.each { |star| star.draw() }
			draw_variable_background()
		}
	end
	def draw_background
		@lp.each_slice(2) do |x,y| 
			draw_triangle(
				x, y, 0xAAFFFFFF, 
				x+(3..5).rand, y+(3..5).rand,  0xAAFFFFFF, 
				x+(3..5).rand, y,  0xAAFFFFFF) 
		end
	end		
	def draw_variable_background()
		if @ping<@start
			@font2.draw(@text+ "  ! !", SX/2, SY/2, ZOrder::UI, 1.0, 1.0, 0xf0f0f000)
			@font.draw("", 10, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
		else		
			#----------- barr graph energies reserve level
			h=5+(@player.score/2000.0)*(SY-10)
			draw_quad(5, 5, 0xBB55FF55, 20/KK, 5,  0xBB55FF55, 20/KK, h,  0xBBFFFF55, 5 , h , 0xBBFFFF55)
			
			#------------ textual energie reserve level
			@font.draw("Score: #{@player.score}", 25/KK, 10/KK, ZOrder::UI, 1.0, 1.0, 0xffffff00)
		end
	end
end

GameWindow.new.show

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("entities/base_wire_entity/init.lua")
include("shared.lua")

function ENT:Initialize()
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self.phys = self.Entity:GetPhysicsObject()
	if (self.phys:IsValid()) then
		self.phys:Wake()
		self.phys:EnableGravity(false)
		self.phys:SetMass((self.ConTable.damage+self.ConTable.radius)/(self.ConTable.shootdelay+self.ConTable.reloadtime))
	end
	self.Reloaded=true
	if wire then
		self.Inputs=Wire_CreateInputs(self.Entity, {"Fire"})
		self.Outputs=Wire_CreateOutputs(self.Entity, {"Ammo","CanFire"})
	end
	self.NextShoot=0
	self.Sound = CreateSound(self.Entity,self.ConTable.soundShoot)
	self.SoundStop=0
	self.MagazineLoad=self.ConTable.msize
end

function ENT:TriggerInput(name, value)
	if name=="Fire" then
		self.firing = (value==1 and true or false)
	end
end

function ENT:AddVehicle(e)
	self.Vehicle=e
end

function ENT:FireGun(act)
	local crt=CurTime()
	if self.NextShoot<=crt and self.MagazineLoad>0 then
		act = act or self:GetOwner()
		self.NextShoot=crt+self.ConTable.shootdelay
		self.SoundPlayed=false
		self.Sound:Stop()
		self.SoundStop=crt+1
		local shootvec = self:GetUp()*(self:OBBMaxs().z+5)
		local selfpos = self:GetPos()
		local selfspeed = self:GetVelocity()
		if self.ConTable.mode==0 or self.ConTable.mode==2 then
			local bullet = ents.Create("wac_w_base_bullet")
			bullet.ConTable=table.Copy(self.ConTable)
			constraint.NoCollide(self.Entity, bullet, 0, 0)
			bullet:SetAngles(self:GetAngles())
			bullet:SetPos(selfpos + shootvec)
			bullet:Spawn()
			bullet:Activate()
			bullet.targetpos = vec
			bullet.oldpos = (selfpos - shootvec)
			bullet.tracehitang = self:GetAngles()
			bullet.Owner = act or self.Owner
			if !bullet.phys then bullet.phys = bullet:GetPhysicsObject() end		
			local effectdata = EffectData()
			effectdata:SetOrigin(selfpos + shootvec)
			effectdata:SetAngles(shootvec:Angle())
			effectdata:SetScale(self.ConTable.damage/150)
			util.Effect("wac_tank_shoot", effectdata)		
			if self.phys:IsValid() then
				self.phys:AddVelocity(shootvec*-self.ConTable.damage/10)
			end
			self.Sound:ChangeVolume(450,0)
			self.Sound:Play()
			if bullet.phys:IsValid() then
				bullet.phys:SetVelocity(selfspeed + shootvec*3500)
			end
		elseif self.ConTable.mode==1 then
			local bullet = ents.Create("wac_w_rocket")
			bullet:SetAngles(shootvec:Angle())
			bullet:SetPos(selfpos+shootvec)
			bullet:Spawn()
			bullet:Activate()
			bullet.tracehitang=bullet:GetAngles()
			bullet.Owner = act or self.Owner
			bullet.StartTime=1
			bullet.ConTable=table.Copy(self.ConTable)
			self.Rocket=bullet
			self.Sound:ChangeVolume(450,0)
			self.Sound:Play()
			if !bullet.phys then bullet.phys = bullet:GetPhysicsObject() end	
			if bullet.phys:IsValid() then
				bullet.phys:SetVelocity(self.Owner:GetVelocity()+shootvec*400)
			end
		end
		self.MagazineLoad=self.MagazineLoad-1
	end
end

function ENT:OnTakeDamage(dmginfo)
	self.Entity:TakePhysicsDamage(dmginfo)	
end

function ENT:Think()
	local crt=CurTime()
	if self.ConTable.mode==1 then
		if IsValid(self.Rocket) then
			self.Rocket.targetpos = util.QuickTrace(self:GetPos(),self:GetAngles():Up()*9999999,self.Entity).HitPos
		end
	end
	if self.SoundStop <= crt then
		self.Sound:Stop()
	end
	if self.MagazineLoad == 0 and crt>self.NextShoot-self.ConTable.reloadtime/2 and !self.SoundPlayed then
		self.SoundPlayed = true
		self.Entity:EmitSound(self.ConTable.soundReload, 300)
	end
	if self.MagazineLoad==0 and crt+self.ConTable.reloadtime>self.NextShoot then
		self.MagazineLoad=self.ConTable.msize
		self.NextShoot=CurTime()+self.ConTable.reloadtime
	end
	if
		IsValid(self.Vehicle) and self.Vehicle:GetPassenger():IsValid()
		and self.Vehicle:GetPassenger():KeyDown(IN_ATTACK)
	then
		self.firing = false
		self:FireGun(self.Vehicle:GetPassenger())
	end
	if self.firing then
		self:FireGun()
	end
	if wire then
		Wire_TriggerOutput(self.Entity, "Ammo", self.MagazineLoad)
		Wire_TriggerOutput(self.Entity, "CanFire", (self.NextShoot<crt and self.MagazineLoad>0) and 1 or 0)
	end
	self:NextThink(crt)
	return true
end

function ENT:BuildDupeInfo()
	local info = WireLib.BuildDupeInfo(self.Entity) or {}
	if (self.Vehicle) and (self.Vehicle:IsValid()) then
		info.v = self.Vehicle:EntIndex()
	end
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	WireLib.ApplyDupeInfo(ply, ent, info, GetEntByID)
	if (info.v) then
		self.Vehicle = GetEntByID(info.v)
		if (!self.Vehicle) or self.Vehicle != GetEntByID(info.v) then
			self.Vehicle = ents.GetByIndex(info.v)
		end
	end
end

function ENT:OnRemove()
	self.Sound:Stop()
end

numpad.Register("fireGun", function(p, e)
	if !e or !e:IsValid() then return end
	e.firing = true
end)

numpad.Register("stopFire", function(p, e)
	if !e or !e:IsValid() then return end
	e.firing = false
end)

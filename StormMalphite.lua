--[[
    First Release By Storm Team (Martin) @ 25.Nov.2020    
]]

if Player.CharName ~= "Malphite" then return end

require("common.log")
module("Storm Malphite", package.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Malphite = {}

local spells = {
    Q = Spell.Targeted({
        Slot = Enums.SpellSlots.Q,
        Range = 620,
        Delay = 0.25,
    }),
    W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Delay = 0.25,
    }),
    E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 400,
        Delay = 0.2419,
    }),
    R = Spell.Skillshot({
        Slot = Enums.SpellSlots.R,
        Range = 1000,
        Radius = 250,
        Delay = 0,
        Speed = 1835,
        Type = "Circular",
        UseHitbox = true
    }),
}
local function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "minions")) do
        local hero = v.AsAI
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Malphite.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end
local lastTick = 0
function Malphite.OnTick()    
    if not GameIsAvailable() then return end 

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime    

    if Malphite.Auto() then return end
    if not Orbwalker.CanCast() then return end

    local ModeToExecute = Malphite[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Malphite.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Malphite.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Malphite.ComboLogic(mode)
    if Malphite.IsEnabledAndReady("Q", mode) then
        for k, qTarget in ipairs(Malphite.GetTargets(spells.Q.Range)) do
            if spells.Q:Cast(qTarget) then
                return
            end
        end
    end
    if Malphite.IsEnabledAndReady("E", mode) then
        for k, eTarget in ipairs(Malphite.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end

    if Malphite.IsEnabledAndReady("R", mode) then
        local points = {}
        for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
            local pred = spells.R:GetPrediction(rTarget)
            if pred and pred.HitChanceEnum >= Enums.HitChance.High then
                insert(points, pred.CastPosition)
            end
        end
            local bestPos, hitCount = spells.R:GetBestCircularCastPos(points)
            if hitCount >= Menu.Get("Combo.UseRh") then
                spells.R:Cast(bestPos)
            end
        
    end
   
end
function Malphite.HarassLogic(mode)
    local Mana = Menu.Get("Harass.Mana")
    if Mana > (Player.ManaPercent * 100) then return end
    if Malphite.IsEnabledAndReady("Q", mode) then
        for k, qTarget in ipairs(Malphite.GetTargets(spells.Q.Range)) do
            if spells.Q:Cast(qTarget) then
                return
            end
        end
    end
    if Malphite.IsEnabledAndReady("E", mode) then
        for k, eTarget in ipairs(Malphite.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end 
end

function Malphite.Rdmg()
    return (200 + (spells.R:GetLevel() - 1) * 100) + (0.8 * Player.TotalAP)
end
function Malphite.Qdmg()
    return (70 + (spells.R:GetLevel() - 1) * 50) + (0.6 * Player.TotalAP)
end
---@param source AIBaseClient
---@param spell SpellCast
function Malphite.OnInterruptibleSpell(source, spell, danger, endT, canMove)
   
end
---@param _target AttackableUnit
function Malphite.OnPostAttack(_target)
    local Mana = Menu.Get("Clear.Mana")
    local UseW = Menu.Get("Clear.UseW")
    local usejW = Menu.Get("Clear.UseWJ")
    local target = _target.AsAI
    if not target  then return end
    
    local mode = Orbwalker.GetMode()
 
    if target.IsHero  then
        if Menu.Get("Combo.UseW") and mode == "Combo" and spells.W:IsReady() then
            spells.W:Cast()
                return
        end
    end
    if target.IsHero then
        if Menu.Get("Harass.UseW") and  mode == "Harass" and spells.W:IsReady() and Menu.Get("Harass.Mana") > (Player.ManaPercent * 100) then
            spells.W:Cast()
                return
        end
    end
    if target.IsMonster and usejW and mode == "Waveclear" then
        if UseW and  spells.W:IsReady() then
            spells.W:Cast()
                return
        end
    end
    if target.IsMinion and mode == "Waveclear" and Mana > (Player.ManaPercent * 100)  then
        if UseW and  spells.W:IsReady() then
            spells.W:Cast()
                return
        end
    end

end
---@param source AIBaseClient
---@param dash DashInstance
function Malphite.OnGapclose(source, dash)
    if not (source.IsEnemy and Menu.Get("Misc.GapQ") and spells.Q:IsReady()) then return end

    if source:Distance(Player) < 400 then
        spells.Q:Cast(source)        
        end
    end
function Malphite.Auto() 
    local KSR = Menu.Get("KillSteal.R")
    local KSQ = Menu.Get("KillSteal.Q")
    local rToKill = Menu.Get("Misc.ForceR") 
    if rToKill then 
        local points = {}
    for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
        local pred = spells.R:GetPrediction(rTarget)
        if pred and pred.HitChanceEnum >= Enums.HitChance.High then
            insert(points, pred.CastPosition)
        end
    end
        local bestPos, hitCount = spells.R:GetBestCircularCastPos(points)
        if hitCount >= Menu.Get("Misc.AutoR") then
            spells.R:Cast(bestPos)
        end
    
    end
    if KSR then 
        for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
             local rDmg = DmgLib.CalculatePhysicalDamage(Player, rTarget, Malphite.Rdmg())
             local ksHealth = spells.R:GetKillstealHealth(rTarget)
             if rDmg > ksHealth and  spells.R:CastOnHitChance(rTarget, Enums.HitChance.High) then
                return
             end 
        end
    end
    if KSQ then 
        for k, QTarget in ipairs(TS:GetTargets(spells.Q.Range, true)) do        
             local rDmg = DmgLib.CalculatePhysicalDamage(Player, QTarget, Malphite.Qdmg())
             local ksHealth = spells.Q:GetKillstealHealth(QTarget)
             if rDmg > ksHealth and  spells.Q:Cast(QTarget) then
                return
             end 
        end
    end
end   


function Malphite.Combo()  Malphite.ComboLogic("Combo")  end
function Malphite.Harass() Malphite.HarassLogic("Harass") end
function Malphite.Waveclear()
    local usejQ = Menu.Get("Clear.UseQJ")
    local usejE = Menu.Get("Clear.UseEJ")
if usejQ and spells.Q:IsReady() then
    for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = spells.Q:IsInRange(minion)
        if minionInRange and minion.IsMonster  and minion.IsTargetable then
            if spells.Q:Cast(minion) then 
                return
            end     
        end                  
    end
end
if usejE and spells.E:IsReady() then
    for k, v in pairs(ObjManager.Get("neutral", "minions")) do
        local minion = v.AsAI
        local minionInRange = spells.E:IsInRange(minion)
        if minionInRange and minion.IsMonster  and minion.IsTargetable then
            if spells.E:Cast() then 
                return
            end     
        end                  
    end
end

    local Mana = Menu.Get("Clear.Mana")
    local UseQ = Menu.Get("Clear.UseQ")
    local UseE = Menu.Get("Clear.UseE")
    local UseEC = Menu.Get("Clear.UseEC")
    if Mana > (Player.ManaPercent * 100) then return end
    if spells.Q:IsReady() and UseQ then
        for k, v in pairs(ObjManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            sort(minion, function(a, b) return a.MaxHealth > b.MaxHealth end) 
            local healthPred = spells.Q:GetHealthPred(minion)
            local minionInRange = minion and minion.MaxHealth > 6 and spells.Q:IsInRange(minion)
            local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
         
            if minionInRange and not shouldIgnoreMinion and minion.IsTargetable and healthPred > 0 and Malphite.Qdmg() > healthPred then
              spells.Q:Cast(minion)
            end       
        end
    end
    if spells.E:IsReady() and UseE then
        if CountEnemiesInRange(Player.Position,spells.E.Range) >= UseEC then
            spells.E:Cast()
        end
    end
      
        
end
function Malphite.Lasthit() 
    local useQ = Menu.Get("Lasthit.UseQ")
    if not spells.Q:IsReady() or not useQ then return end
    for k, v in pairs(ObjManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        sort(minion, function(a, b) return a.MaxHealth > b.MaxHealth end) 
        local healthPred = spells.Q:GetHealthPred(minion)
        local minionInRange = minion and minion.MaxHealth > 6 and spells.Q:IsInRange(minion)
        local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
     
        if minionInRange and not shouldIgnoreMinion and minion.IsTargetable and healthPred > 0 and Malphite.Qdmg() > healthPred then
          spells.Q:Cast(minion)
        end       

    end
end

function Malphite.LoadMenu()

    Menu.RegisterMenu("StormMalphite", "Storm Malphite", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFFD700FF, true)
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Checkbox("Combo.UseE",   "Use [E]", true)
            Menu.Checkbox("Combo.UseR",   "Use [R] when killable", true)
            Menu.Slider("Combo.UseRh", " R Hitcount", 2, 1, 5)   
            Menu.NextColumn()
            Menu.ColoredText("Harass", 0xFFD700FF, true)
            Menu.Slider("Harass.Mana", "Mana Percent ", 50,0, 100)
            Menu.Checkbox("Harass.UseQ",   "Use [Q]", true)   
            Menu.Checkbox("Harass.UseW",   "Use [W]", true)
            Menu.Checkbox("Harass.UseE",   "Use [E]", true)
        end)
        Menu.Separator()
        Menu.ColoredText("Jungle", 0xFFD700FF, true)
        Menu.Checkbox("Clear.UseQJ",   "Use [Q] Jungle", true) 
        Menu.Checkbox("Clear.UseWJ",   "Use [W] Jungle", true) 
        Menu.Checkbox("Clear.UseEJ",   "Use [E] Jungle", true) 
        Menu.ColoredText("Lane", 0xFFD700FF, true)
        Menu.Slider("Clear.Mana", "Clear when Player mana Percent > X", 50, 0, 100)   
        Menu.Checkbox("Clear.UseQ",   "Use [Q] Lane", true) 
        Menu.Checkbox("Clear.UseW",   "Use [W] Lane", true) 
        Menu.Checkbox("Clear.UseE",   "Use [E] Lane", true) 
        Menu.Slider("Clear.UseEC", "E Hitcount", 2, 1, 5)  
        Menu.ColoredText("Lasthit", 0xFFD700FF, true)
        Menu.Checkbox("Lasthit.UseQ",   "Use [Q] to lasthit", true) 
        Menu.Separator()

        Menu.ColoredText("KillSteal Options", 0xFFD700FF, true)
        Menu.Checkbox("KillSteal.R", "Use [R] to KS", true)     
        Menu.Checkbox("KillSteal.Q", "Use [Q] to KS", true)    
        Menu.Separator()

        Menu.ColoredText("Misc Options", 0xFFD700FF, true)      
        Menu.Checkbox("Misc.GapQ", "Use [Q] on Gapcloser", true) 
        Menu.Keybind("Misc.ForceR", "Force [R] Key", string.byte('T')) 
        Menu.Slider("Misc.AutoR", "Force R Hitcount", 2, 1, 5)  
        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFFD700FF, true)
        Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
        Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
        Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range")
        Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)     
    end)     
end

function OnLoad()
    Malphite.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Malphite[eventName] then
            EventManager.RegisterCallback(eventId, Malphite[eventName])
        end
    end    
    return true
end
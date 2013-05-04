local interface = wrap.CInterface.new()

interface:print('/* WARNING: autogenerated file */')
interface:print('')
interface:print('#include "THC.h"')
interface:print('#include "luaT.h"')
interface:print('#include "utils.h"')
interface:print('')
interface:print('')

-- specific to CUDA
local typename = 'CudaTensor'

-- cut and paste from wrap/types.lua
wrap.argtypes.CudaTensor = {
   
   helpname = function(arg)
                 if arg.dim then
                    return string.format('%s~%dD', typename, arg.dim)
                 else
                    return typename
                 end
              end,
   
   declare = function(arg)
                local txt = {}
                table.insert(txt, string.format("TH%s *arg%d = NULL;", typename, arg.i))
                if arg.returned then
                   table.insert(txt, string.format("int arg%d_idx = 0;", arg.i));
                end
                return table.concat(txt, '\n')
             end,
   
   check = function(arg, idx)
              if arg.dim then
                 return string.format('(arg%d = luaT_toudata(L, %d, "torch.%s")) && (arg%d->nDimension == %d)', arg.i, idx, typename, arg.i, arg.dim)
              else
                 return string.format('(arg%d = luaT_toudata(L, %d, "torch.%s"))', arg.i, idx, typename)
              end
           end,
   
   read = function(arg, idx)
             if arg.returned then
                return string.format("arg%d_idx = %d;", arg.i, idx)
             end
          end,
   
   init = function(arg)
             if type(arg.default) == 'boolean' then
                return string.format('arg%d = TH%s_new();', arg.i, typename)
             elseif type(arg.default) == 'number' then
                return string.format('arg%d = %s;', arg.i, arg.args[arg.default]:carg())
             else
                error('unknown default tensor type value')
             end
          end,
   
   carg = function(arg)
             return string.format('arg%d', arg.i)
          end,
   
   creturn = function(arg)
                return string.format('arg%d', arg.i)
             end,
   
   precall = function(arg)
                local txt = {}
                if arg.default and arg.returned then
                   table.insert(txt, string.format('if(arg%d_idx)', arg.i)) -- means it was passed as arg
                   table.insert(txt, string.format('lua_pushvalue(L, arg%d_idx);', arg.i))
                   table.insert(txt, string.format('else'))
                   if type(arg.default) == 'boolean' then -- boolean: we did a new()
                      table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.%s");', arg.i, typename))
                   else  -- otherwise: point on default tensor --> retain
                      table.insert(txt, string.format('{'))
                      table.insert(txt, string.format('TH%s_retain(arg%d);', typename, arg.i)) -- so we need a retain
                      table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.%s");', arg.i, typename))
                      table.insert(txt, string.format('}'))
                   end
                elseif arg.default then
                   -- we would have to deallocate the beast later if we did a new
                   -- unlikely anyways, so i do not support it for now
                   if type(arg.default) == 'boolean' then
                      error('a tensor cannot be optional if not returned')
                   end
                elseif arg.returned then
                   table.insert(txt, string.format('lua_pushvalue(L, arg%d_idx);', arg.i))
                end
                return table.concat(txt, '\n')
             end,
   
   postcall = function(arg)
                 local txt = {}
                 if arg.creturned then
                    -- this next line is actually debatable
                    table.insert(txt, string.format('TH%s_retain(arg%d);', typename, arg.i))
                    table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.%s");', arg.i, typename))
                 end
                 return table.concat(txt, '\n')
              end
}

wrap.argtypes.LongArg = {

   vararg = true,

   helpname = function(arg)
               return "(LongStorage | dim1 [dim2...])"
            end,

   declare = function(arg)
              return string.format("THLongStorage *arg%d = NULL;", arg.i)
           end,

   init = function(arg)
             if arg.default then
                error('LongArg cannot have a default value')
             end
          end,
   
   check = function(arg, idx)
            return string.format("torch_islongargs(L, %d)", idx)
         end,

   read = function(arg, idx)
             return string.format("arg%d = torch_checklongargs(L, %d);", arg.i, idx)
          end,
   
   carg = function(arg, idx)
             return string.format('arg%d', arg.i)
          end,

   creturn = function(arg, idx)
                return string.format('arg%d', arg.i)
             end,
   
   precall = function(arg)
                local txt = {}
                if arg.returned then
                   table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.LongStorage");', arg.i))
                end
                return table.concat(txt, '\n')
             end,

   postcall = function(arg)
                 local txt = {}
                 if arg.creturned then
                    -- this next line is actually debatable
                    table.insert(txt, string.format('THLongStorage_retain(arg%d);', arg.i))
                    table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.LongStorage");', arg.i))
                 end
                 if not arg.returned and not arg.creturned then
                    table.insert(txt, string.format('THLongStorage_free(arg%d);', arg.i))
                 end
                 return table.concat(txt, '\n')
              end   
}

function interface.luaname2wrapname(self, name)
   return string.format('cutorch_CudaTensor_%s', name)
end

local function cname(name)
   return string.format('THCudaTensor_%s', name)
end

local function lastdim(argn)
   return function(arg)
             return string.format("THCudaTensor_nDimension(%s)", arg.args[argn]:carg())
          end
end

interface:wrap("zero",
               cname("zero"),
               {{name="CudaTensor", returned=true}})

interface:wrap("fill",
               cname("fill"),
               {{name="CudaTensor", returned=true},
                {name="float"}})

interface:wrap("add",
               cname("add"),
               {{name="CudaTensor",returned=true},
                {name="float"}},
               cname("cadd"),
               {{name="CudaTensor", returned=true},
                {name="float", default=1},
                {name="CudaTensor"}},
               cname("cadd_tst"),
               {{name="CudaTensor", returned=true},
                {name="CudaTensor"},
                {name="float", default=1},
                {name="CudaTensor"}})

interface:wrap("mul",
               cname("mul"),
               {{name="CudaTensor", returned=true},
                {name="float"}})

interface:wrap("div",
               cname("div"),
               {{name="CudaTensor", returned=true},
                {name="float"}})

interface:wrap("cmul",
               cname("cmul"),
               {{name="CudaTensor", returned=true},
                {name="CudaTensor", default=1},
                {name="CudaTensor"}})

interface:wrap("cdiv",
               cname("cdiv"),
               {{name="CudaTensor", returned=true},
                {name="CudaTensor"}})

interface:wrap("addcmul",
                  cname("addcmul"),
                  {{name="CudaTensor", returned=true},
                   {name="float", default=1},
                   {name="CudaTensor"},
                   {name="CudaTensor"}})

interface:wrap("addcdiv",
               cname("addcdiv"),
               {{name="CudaTensor", returned=true},
                {name="float", default=1},
                {name="CudaTensor"},
                {name="CudaTensor"}})

interface:wrap("dot",
               cname("dot"),
               {{name="CudaTensor"},
                {name="CudaTensor"},
                {name="float", creturned=true}})

for _,name in ipairs({"min", "max"}) do
   interface:wrap(name,
                  cname(name .. "all"),
                  {{name="CudaTensor"},            
                   {name="float", creturned=true}})
end


interface:wrap("sum",
              cname("sum" .. "all"),
              {{name="CudaTensor"},
               {name="float", creturned=true}},
              cname("sum"),
              {{name="CudaTensor", returned=true},
               {name="CudaTensor"},
               {name="index"}})


for _,name in ipairs({"addmv", "addmm"}) do
   interface:wrap(name,
                  cname(name),
                  {{name="CudaTensor", returned=true},
                   {name="float", default=1, invisible=true}, -- ambiguity
                   {name="float", default=1},
                   {name="CudaTensor"},
                   {name="CudaTensor"}},
                  cname(name),
                  {{name="CudaTensor", returned=true},
                   {name="float"}, -- ambiguity
                   {name="float"},
                   {name="CudaTensor"},
                   {name="CudaTensor"}})
end

interface:wrap("addr",
               cname("addr"),
               {{name="CudaTensor", returned=true},
                {name="float", default=1},
                {name="CudaTensor"},
                {name="CudaTensor"}})

for _,name in ipairs({"log", "log1p", "exp",
                      "cos", "acos", "cosh",
                      "sin", "asin", "sinh",
                      "tan", "atan", "tanh",
                      "sqrt",
                      "ceil", "floor",
                      "abs"}) do
   
   interface:wrap(name,
                  cname(name),
                  {{name="CudaTensor", returned=true}})
   
end

interface:wrap("pow",
               cname("pow"),
               {{name="CudaTensor", returned=true},
                {name="float"}})

interface:wrap('random',
               'THCRandom_random2',
               {{name='long'},
                {name='long'},
                {name='long', creturned=true}},
               'THCRandom_random1',
               {{name='long'},
                {name='long', creturned=true}},
               'THCRandom_random',
               {{name='long', creturned=true}},
               cname("random2"),
               {{name="CudaTensor", returned=true},
                {name='long'},
                {name='long'}},
               cname("random1"),
               {{name="CudaTensor", returned=true},
                {name='long'}},
               cname("random"),
               {{name="CudaTensor", returned=true}})

interface:wrap("rand",
               cname("rand"),
               {{name="CudaTensor", default=true, returned=true, method={default='nil'}},
                {name="LongArg"}})

interface:wrap("randn",
               cname("randn"),
               {{name="CudaTensor", default=true, returned=true, method={default='nil'}},
                {name="LongArg"}})

for _,f in ipairs({{name='geometric'},
                   {name='bernoulli', a=0.5}}) do
   
   interface:wrap(f.name,
                  string.format("THCRandom_%s", f.name),
                  {{name="float", default=f.a},
                   {name="float", creturned=true}},
                  cname(f.name),
                  {{name="CudaTensor", returned=true},
                   {name="float", default=f.a}})
end

for _,f in ipairs({{name='uniform', a=0, b=1},
                   {name='normal', a=0, b=1},
                   {name='cauchy', a=0, b=1},
                   {name='logNormal', a=1, b=2}}) do

   interface:wrap(f.name,
                  string.format("THCRandom_%s", f.name),
                  {{name="float", default=f.a},
                   {name="float", default=f.b},
                   {name="float", creturned=true}},
                  cname(f.name),
                  {{name="CudaTensor", returned=true},
                   {name="float", default=f.a},
                   {name="float", default=f.b}})
end

for _,f in ipairs({{name='exponential'}}) do
   
   interface:wrap(f.name,
                  string.format("THCRandom_%s", f.name),
                  {{name="float", default=f.a},
                   {name="float", creturned=true}},
                  cname(f.name),
                  {{name="CudaTensor", returned=true},
                   {name="float", default=f.a}})
end

for _,name in ipairs({"mean", "var", "std"}) do
   interface:wrap(name,
                  cname(name .. "all"),
                  {{name="CudaTensor"},
                   {name="float", creturned=true}})
end

interface:wrap("norm",
               cname("norm"),
                     {{name="CudaTensor"},
                      {name="float", default=2},
                      {name="float", creturned=true}})

interface:wrap("dist",
               cname("dist"),
               {{name="CudaTensor"},
                {name="CudaTensor"},
                {name="float", default=2},
                {name="float", creturned=true}})

interface:wrap("sign",
                cname("sign"),
                {{name="CudaTensor", returned=true},
                 {name="CudaTensor", default=1}})

interface:register("cutorch_CudaTensorMath__")

   interface:print([[
void cutorch_CudaTensorMath_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.CudaTensor");
  luaL_register(L, NULL, cutorch_CudaTensorMath__);
  lua_pop(L, 1);
}
]])

interface:tofile(arg[1])

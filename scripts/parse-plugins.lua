-- LazyVim Plugin Parser
-- This script extracts plugin specifications from LazyVim

local function serialize_table(t)
  local result = {}
  for k, v in pairs(t) do
    if type(v) == "string" then
      result[k] = v
    elseif type(v) == "boolean" then
      result[k] = v
    elseif type(v) == "number" then
      result[k] = v
    elseif type(v) == "table" then
      result[k] = serialize_table(v)
    end
  end
  return result
end

-- Function to extract plugin name from a spec
local function extract_plugin_name(spec)
  if type(spec) == "string" then
    return spec
  elseif type(spec) == "table" then
    -- Check for explicit name field
    if spec.name then
      return spec.name
    end
    -- Check for array-style spec where first element is the plugin name
    if spec[1] and type(spec[1]) == "string" then
      return spec[1]
    end
    -- Try to find URL or plugin identifier
    for k, v in pairs(spec) do
      if type(v) == "string" and (v:match("^[%w-]+/[%w.-]+$") or v:match("%.nvim$")) then
        return v
      end
    end
  end
  return nil
end

-- Parse LazyVim plugins
function ParseLazyVimPlugins(lazyvim_path, output_file, version, commit)
  -- Add LazyVim to runtime path
  vim.opt.runtimepath:append(lazyvim_path)
  
  local plugins = {}
  local seen_plugins = {}
  
  -- Function to collect plugins from a spec
  local function collect_plugins(spec, load_order)
    if type(spec) == "string" then
      if not seen_plugins[spec] then
        seen_plugins[spec] = true
        table.insert(plugins, {
          name = spec,
          loadOrder = load_order,
          dependencies = {},
          config = {}
        })
      end
    elseif type(spec) == "table" then
      -- Handle single plugin spec
      local plugin_name = extract_plugin_name(spec)
      if plugin_name and not seen_plugins[plugin_name] then
        seen_plugins[plugin_name] = true
        
        -- Extract dependencies
        local deps = {}
        if spec.dependencies then
          if type(spec.dependencies) == "string" then
            deps = {spec.dependencies}
          elseif type(spec.dependencies) == "table" then
            for _, dep in ipairs(spec.dependencies) do
              if type(dep) == "string" then
                table.insert(deps, dep)
              elseif type(dep) == "table" and dep[1] then
                table.insert(deps, dep[1])
              end
            end
          end
        end
        
        table.insert(plugins, {
          name = plugin_name,
          loadOrder = load_order,
          dependencies = deps,
          config = serialize_table(spec)
        })
      end
      
      -- Handle array of specs
      for i, v in ipairs(spec) do
        if type(v) == "table" or (type(v) == "string" and i > 1) then
          collect_plugins(v, load_order + i)
        end
      end
    end
  end
  
  -- Load LazyVim's plugin specifications
  local ok, lazyvim_plugins = pcall(function()
    -- We need to mock some lazy.nvim functions that LazyVim might use
    _G.require = function(module)
      if module == "lazy" then
        return {
          setup = function() end,
        }
      elseif module:match("^lazyvim%.plugins") then
        -- Load the actual LazyVim plugin module
        local module_path = lazyvim_path .. "/lua/" .. module:gsub("%.", "/") .. ".lua"
        local file = io.open(module_path, "r")
        if file then
          local content = file:read("*all")
          file:close()
          local chunk = loadstring(content)
          if chunk then
            return chunk()
          end
        end
      end
      return {}
    end
    
    -- Try to load the main plugins
    local plugin_files = {
      "coding",
      "colorscheme", 
      "editor",
      "formatting",
      "linting",
      "lsp",
      "treesitter",
      "ui",
      "util",
    }
    
    local all_plugins = {}
    
    -- First, add the core LazyVim plugin
    table.insert(all_plugins, "LazyVim/LazyVim")
    
    -- Load each plugin module
    for _, file in ipairs(plugin_files) do
      local module_path = lazyvim_path .. "/lua/lazyvim/plugins/" .. file .. ".lua"
      local f = io.open(module_path, "r")
      if f then
        local content = f:read("*all")
        f:close()
        
        -- Extract return statement
        local chunk = loadstring(content)
        if chunk then
          local ok, result = pcall(chunk)
          if ok and type(result) == "table" then
            for _, plugin in ipairs(result) do
              table.insert(all_plugins, plugin)
            end
          end
        end
      end
    end
    
    return all_plugins
  end)
  
  if ok and lazyvim_plugins then
    -- Collect all plugins
    collect_plugins(lazyvim_plugins, 0)
  else
    -- Fallback: manually specify core LazyVim plugins
    local core_plugins = {
      "LazyVim/LazyVim",
      "folke/lazy.nvim",
      "folke/which-key.nvim",
      "folke/tokyonight.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-treesitter/nvim-treesitter",
      "neovim/nvim-lspconfig",
      "hrsh7th/nvim-cmp",
      "L3MON4D3/LuaSnip",
      "nvim-neo-tree/neo-tree.nvim",
      "nvim-lualine/lualine.nvim",
      "akinsho/bufferline.nvim",
      "lewis6991/gitsigns.nvim",
      "folke/trouble.nvim",
      "folke/todo-comments.nvim",
      "folke/noice.nvim",
      "folke/flash.nvim",
      "echasnovski/mini.ai",
      "echasnovski/mini.pairs",
      "echasnovski/mini.surround",
      "williamboman/mason.nvim",
      "stevearc/conform.nvim",
      "mfussenegger/nvim-lint",
    }
    
    for i, plugin in ipairs(core_plugins) do
      collect_plugins(plugin, i)
    end
  end
  
  -- Create the JSON structure
  local json_data = {
    version = version,
    commit = commit,
    generated = os.date("%Y-%m-%d %H:%M:%S"),
    plugins = plugins
  }
  
  -- Convert to JSON (simple implementation)
  local function to_json(data, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local result = ""
    
    if type(data) == "table" then
      if #data > 0 then
        -- Array
        result = "[\n"
        for i, v in ipairs(data) do
          result = result .. spaces .. "  " .. to_json(v, indent + 1)
          if i < #data then
            result = result .. ","
          end
          result = result .. "\n"
        end
        result = result .. spaces .. "]"
      else
        -- Object
        result = "{\n"
        local first = true
        for k, v in pairs(data) do
          if not first then
            result = result .. ",\n"
          end
          first = false
          result = result .. spaces .. '  "' .. k .. '": ' .. to_json(v, indent + 1)
        end
        if not first then
          result = result .. "\n"
        end
        result = result .. spaces .. "}"
      end
    elseif type(data) == "string" then
      result = '"' .. data:gsub('"', '\\"') .. '"'
    elseif type(data) == "boolean" then
      result = tostring(data)
    elseif type(data) == "number" then
      result = tostring(data)
    else
      result = "null"
    end
    
    return result
  end
  
  -- Write to file
  local file = io.open(output_file, "w")
  if file then
    file:write(to_json(json_data))
    file:close()
    print("Successfully wrote plugins to " .. output_file)
  else
    error("Failed to open output file: " .. output_file)
  end
end
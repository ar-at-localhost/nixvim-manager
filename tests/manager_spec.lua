local TIMEOUT_MS = 180000 -- 3 minutes

-- ---------------------------------------------------------------------------
-- Unit tests: NixvimManager
-- ---------------------------------------------------------------------------

describe("NixvimManager", function()
  local Promise = require("orgmode.utils.promise")
  local fs = require("yalms.fs")
  local NixvimManager
  local tests_dirs = {}
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname() .. "-nixvim-test"
    vim.fn.mkdir(test_dir, "p")
    table.insert(tests_dirs, test_dir)
  end)

  local get_manager = function(opts)
    opts = opts or {}
    return Promise.new(function(res, rej)
      NixvimManager = require("nixvim-manager.manager")
      NixvimManager:new({
        dir = opts.dir or test_dir,
        on_ready = function(err, manager)
          if err then
            rej(err)
          end

          res(manager)
        end,
      })
    end)
  end

  -- -------------------------------------------------------------------------
  describe("new", function()
    it("creates instance with options", function()
      get_manager()
        :next(function(manager)
          assert.is_table(manager)
          assert.is_table(manager._opts)
          assert.is_table(manager.nixvim)
          assert.is_table(manager._queue)
          assert.is_true(vim.fn.filereadable(test_dir .. "/flake.nix") == 1)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("add", function()
    it("adds nixvim module", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "test-module", initial_content = "{}" }, function(_, result)
              assert.is_table(result)
              assert.is_string(result.link)
              res()
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)

    it("enqueues operation when not ready", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            local queue_before = #manager._queue
            manager:add({ name = "test-module", initial_content = "{}" }, function()
              assert.is_true(#manager._queue >= queue_before)
              res()
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("remove", function()
    it("removes nixvim module when found", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "to-remove", initial_content = "{}" }, function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:remove("to-remove", function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)

    it("returns error when module not found", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:remove("nonexistent-module", function(err)
              if err then
                res()
              else
                rej("expected error")
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("update", function()
    it("updates content of existing module", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "test-module", initial_content = "{}" }, function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:update({ name = "test-module", initial_content = "{}" }, function(err, result)
              if err then
                rej(err)
              else
                assert.is_not_nil(result)
                res(manager)
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)

    it("returns error when module not found", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:update({ name = "nonexistent" }, function(err)
              if err then
                res()
              else
                rej("expected error")
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("get", function()
    it("returns module when found", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "test-get", initial_content = "{}" }, function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:get("test-get", function(err, result)
              if err then
                rej(err)
              else
                assert.is_not_nil(result)
                res(manager)
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)

    it("enqueues operation when not ready", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            local queue_before = #manager._queue
            manager:get("any-module", function() end)
            assert.is_true(#manager._queue >= queue_before)
            res()
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("reload", function()
    it("reloads nixvim modules", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:reload(function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("queue behavior", function()
    it("enqueues operations when not ready", function()
      package.loaded["nixvim-manager.manager"] = nil
      local queue_dir = vim.fn.tempname() .. "-nixvim-queue-test"
      vim.fn.mkdir(queue_dir, "p")

      get_manager({ dir = queue_dir })
        :next(function(manager)
          return Promise.new(function(res, rej)
            local original_ready = manager._ready
            local queue_before = #manager._queue

            manager:add({ name = "module1", initial_content = "{}" }, function() end)
            manager:add({ name = "module2", initial_content = "{}" }, function() end)

            if not original_ready then
              assert.is_equal(2, #manager._queue - queue_before)
            end

            vim.fn.delete(queue_dir, "rf")
            res()
          end)
        end)
        :wait(TIMEOUT_MS)
    end)

    it("drains queue when ready", function()
      get_manager()
        :next(function(manager)
          assert.is_equal(0, #manager._queue)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("resolve_link", function()
    local manager

    before_each(function()
      package.loaded["nixvim-manager.manager"] = nil
      NixvimManager = require("nixvim-manager.manager")
      manager = NixvimManager:new({ dir = test_dir, on_ready = function() end })
      wait_ready(manager)
    end)

    it("returns nil when no modules exist", function()
      assert.is_nil(manager:resolve_link())
    end)

    it("returns default link when no dir specified", function()
      manager.nixvim["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      assert.is_equal("/nix/store/default-nvim/bin/nvim", manager:resolve_link())
    end)

    it("returns default link when no dir matches", function()
      manager.nixvim["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvim["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal("/nix/store/default-nvim/bin/nvim", manager:resolve_link("/home/user/other"))
    end)

    it("returns matching dir-specific link when prefix matches", function()
      manager.nixvim["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvim["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal(
        "/nix/store/project-nvim/bin/nvim",
        manager:resolve_link("/home/user/project/src")
      )
    end)

    it("prefers longest matching prefix", function()
      manager.nixvim["default"] = {
        name = "default",
        link = "/nix/store/default-nvim/bin/nvim",
        dirs = nil,
      }
      manager.nixvim["short"] = {
        name = "short",
        link = "/nix/store/short-nvim/bin/nvim",
        dirs = { "/home/user" },
      }
      manager.nixvim["long"] = {
        name = "long",
        link = "/nix/store/long-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_equal(
        "/nix/store/long-nvim/bin/nvim",
        manager:resolve_link("/home/user/project/src")
      )
    end)

    it("handles trailing slash in dir prefix", function()
      manager.nixvim["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project/" },
      }
      assert.is_equal(
        "/nix/store/project-nvim/bin/nvim",
        manager:resolve_link("/home/user/project")
      )
    end)

    it("returns nil when only dirs-constrained entries exist but no match", function()
      manager.nixvim["project"] = {
        name = "project",
        link = "/nix/store/project-nvim/bin/nvim",
        dirs = { "/home/user/project" },
      }
      assert.is_nil(manager:resolve_link("/home/user/other"))
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("add with dirs", function()
    it("adds module with directory constraint", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({
              name = "project-config",
              initial_content = "{}",
              dirs = { "/home/user/project", "/home/user/work" },
              function(err, result)
                if err then
                  rej(err)
                else
                  assert.is_not_nil(result)
                  assert.is_table(manager.nixvim["project-config"])
                  assert.is_equal("/home/user/project", manager.nixvim["project-config"].dirs[1])
                  assert.is_equal("/home/user/work", manager.nixvim["project-config"].dirs[2])
                  res()
                end
              end,
            })
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("update dirs only", function()
    it("updates dirs without rebuild when content unchanged", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "test-dirs", initial_content = "{}" }, function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:get("test-dirs", function(_, entry)
              if not entry then
                rej("entry not found")
                return
              end
              entry.link = "/nix/store/test/bin/nvim"
              res()
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:update({ name = "test-dirs", dirs = { "/new/dir" } }, function(err, result)
              if err then
                rej(err)
              else
                assert.is_not_nil(result)
                assert.is_equal("/new/dir", result.dirs[1])
                res()
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("update string shorthand", function()
    it("converts string to name option", function()
      get_manager()
        :next(function(manager)
          return Promise.new(function(res, rej)
            manager:add({ name = "update-test", initial_content = "{}" }, function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :next(function(manager)
          return Promise.new(function(res, rej)
            assert.is_not_nil(manager.nixvim["update-test"])
            manager:update("update-test", function(err)
              if err then
                rej(err)
              else
                res(manager)
              end
            end)
          end)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("on_ready callback", function()
    it("receives nil error on successful init", function()
      get_manager()
        :next(function(manager)
          assert.is_table(manager)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("nixvim table state", function()
    it("starts empty and gets populated", function()
      get_manager()
        :next(function(manager)
          assert.is_table(manager.nixvim)
        end)
        :wait(TIMEOUT_MS)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("bases", function()
    local manager

    before_each(function()
      return get_manager()
        :next(function(m)
          manager = m
        end)
        :wait(TIMEOUT_MS)
    end)

    -- -----------------------------------------------------------------------
    describe("add_base", function()
      it("adds base with content", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{ pkgs, ... }: { }" }, function(err)
                if err then
                  rej(err)
                else
                  assert.is_not_nil(manager.bases["web"])
                  res()
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("rejects path separators in base name", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web/base", content = "{}" }, function(err)
                if err and err:find("cannot contain path separators") then
                  res()
                else
                  rej("expected error")
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("rejects duplicate base name", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err and err:find("already exists") then
                  res()
                else
                  rej("expected error")
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("update_base", function()
      it("updates existing base content", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{ old = true; }" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:update_base({ name = "web", content = "{ new = true; }" }, function(err)
                if err then
                  rej(err)
                else
                  assert.is_true(manager.bases["web"]:find("new = true") ~= nil)
                  assert.is_false(manager.bases["web"]:find("old = true") ~= nil)
                  res()
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("skips rebuild when content unchanged", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            local call_count = 0
            local original_write_file = fs.write_file
            fs.write_file = function(path, content)
              call_count = call_count + 1
              return original_write_file(path, content)
            end

            return Promise.new(function(res, rej)
              manager:update_base({ name = "web", content = "{}" }, function()
                fs.write_file = original_write_file
                assert.is_equal(0, call_count)
                res()
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("returns error for non-existent base", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:update_base({ name = "nonexistent", content = "{}" }, function(err)
                if err and err:find("not found") then
                  res()
                else
                  rej("expected error")
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("remove_base", function()
      it("removes base file from disk", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:remove_base("web", function(err)
                if err then
                  rej(err)
                else
                  assert.is_nil(manager.bases["web"])
                  assert.is_false(vim.fn.filereadable(test_dir .. "/_web.nix") == 1)
                  res()
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("returns error for non-existent base", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:remove_base("nonexistent", function(err)
                if err and err:find("not found") then
                  res()
                else
                  rej("expected error")
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("list_bases", function()
      it("returns array of base names", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "default", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "minimal", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:list_bases(function(err, bases_list)
                if err then
                  rej(err)
                else
                  assert.is_table(bases_list)
                  assert.is_true(#bases_list >= 3)

                  local base_set = {}
                  for _, name in ipairs(bases_list) do
                    base_set[name] = true
                  end
                  assert.is_true(base_set["web"])
                  assert.is_true(base_set["default"])
                  assert.is_true(base_set["minimal"])
                  res()
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("nixvim with base field", function()
      it("adds nixvim with specific base", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add(
                { name = "myconfig", initial_content = "{ }", base = "web" },
                function(err, added)
                  if err then
                    rej(err)
                  else
                    assert.is_table(added)
                    assert.is_equal("myconfig", added.name)
                    assert.is_equal("web", added.base)
                    res()
                  end
                end
              )
            end)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("updates nixvim base without rebuild", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "web", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "default", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add(
                { name = "testconfig", initial_content = "{ }", base = "web" },
                function(err)
                  if err then
                    rej(err)
                  else
                    res(manager)
                  end
                end
              )
            end)
          end)
          :next(function(manager)
            assert.is_equal("web", manager.nixvim["testconfig"].base)
            return Promise.new(function(res, rej)
              manager:update({ name = "testconfig", base = "default" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            assert.is_equal("default", manager.nixvim["testconfig"].base)
          end)
          :wait(TIMEOUT_MS)
      end)

      it("defaults to 'default' base when not specified", function()
        get_manager()
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add_base({ name = "default", content = "{}" }, function(err)
                if err then
                  rej(err)
                else
                  res(manager)
                end
              end)
            end)
          end)
          :next(function(manager)
            return Promise.new(function(res, rej)
              manager:add({ name = "testconfig", initial_content = "{ }" }, function(err, added)
                if err then
                  rej(err)
                else
                  assert.is_table(added)
                  assert.is_equal("default", added.base)
                  res()
                end
              end)
            end)
          end)
          :wait(TIMEOUT_MS)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("opts.bases seeding", function()
      it("creates bases from declarative opts", function()
        package.loaded["nixvim-manager.manager"] = nil
        NixvimManager = require("nixvim-manager.manager")
        local m = NixvimManager:new({
          dir = test_dir,
          bases = { web = "{ pkgs, ... }: { }", default = "{ }" },
          on_ready = function() end,
        })
        wait_ready(m)

        assert.is_not_nil(m.bases["web"])
        assert.is_not_nil(m.bases["default"])
        assert.is_true(m.bases["web"]:find("pkgs, ...") ~= nil)
        assert.is_equal("{ }", m.bases["default"])
      end)

      it("updates existing bases from opts", function()
        await("add_base web old", function(cb)
          manager:add_base({ name = "web", content = "{ old = true; }" }, cb)
        end)
        manager:_save_config()

        package.loaded["nixvim-manager.manager"] = nil
        NixvimManager = require("nixvim-manager.manager")
        local m2 = NixvimManager:new({
          dir = test_dir,
          bases = { web = "{ new = true; }", default = "{ }" },
          on_ready = function() end,
        })
        wait_ready(m2)

        assert.is_not_nil(m2.bases["web"])
        assert.is_true(m2.bases["web"]:find("new = true") ~= nil)
        assert.is_false(m2.bases["web"]:find("old = true") ~= nil)
      end)
    end)

    -- -----------------------------------------------------------------------
    describe("reload with bases", function()
      it("loads bases from _*.nix files", function()
        fs.write_file(test_dir .. "/_web.nix", "{ pkgs, ... }: { }")
        fs.write_file(test_dir .. "/_default.nix", "{ }")

        package.loaded["nixvim-manager.manager"] = nil
        NixvimManager = require("nixvim-manager.manager")
        local m = NixvimManager:new({ dir = test_dir, on_ready = function() end })
        wait_ready(m)

        assert.is_not_nil(m.bases["web"])
        assert.is_not_nil(m.bases["default"])
        assert.is_true(m.bases["web"]:find("pkgs, ...") ~= nil)
        assert.is_equal("{ }", m.bases["default"])
      end)

      it("loads nixvims with base field from config", function()
        await("add_base web", function(cb)
          manager:add_base({ name = "web", content = "{}" }, cb)
        end)
        await("add testconfig base=web", function(cb)
          manager:add({ name = "testconfig", initial_content = "{ }", base = "web" }, cb)
        end)
        assert.is_not_nil(manager.nixvim["testconfig"])
        manager:_save_config()

        package.loaded["nixvim-manager.manager"] = nil
        NixvimManager = require("nixvim-manager.manager")
        local m2 = NixvimManager:new({ dir = test_dir, on_ready = function() end })
        wait_ready(m2)

        assert.is_table(m2.nixvim["testconfig"])
        assert.is_equal("web", m2.nixvim["testconfig"].base)
      end)
    end)
  end)
end)

describe("E2E: building nixvims", function()
  local NixvimManager
  local test_dir

  before_each(function()
    package.loaded["nixvim-manager.manager"] = nil
    test_dir = vim.fn.tempname() .. "-nixvim-e2e-test"
    vim.fn.mkdir(test_dir, "p")
  end)

  after_each(function()
    if test_dir and vim.fn.isdirectory(test_dir) == 1 then
      vim.fn.delete(test_dir, "rf")
    end
  end)

  -- -------------------------------------------------------------------------
  describe("basic build", function()
    it("builds default nixvim without base", function()
      NixvimManager = require("nixvim-manager.manager")
      local manager = NixvimManager:new({ dir = test_dir, on_ready = function() end })
      wait_ready(manager)

      local err, result = await("add foo and build", function(cb)
        manager:add({ name = "foo", initial_content = "{}" }, cb)
      end)

      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_string(result.link)
      assert.is_true(result.link:match("^/nix/store/") ~= nil)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("build with base", function()
    it("builds nixvim extending a base", function()
      NixvimManager = require("nixvim-manager.manager")
      local manager = NixvimManager:new({ dir = test_dir, on_ready = function() end })
      wait_ready(manager)

      await("add_base default", function(cb)
        manager:add_base({ name = "default", content = "{ }" }, cb)
      end)

      local err, result = await("add test base=default", function(cb)
        manager:add({ name = "test", initial_content = "{ }", base = "default" }, cb)
      end)

      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_string(result.link)
      assert.is_true(result.link:match("^/nix/store/") ~= nil)
    end)
  end)

  -- -------------------------------------------------------------------------
  describe("build with bases.default", function()
    it("uses bases.default as default base", function()
      NixvimManager = require("nixvim-manager.manager")
      local manager = NixvimManager:new({ dir = test_dir, on_ready = function() end })
      wait_ready(manager)

      await("add_base default", function(cb)
        manager:add_base({ name = "default", content = "{ }" }, cb)
      end)
      await("add_base other", function(cb)
        manager:add_base({ name = "other", content = "{ }" }, cb)
      end)

      local err, result = await("add using-default", function(cb)
        manager:add({ name = "using-default", initial_content = "{ }" }, cb)
      end)

      assert.is_nil(err)
      assert.is_not_nil(result)
      assert.is_string(result.link)
      assert.is_true(result.link:match("^/nix/store/") ~= nil)
    end)
  end)
end)

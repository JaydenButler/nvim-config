-- ~/.config/nvim/lua/plugins/dap-rust.lua
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mason-org/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -----------------------------------------------------------------------
      -- Helper: figure out Rust executable path automatically
      -----------------------------------------------------------------------
      local function get_rust_executable()
        -- e.g. /home/jayden/projects/rlparser -> "rlparser"
        local cwd = vim.fn.getcwd()
        local crate_name = vim.fn.fnamemodify(cwd, ":t")
        local exe = cwd .. "/target/debug/" .. crate_name
        return exe
      end

      -----------------------------------------------------------------------
      -- Mason + codelldb setup
      -----------------------------------------------------------------------
      require("mason-nvim-dap").setup({
        ensure_installed = { "codelldb" },
        automatic_installation = true,
      })

      local codelldb_path = vim.fn.stdpath("data") .. "/mason/bin/codelldb"

      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = codelldb_path,
          args = { "--port", "${port}" },
        },
      }

      -----------------------------------------------------------------------
      -- Rust debug configuration (no prompt)
      -----------------------------------------------------------------------
      dap.configurations.rust = {
        {
          name = "Debug current crate",
          type = "codelldb",
          request = "launch",
          program = get_rust_executable, -- <-- no input(), just compute the path
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          sourceLanguages = { "rust" },
        },
      }

      -----------------------------------------------------------------------
      -- DAP UI setup & auto-open/close
      -----------------------------------------------------------------------
      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -----------------------------------------------------------------------
      -- Keymaps
      -----------------------------------------------------------------------
      local map = vim.keymap.set

      -- F5: cargo build + *always* run "Debug current crate"
      map("n", "<F5>", function()
        local cwd = vim.fn.getcwd()
        local rust_cfg = dap.configurations.rust and dap.configurations.rust[1]
        if not rust_cfg then
          vim.notify("No Rust DAP configuration found", vim.log.levels.ERROR)
          return
        end

        print("Building (cargo build)...")
        vim.fn.jobstart("cargo build", {
          cwd = cwd,
          stdout_buffered = true,
          stderr_buffered = true,
          on_exit = function(_, code)
            vim.schedule(function()
              if code == 0 then
                print("Build succeeded, starting debugger...")
                -- explicitly run the first Rust config instead of dap.continue()
                dap.run(vim.deepcopy(rust_cfg))
              else
                vim.notify("cargo build failed (" .. code .. ")", vim.log.levels.ERROR)
              end
            end)
          end,
        })
      end, { desc = "DAP: Build & Debug (F5)" })

      map("n", "<F10>", function()
        dap.step_over()
      end, { desc = "DAP: Step Over (F10)" })

      map("n", "<F11>", function()
        dap.step_into()
      end, { desc = "DAP: Step Into (F11)" })

      map("n", "<F12>", function()
        dap.step_out()
      end, { desc = "DAP: Step Out (F12)" })

      map("n", "<leader>b", function()
        dap.toggle_breakpoint()
      end, { desc = "DAP: Toggle Breakpoint" })

      map("n", "<leader>du", function()
        dapui.toggle()
      end, { desc = "Toggle DAP UI" })

      map("n", "<F4>", function()
        dap.terminate()
        pcall(function()
          dapui.close()
        end)
        print("Debugging stopped.")
      end, { desc = "Stop (F4)" })

      map("n", "<F6>", function()
        local d = require("dap")
        if d.session() then
          d.restart()
        else
          d.continue()
        end
      end, { desc = "Restart/Continue (F6)" })
    end,
  },
}

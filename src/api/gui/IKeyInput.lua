local IInputHandler = require("api.gui.IInputHandler")
assert(type(IInputHandler) == "table")

return interface("IKeyInput",
                 {
                    receive_key = "function",
                    run_key_action = "function",
                    bind_keys = "function",
                    unbind_keys = "function",
                 },
                 IInputHandler)

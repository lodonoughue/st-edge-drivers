local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local defaults = require "st.zigbee.defaults"
local ZigbeeDriver = require "st.zigbee"
local common = require "common"

local PowerConfig = clusters.PowerConfiguration
local BatteryPerc = PowerConfig.attributes.BatteryPercentageRemaining

local COMPONENT_BY_ENDPOINT = {
  [0x01] = "button1",
  [0x02] = "button2",
}

local BUTTON_VALUES = { "pushed" }

local function init_handler(self, device)
  common.init_endpoints(self, device, COMPONENT_BY_ENDPOINT)
end

local function configure_handler(self, device)
  common.configure_battery_reporting(self, device)
  common.configure_endpoints(self, device, common.IKEA_CLUSTER_ID, COMPONENT_BY_ENDPOINT)
end

local function added_handler(self, device)
  common.emit_button_configuration(self, device, BUTTON_VALUES)
  common.emit_battery_perc(self, device)
end

local function driver_switched_handler(self, device)
  common.emit_button_configuration(self, device, BUTTON_VALUES)
end

local template = {
  NAME = "IKEA SOMRIG Shortcut Button (Single)",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
  },
  lifecycle_handlers = {
    init = init_handler,
    doConfigure = configure_handler,
    added = added_handler,
    driverSwitched = driver_switched_handler,
  },
  zigbee_handlers = {
    attr = {
      [PowerConfig.ID] = {
        [BatteryPerc.ID] = common.handle_battery_perc(),
      }
    },
    cluster = {
      [common.IKEA_CLUSTER_ID] = {
        [0x01] = common.handle_button_pushed(),
      },
    }
  },
  can_handle = common.can_handle("IKEA of Sweden", "SOMRIG shortcut button"),
}

defaults.register_for_default_handlers(template, template.supported_capabilities)
local driver = ZigbeeDriver("ikea-somrig-shortcut-button-single", template)
driver:run()

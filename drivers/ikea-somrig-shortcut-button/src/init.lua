local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local defaults = require "st.zigbee.defaults"
local device_mgmt = require "st.zigbee.device_management"
local utils = require 'st.utils'
local ZigbeeDriver = require "st.zigbee"

local PowerConfig = clusters.PowerConfiguration
local BatteryPerc = PowerConfig.attributes.BatteryPercentageRemaining

local IKEA_CLUSTER_ID = 0xFC80
local ENDPOINT_TO_COMPONENT_MAP = {
  [0x01] = "button1",
  [0x02] = "button2",
}

local function init_handler(_, device)
  device:set_endpoint_to_component_fn(function(_, endpoint)
    local component = ENDPOINT_TO_COMPONENT_MAP[endpoint]
    if component ~= nil then
      return component
    else
      return "main"
    end
  end)
end

local function configure_handler(self, device)
  local hub_eui = self.environment_info.hub_zigbee_eui

  device:send(device_mgmt.build_bind_request(
    device, PowerConfig.ID, hub_eui, 0x01))
  device:send(BatteryPerc:configure_reporting(device, 30, 21600, 1))

  for endpoint, _ in pairs(ENDPOINT_TO_COMPONENT_MAP) do
    device:send(device_mgmt.build_bind_request(
      device, IKEA_CLUSTER_ID, hub_eui, endpoint))
  end
end

local function added_handler(_, device)
  local visibility = { visibility = { displayed = false } }
  local button_values = { "pushed", "double", "held" }
  local buttons_per_component = { value = 1 }

  for _, component in pairs(device.profile.components) do
    if device:supports_capability(capabilities.button, component.id) then
      device:emit_component_event(component,
        capabilities.button.supportedButtonValues(button_values, visibility))
      device:emit_component_event(component,
        capabilities.button.numberOfButtons(buttons_per_component, visibility))
      device:emit_component_event(component,
        capabilities.button.button.pushed({state_change = false}))
    end

    if device:supports_capability(capabilities.battery, component.id) then
      device:send(BatteryPerc:read(device))
    end
  end
end

local function can_handle(_, _, device, ...)
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  return manufacturer == "IKEA of Sweden" and model == "SOMRIG shortcut button"
end

local function battery_perc_handler(_, device, value)
  local battery_perc = utils.clamp_value(value.value, 0, 100)
  device:emit_event(capabilities.battery.battery(battery_perc))
end

local function button_handler(pressed_type)
  return function(_, device, zb_rx)
    local endpoint = zb_rx.address_header.src_endpoint.value
    local event = pressed_type({state_change = true})
    device:emit_event_for_endpoint(endpoint, event)
  end
end

local template = {
  NAME = "IKEA SOMRIG Shortcut Button",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
  },
  lifecycle_handlers = {
    init = init_handler,
    doConfigure = configure_handler,
    added = added_handler,
  },
  zigbee_handlers = {
    attr = {
      [PowerConfig.ID] = {
        [BatteryPerc.ID] = battery_perc_handler
      }
    },
    cluster = {
      [IKEA_CLUSTER_ID] = {
        [0x02] = button_handler(capabilities.button.button.held),
        [0x03] = button_handler(capabilities.button.button.pushed),
        [0x06] = button_handler(capabilities.button.button.double),
      },
    }
  },
  can_handle = can_handle,
}

defaults.register_for_default_handlers(template, template.supported_capabilities)
local driver = ZigbeeDriver("ikea-somrig-shortcut-button", template)
driver:run()

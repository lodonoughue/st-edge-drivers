local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local device_mgmt = require "st.zigbee.device_management"
local utils = require 'st.utils'

local PowerConfig = clusters.PowerConfiguration
local BatteryPerc = PowerConfig.attributes.BatteryPercentageRemaining

local function handle_button_event(pressed_type)
  return function(_, device, zb_rx)
    local endpoint = zb_rx.address_header.src_endpoint.value
    local event = pressed_type({state_change = true})
    device:emit_event_for_endpoint(endpoint, event)
  end
end

local common = {}

common.IKEA_CLUSTER_ID = 0xFC80

common.init_endpoints = function(_, device, component_by_endpoint)
  device:set_endpoint_to_component_fn(function(_, endpoint)
    local component = component_by_endpoint[endpoint]
    if component ~= nil then
      return component
    else
      return "main"
    end
  end)
end

common.configure_battery_reporting = function(self, device)
  local hub_eui = self.environment_info.hub_zigbee_eui
  device:send(device_mgmt.build_bind_request(device, PowerConfig.ID, hub_eui, 0x01))
  device:send(BatteryPerc:configure_reporting(device, 30, 21600, 1))
end

common.configure_endpoints = function(self, device, cluster_id, component_by_endpoint)
  local hub_eui = self.environment_info.hub_zigbee_eui
  for endpoint, _ in pairs(component_by_endpoint) do
    device:send(device_mgmt.build_bind_request(device, cluster_id, hub_eui, endpoint))
  end
end

common.can_handle = function(manufacturer, model)
  return function(_, _, device, ...)
    local device_manufacturer = device:get_manufacturer()
    local device_model = device:get_model()
    return manufacturer == device_manufacturer and model == device_model
  end
end

common.handle_battery_perc = function()
  return function(_, device, value)
    local battery_perc = utils.clamp_value(value.value, 0, 100)
    device:emit_event(capabilities.battery.battery(battery_perc))
  end
end

common.emit_battery_perc = function(_, device)
  for _, component in pairs(device.profile.components) do
    if device:supports_capability(capabilities.battery, component.id) then
      device:send(BatteryPerc:read(device))
    end
  end
end

common.emit_button_configuration = function(_, device, button_values)
  local visibility = { visibility = { displayed = false } }
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
  end
end

common.handle_button_held = function()
  return handle_button_event(capabilities.button.button.held)
end

common.handle_button_pushed = function()
  return handle_button_event(capabilities.button.button.pushed)
end

common.handle_button_double = function()
  return handle_button_event(capabilities.button.button.double)
end

return common

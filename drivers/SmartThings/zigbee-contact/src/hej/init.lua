local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local IASZone = clusters.IASZone


-- Periodic timer interval
local INTERVAL = 120


-- Hej Contact Sensor (https://www.hej.life/shop-sensor/?idx=25)
local FINGERPRINTS = {
  { mfr = "TUYATEC-ktge2vqt", model = "RH3001" },
  { mfr = "TUYATEC-nznq0233", model = "RH3001" }
}


local is_hej_products = function(opts, driver, device, ...)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
      return true
    end
  end
  return false
end


-- Don't monitoring ZoneStatus.
local function do_init(self, device)
  print("[*] init")
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  print("[+] Device ID : ", device)
  print("[+] Manufacturer : ", manufacturer)
  print("[+] Model : ", model)

  device:remove_configured_attribute(IASZone.ID, IASZone.attributes.ZoneStatus.ID)
  device:remove_monitored_attribute(IASZone.ID, IASZone.attributes.ZoneStatus.ID)
  device:configure()
end


-- Hej Contact Sensor doesn't report current status during pairing process.
-- So fake event is needed for default status.
local function do_added(self, device)
  print("[*] added")
  device:refresh()

  local latest_state = device:get_latest_state("main", capabilities.contactSensor.ID, capabilities.contactSensor.contact.NAME)
  print("[+] Latest state : ", latest_state)
  if latest_state == "open" then
    device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.open())
  else
    device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.closed())
  end

  local remaining_battery = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.battery.NAME)
  print("[+] Remaining battery : ", remaining_battery)
  if remaining_battery == nil then
    device:emit_event_for_endpoint("main", capabilities.battery.battery(100))
  else
    device:emit_event_for_endpoint("main", capabilities.battery.battery(remaining_battery))
  end
end


-- Hej Contact Sensor doesn't report current status regularly.
local function do_infoChanged(self, device)
  print("[*] infoChanged")
  for timer in pairs(device.thread.timers) do
    print("[-] Cancel all timer")
    device.thread:cancel_timer(timer)
  end
  device.thread:call_on_schedule(
    INTERVAL,
    function ()
      local latest_state = device:get_latest_state("main", capabilities.contactSensor.ID, capabilities.contactSensor.contact.NAME)
      print("[+] Latest state : ", latest_state)
      if latest_state == "open" then
        device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.open())
      else
        device:emit_event_for_endpoint("main", capabilities.contactSensor.contact.closed())
      end
      local remaining_battery = device:get_latest_state("main", capabilities.battery.ID, capabilities.battery.battery.NAME)
      print("[+] Remaining battery : ", remaining_battery)
      if remaining_battery == nil then
        device:emit_event_for_endpoint("main", capabilities.battery.battery(100))
      else
        device:emit_event_for_endpoint("main", capabilities.battery.battery(remaining_battery))
      end
    end
    , 'Refresh state')
end


local hej_contact_handler = {
  NAME = "Hej Contact Handler",
  lifecycle_handlers = {
    init = do_init,
    added = do_added,
    infoChanged = do_infoChanged
  },
  can_handle = is_hej_products
}


return hej_contact_handler
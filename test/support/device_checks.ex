defmodule DeviceChecks do
  @moduledoc false

  import Spek.Macros

  defcheck device_online(device, reason: :device_offline) do
    device.online?
  end

  defcheck battery_above_20(device, reason: :battery_too_low) do
    device.battery_level > 20
  end

  defcheck charging(device) do
    device.charging?
  end

  defcheck low_power_mode_enabled(device) do
    device.low_power_mode?
  end
end

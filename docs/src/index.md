# HTLogger Documentation

This is a package for logging temperature and humidity data from a compatible
device.

## Installation
From the Julia REPL:
```julia
julia>]
pkg> add https://github.com/MLackner/HTLogger
```

## Usage
From the Julia REPL:
```julia
julia> using THLogger
julia> THLogger.run()
```

This will automatically search for correct device and start logging in a `log/`
folder that will be created in the current directory if it doesn't exist yet.

For more customization options refer to the documentation of `THLogger.run`.

## Compatible Devices
The communication happens via the serial port. The device has to implement the
following communication patterns:

* `"i\n"` should return the logger's identity as `"thlogger\n"`
* `"m\n"` should return the humidity and temperature raw data as for example
  `"5405,3868\n"`. (The first value is the humidity raw data and the second
  value is the temperature raw data). 

Functions for converting the raw data to actual values are provided in this
package.

The code in github.com/MLackner/Arduino-HYT939 runs on an Arduino Uno with an HYT939
Temperature/Humidity sensor. More information about the HYT939 sensor is
available in this
[datasheet](https://asset.re-in.de/add/160267/c1/-/en/000505678ML01/AN_IST-AG-Evaluations-Kit-1-St.-LabKit-HYT-Messbereich-0-100-rF.pdf).

## Functions

```@docs
HTLogger.run()
HTLogger.convert_humidity(H_raw)
HTLogger.convert_temperature(T_raw)
```

## Index

```@index
```
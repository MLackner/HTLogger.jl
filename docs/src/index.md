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

* `\I\n` should return the logger's identity as `thlogger\r\n`
* `\T\n` should return the temperature as for example `23.21\r\n`
* `\H\n` should return the humidity as for example `50.21\r\n`

The code in >this repository< runs on an Arduino Uno with an HYT939
Temperature/Humidity sensor.

## Functions

```@docs
HTLogger.run()
```

## Index

```@index
```
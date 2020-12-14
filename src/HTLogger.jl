module HTLogger

using SerialPorts
using Dates

struct TimeoutError <: Exception end

"""
    run(;path="log", baudrate=9600, port="", interval=5, lines_per_file=135_000, debug=false)

Starts logging the temperature and humidity data from the connected device.

# Keyword Arguments

* `path`: the path where the `.log` files are stored. If the path does not
  exist, it is created.

* `baudrate`: the baudrate the device is configured to

* `port`: the serial port the device is connected to. If `port` is an empty
  string, the program will try to find the device automatically.

* `interval`: the time between the individual measurements in seconds. It is
  implemented in such a way that the main measurement loop is idle for the
  `interval` time. This means that the individual measurements are more than
  `interval` seconds apart because additional time is spent reading the data
  from the device and writing to the file.

* `lines_per_file=135_000`: number of lines in a log file until a new file is
  created. 1MB roughly corresponds to 28,000 entries.

* `debug`: prints messages that help to debug in case there are problems
"""
function run(;path="log", baudrate=9600, port="",interval=5,lines_per_file = 135_000,debug=false)
    # In case an error occurs we will rerun the program recursively indefinetly
    # until the program is interrupted. Collect the keyword arguments that get
    # passed to the run function recursively. Do not specify the port in the
    # rerun because the logger port could have been changed.
    kwargs = (
        path=path, 
        baudrate=baudrate, 
        interval=interval, 
        lines_per_file=lines_per_file, 
        debug=debug
    )

    # define the serial port as a constant reference so it is visible in all
    # try-catch blocks
    local s = Ref{SerialPort}()

    try
        # if no port is supplied search automatically
        if port == ""
            port = find_port(; debug, baudrate)
        end

        # connect to the device
        s[] = SerialPort(port, baudrate)

        # wait for board to be ready
        sleep(3)
    catch err
        if err isa InterruptException
            # in case the user interrupts the program
            println("Terminated by user while trying to connect to logging device.")

            return nothing
        else
            # if no port can be found or any other error occurs we will try running again
            @warn "Could not find the device on any port. Make sure it is connected.\nTrying again..."
            sleep(5)
            run(; kwargs...)
        end
    end

    # create a file / get the file to write to
    filepath, nlines = logfile_handling(path, lines_per_file)

    try
        while true
            t = string(Dates.now())
            T = read_temperature(s[])
            H = read_rel_humidity(s[])

            open(filepath, "a") do io
                newline = "$t\t$T\t$H\n"
                write(io, newline)
            end

            nlines += 1
            if nlines >= lines_per_file
                filepath, nlines = logfile_handling(path, lines_per_file)
            end

            sleep(interval)
            
        end
    catch err
        if err isa InterruptException
            println("Logging terminated by user")
        else
            @warn "A $err occured. Trying to start over..."
            close(s[])
            # do not specify the port! If the device is disconnected 
            run(; kwargs...)
        end
    finally
        # close the serial port
        close(s[])
    end

    nothing
end

function logfile_handling(path, lines_per_file)
    if !isdir(path)
        mkpath(path)
        println("""
        Did not find the specified path at $path, so I
        created that for you!\n
        """)
    end

    filepath = get_logfile_for_writing(path, lines_per_file)
end

function get_logfile_for_writing(path, lines_per_file)::Tuple{String,Int}
    # lines_per_file has to be greater than 0. Otherwise we'll be
    # stuck generating empty files
    lines_per_file > 0 || error("Number of lines per file has to be > 0.")

    files = readdir(path)
    filter!(x -> occursin(".log", x), files)
    sort!(files)

    if length(files) > 0
        println("Did find $(length(files)) logfiles")
        
        file = last(files)
        filepath = joinpath(path, file)
        nlines = get_num_lines(filepath)

        if nlines < lines_per_file
            println("Found logfile $file with $nlines lines. Writing to that.")
            return (filepath, nlines)
        else
            # Found a logfile but it already has more than the maximum
            # allowed number of lines
            println("""Found logfile $file but it already has $nlines lines.
            The maximum number of lines is set to $lines_per_file.\n""")
        end
    else
        println("Did not find a log file at $path.")
    end
    filename = generate_logfile_name()
    filepath = joinpath(path, filename)
    touch(filepath)

    filepath, 0
end

function generate_logfile_name(prefix="hty939", ext=".log")
    datestring = splitext( string(now()) )[1]
    datestring = replace(datestring, ':' => '_')
    prefix * "_" * datestring * ext
end

function get_num_lines(filepath)::Int
    # open file / read as byte array / close file
    f = open(filepath, "r")
    str = read(f)
    close(f)

    nrows = 0
    for byte in str
        # check for newline (\n)
        byte == 0x0a && (nrows += 1)
    end
    nrows
end

function read_line(s; timeout=10)
    readbuffer = IOBuffer()
    t_start = time()
    byte    = ""
    while byte ≠ "\n"
        t = time()
        if bytesavailable(s) > 0
            byte = read(s, 1)
            write(readbuffer, byte)
        end
        if t - t_start > timeout
            throw(TimeoutError)
        end
    end

    String(take!(readbuffer))
end

function query(s, msg; timeout=2)
    write(s, msg)
    read_line(s; timeout=timeout)
end

function read_temperature(s)
    readavailable(s)
    readbuffer = query(s, "T\n")
    parse(Float64, readbuffer)
end

function read_rel_humidity(s)
    readavailable(s)
    readbuffer = query(s, "H\n")
    parse(Float64, readbuffer)
end

function find_port(;debug=false, baudrate=9600)
    # get a list with all available serial ports
    ports = SerialPorts.list_serialports()

    print("Searching for logger...")

    for p in ports
        print(".")

        try # try to connect to each port in the list
            s = SerialPort(p, baudrate)
            debug && println("$p is open")

            # wait for the device to initialize
            sleep(2.0)

            try # try to write and read from the port
                # clear everything that is in the buffer
                readavailable(s)
                readbuffer = query(s, "I\n")
                debug && println("Got '$readbuffer' from $p")

                # If we successfully identified the logger close the connection
                # and return the port. Otherwise continue with the next port in
                # the list.
                if readbuffer == "htlogger\r\n"
                    println("Found the logger on port $p")
                    close(s)
                    return p
                else
                    debug && println("Could read from $p but got wrong identifier.")
                end
            catch # write / read failed
                debug && println("Could not write to port $p")
            finally
                close(s)
            end
        catch # connection failed
            debug && println("Could not open port $p")
        end
    end
    
    # make a new line
    println()

    error("Could not find logger.")
end

end

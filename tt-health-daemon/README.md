# tt-health-daemon

## About

tt-health-daemon captures a snapshot of attributes exposed by tt-kmd, which can be updated and queried through a unix socket.

## Big questions right now

- Is this something like what we want or am I completely off the mark?
- How do I further interpret the pcie_perf_counters? Is there something useful I can do with them?
    - Add counter rollover logic?
- Do we really want to use unix sockets, do we want to write to files, or something else? How can we best make use of unix sockets and expose everything properly?
    - For now we just have one socket and we dump a bunch of text to it when we open a connection to it, I definitely don't think we should keep this.
- Do we want to be performing reads per-metric or update all metrics at once?
    - I was thinking update all metrics at once and associate them all with a timestamp
- Should there be a metric update loop in the application or should updates be on-demand?
    - I was thinking on-demand
- Should there be a metric type split up into name and value? Might make it easier with some of the messy filename stuff (clean up the device module side of it)

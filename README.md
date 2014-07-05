check_promise_vtrak
===================

Nagios plugin to monitor a Promise Vtrak

Please go to http://www.claudiokuenzler.com/nagios-plugins/check_promise_vtrak.php for up to date documentation.


Usage
-----
    ./check_promise_vtrak.pl -H host [-p port] [-C community] -m model -t checktype
    

Examples
--------
    # General information: 
    ./check_promise_vtrak.pl -H myvtrak -C public -m E310s -t info
    Promise Technology,Inc. VTrak E610s - S/N: RCXXXXXXXXX - Firmware: 3.36.0000.02 - Uptime: 76 days, 04:59:49.17

    # Disk check:
    ./check_promise_vtrak.pl -H myvtrak -C public -m E310s -t disk
    DISK WARNING - 1 DISK WARNINGS ( 1 disk(s) unconfigured )

    # Enclosure check:
    ./check_promise_vtrak.pl -H myvtrak -C public -m E310s -t enclosure
    ENCLOSURE OK - 1 enclosure(s) attached
    
    # Power supplies check:
    ./check_promise_vtrak.pl -H myvtrak -C public -m E310s -t ps
    POWER SUPPLY OK - 2 power supplies attached


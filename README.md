Generic PMDA
============

This PMDA is a **temporary hack** to support CPU [Flame Graphs](http://www.brendangregg.com/FlameGraphs/cpuflamegraphs.html) and Disk Latency Heat Maps on [Vector](https://github.com/Netflix/vector). This solution is far from ideal and **will be deprecated** once the the widgets and PMDAs are ready. Two issues are being used to track the development of the new solution:

* [github.com/Netflix/vector/issues/7](https://github.com/Netflix/vector/issues/7)
* [github.com/Netflix/vector/issues/74](https://github.com/Netflix/vector/issues/74)

**WARNING:** This PMDA was not *properly* tested. Use at your own risk.

Metrics
=======

The file ./help contains descriptions for all of the metrics exported
by this PMDA.

Once the PMDA has been installed, the following command will list all
the available metrics and their explanatory "help" text:

	$ pminfo -fT generic

Dependencies
============

You **must** have these dependencies installed in order to successfully generate the graphs.

* **perf command** - On Debian/Ubuntu based distributions, this is part of the *linux-tools* package.
* **perf-map-agent** - *Java-only* - If you would like to translate Java symbols, you will need perf-map-agent. Follow the instructions on [perf-map-agent](https://github.com/jrudolph/perf-map-agent) to install it.
* **Patched JDK** - *Java-only* - Besides perf-map-agent, you will also need a patched JDK that includes *frame pointer register*. From Java 8 update 60 onwards, this is made available by the *-XX:+PreserveFramePointer* option.

Installation
============

```
$ cd $PCP_PMDAS_DIR/generic
```

 +  Check that there is no clash in the Performance Metrics Domain
    defined in ./domain.h and the other PMDAs currently in use (see
    $PCP_PMCDCONF_PATH).  If there is, edit ./domain.h to choose another
    domain number.

 +  Then simply use

```
$ ./Install
```

 +  and choose both the "collector" and "monitor" installation
    configuration options -- everything else is automated.

De-installation
===============

 +  Simply use

```
$ cd $PCP_PMDAS_DIR/generic
$ ./Remove
```

Troubleshooting
===============

 +  After installing or restarting the agent, the PMCD log file
    ($PCP_LOG_DIR/pmcd/pmcd.log) and the PMDA log file
    ($PCP_LOG_DIR/pmcd/generic.log) should be checked for any warnings
    or errors.

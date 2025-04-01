this can make an alloy container for linux.
However. the metrics that alloy can see inside a containerized env are not as useful
they recommend doing bind mounts for /proc / and this is not a great idea.
Better to just run alloy as a systemd service and use the config.alloy from here for it.

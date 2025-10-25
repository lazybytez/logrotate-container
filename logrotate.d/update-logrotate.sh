#!/bin/bash
#
# A helper script for updating the /usr/bin/logrotate.d/logrotate.conf.

set -e

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh
source /usr/bin/logrotate.d/logrotate-config.sh


# Reset and then regenerate logrotate config
resetConfigurationFile
source /usr/bin/logrotate.d/logrotate-create-config.sh

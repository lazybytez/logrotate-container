#!/bin/bash
#
# A helper script for ENTRYPOINT.

set -e

[[ ${DEBUG} == true ]] && set -x

source /usr/bin/logrotate.d/logrotate.sh
source /usr/bin/logrotate.d/logrotate-config.sh

resetConfigurationFile

if [ -n "${DELAYED_START}" ]; then
  sleep ${DELAYED_START}
fi

# Create logrotate config
source /usr/bin/logrotate.d/logrotate-create-config.sh

cat /usr/bin/logrotate.d/logrotate.conf

# Crontab Generation
logrotate_parameters=""
if [ -n "${LOGROTATE_PARAMETERS}" ]; then
  logrotate_parameters="-"${LOGROTATE_PARAMETERS}
fi

logrotate_cronlog=""
if [ -n "${LOGROTATE_LOGFILE}" ] && [ -z "${SYSLOGGER}"]; then
  logrotate_cronlog=" 2>&1 | tee -a "${LOGROTATE_LOGFILE}
else
  if [ -n "${SYSLOGGER}" ]; then
    logrotate_cronlog=" 2>&1 | "${syslogger_command}
  fi
fi

logrotate_croninterval="1 0 0 * * *"
if [ -n "${LOGROTATE_INTERVAL}" ]; then
  case "$LOGROTATE_INTERVAL" in
    hourly)
      logrotate_croninterval='@hourly'
    ;;
    daily)
      logrotate_croninterval='@daily'
    ;;
    weekly)
      logrotate_croninterval='@weekly'
    ;;
    monthly)
      logrotate_croninterval='@monthly'
    ;;
    yearly)
      logrotate_croninterval='@yearly'
    ;;
    *)
      logrotate_croninterval="1 0 0 * * *"
    ;;
  esac
fi

if [ -n "${LOGROTATE_CRONSCHEDULE}" ]; then
  logrotate_croninterval=${LOGROTATE_CRONSCHEDULE}
fi

logrotate_cron_timetable="/usr/sbin/logrotate ${logrotate_parameters} --state=${logrotate_logstatus} /usr/bin/logrotate.d/logrotate.conf ${logrotate_cronlog}"

# Cron Startup
if [ "$1" = 'cron' ]; then
  if [ ${logrotate_autoupdate} = "true" ]; then
    mkdir -p /etc/ofelia
	cat <<EOF > /etc/ofelia/schedule-autoupdate.ini
[job-local "logrotate-with-autoupdate"]
schedule = ${logrotate_croninterval}
command = /bin/bash -c \"/usr/bin/logrotate.d/update-logrotate.sh && ${logrotate_cron_timetable}\"
EOF

	exec ofelia daemon --config /etc/ofelia/schedule-autoupdate.ini
    exit
  fi
	mkdir -p /etc/ofelia
	cat <<EOF > /etc/ofelia/schedule-standard.ini
[job-local "logrotate"]
schedule = ${logrotate_croninterval}
command = /bin/bash -c \"${logrotate_cron_timetable}\"
EOF

	exec ofelia daemon --config /etc/ofelia/schedule-standard.ini
fi

exec "$@"

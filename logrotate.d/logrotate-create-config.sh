#!/bin/bash
#
# Creation of logrotate configuration file based on environment variables

# Logfile Crawling
function handleSingleFile() {
  local singleFile="$1"
  local file_owner_user=$(stat -c %U ${singleFile})
  local file_owner_group=$(stat -c %G ${singleFile})
  local new_logrotate_entry=$(createLogrotateConfigurationEntry "${singleFile}" "${file_owner_user}" "${file_owner_group}" "${logrotate_copies}" "${logrotate_logfile_compression}" "${logrotate_logfile_compression_delay}" "${logrotate_mode}" "${logrotate_interval}" "${logrotate_size}" "${logrotate_dateformat}" "${logrotate_minsize}" "${logrotate_maxage}" "${logrotate_prerotate}" "${logrotate_postrotate}")

  echo "Inserting new ${singleFile} to /usr/bin/logrotate.d/logrotate.conf"
  insertConfigurationEntry "$new_logrotate_entry" "/usr/bin/logrotate.d/logrotate.conf"
}

log_dirs=""
if [ -n "${LOGS_DIRECTORIES}" ]; then
  log_dirs=${LOGS_DIRECTORIES}
else
  log_dirs=${log_dir}
fi

logs_ending="log"
if [ -n "${LOG_FILE_ENDINGS}" ]; then
  logs_ending="${LOG_FILE_ENDINGS}"
fi

find_filter=()
for ending in $logs_ending; do
  if [ ${#find_filter[@]} -gt 0 ]; then
    find_filter+=("-o")
  fi
  find_filter+=("-iname" "*.${ending}")
done

if [ -n "${LOGS_FILE_REGEX}" ]; then
  if [ ${#find_filter[@]} -gt 0 ]; then
    find_filter+=("-o")
  fi
  find_filter+=("-regex" "${LOGS_FILE_REGEX}")
fi

for d in ${log_dirs}; do
  if [ ! -d "${d}" ]; then
    continue
  fi

  while IFS= read -r -d '' f; do
    echo "Found new file $f, Processing..."
    handleSingleFile "$f"
  done < <(find "${d}" -type f \( "${find_filter[@]}" \) -print0 2>/dev/null)
done

# Take all log files in subfolder's
all_log_dirs=""
if [ -n "${ALL_LOGS_DIRECTORIES}" ]; then
  all_log_dirs=${ALL_LOGS_DIRECTORIES}
fi

for d in ${all_log_dirs}
do
  log_files=$(find ${d} -type f);
  for f in ${log_files};
  do
    if [ -f "${f}" ]; then
      echo "Found new file $f, Processing..."
      handleSingleFile "$f"
    fi
  done
done

cat /usr/bin/logrotate.d/logrotate.conf

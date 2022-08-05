#!/bin/sh

# Allow for bind-mount multiple settings.py overrides
FILES=$(ls /app/docker/extra_settings/* 2>/dev/null)
NUM_FILES=$(echo "$FILES" | wc -w)
if [ "$NUM_FILES" -gt 0 ]; then
    COMMA_LIST=$(echo $FILES | tr -s '[:blank:]' ', ')
    echo "============================================================"
    echo "     Overriding DefectDojo's local_settings.py with multiple"
    echo "     Files: $COMMA_LIST"
    echo "============================================================"
    cp /app/docker/extra_settings/* /app/dojo/settings/
    rm -f /app/dojo/settings/README.md
fi

umask 0002

# do the check with Django stack
python3 manage.py check

UWSGI_INIFILE=dojo/uwsgi.ini
cat > $UWSGI_INIFILE<<EOF
[uwsgi]
$DD_UWSGI_MODE = $DD_UWSGI_ENDPOINT
protocol = uwsgi
module = dojo.wsgi:application
enable-threads
processes = ${DD_UWSGI_NUM_OF_PROCESSES:-2}
threads = ${DD_UWSGI_NUM_OF_THREADS:-2}
threaded-logger
buffer-size = ${DD_UWSGI_BUFFER_SIZE:-4096}
EOF

if [ "${DD_LOGGING_HANDLER}" = "json_console" ]; then
    cat >> $UWSGI_INIFILE <<'EOF'
; logging as json does not offer full tokenization for requests, everything will be in message.
logger = stdio
log-encoder = json {"timestamp":${strftime:%%Y-%%m-%%d %%H:%%M:%%S%%z}, "source": "uwsgi", "message":"${msg}"}
log-encoder = nl
EOF
fi

exec uwsgi --ini $UWSGI_INIFILE

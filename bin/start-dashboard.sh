#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -o pipefail
set -o nounset   # exit the script if you try to use an uninitialised variable
set -o errexit   # exit the script if any statement returns a non-true return value

source "$(dirname "$0")/utils.sh"
load_rss_env 0

cd "$RSS_HOME"

DASHBOARD_CONF_FILE="${RSS_CONF_DIR}/dashboard.conf"
JAR_DIR="${RSS_HOME}/jars"
LOG_CONF_FILE="${RSS_CONF_DIR}/log4j.properties"
LOG_PATH="${RSS_LOG_DIR}/dashboard.log"
OUT_PATH="${RSS_LOG_DIR}/dashboard.out"

MAIN_CLASS="org.apache.uniffle.dashboard.web.JettyServerFront"

echo "Check process existence"
is_jvm_process_running "$JPS" $MAIN_CLASS

CLASSPATH=""

for file in $(ls ${JAR_DIR}/dashboard/*.jar 2>/dev/null); do
  CLASSPATH=$CLASSPATH:$file
done

mkdir -p "${RSS_LOG_DIR}"
mkdir -p "${RSS_PID_DIR}"

echo "class path is $CLASSPATH"

JVM_ARGS=" -server \
          -Xmx${XMX_SIZE:-8g} \
          -Xms${XMX_SIZE:-8g} \
          -XX:+UseG1GC \
          -XX:MaxGCPauseMillis=200 \
          -XX:ParallelGCThreads=20 \
          -XX:ConcGCThreads=5 \
          -XX:InitiatingHeapOccupancyPercent=45 \
          -XX:+PrintGC \
          -XX:+PrintAdaptiveSizePolicy \
          -XX:+PrintGCDateStamps \
          -XX:+PrintGCTimeStamps \
          -XX:+PrintGCDetails \
          -Xloggc:${RSS_LOG_DIR}/gc-%t.log"

JAVA11_EXTRA_ARGS=" -XX:+IgnoreUnrecognizedVMOptions \
          -Xlog:gc:tags,time,uptime,level"

ARGS=""

if [ -f ${LOG_CONF_FILE} ]; then
  ARGS="$ARGS -Dlog4j.configuration=file:${LOG_CONF_FILE} -Dlog.path=${LOG_PATH}"
else
  echo "Exit with error: ${LOG_CONF_FILE} file doesn't exist."
  exit 1
fi

$RUNNER $ARGS $JVM_ARGS $JAVA11_EXTRA_ARGS -cp $CLASSPATH $MAIN_CLASS --conf "$DASHBOARD_CONF_FILE" $@ &> $OUT_PATH &

get_pid_file_name dashboard
echo $! >${RSS_PID_DIR}/${pid_file}

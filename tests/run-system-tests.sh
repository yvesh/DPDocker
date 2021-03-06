#!/bin/bash

# Clear mysql data when running all tests
if [ -z "$2" ]; then
  # Remove the containers
  docker container rm -f $(docker container ls -q --filter name=tests_*) > /dev/null 2>&1

  # Cleanup data dirs
  sudo rm -rf $(dirname $0)/mysql_data
  sudo rm -rf $(dirname $0)/www
  mkdir $(dirname $0)/www

  # We start mysql early to rebuild the database
  EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml up -d mysql-test
  sleep 5
fi

# Run containers in detached mode so when the system tests command ends, we can stop them afterwards
EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml up -d phpmyadmin-test
EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml up -d mailcatcher-test
EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml up -d web-test
EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml up -d selenium-test

# Waiting for web server
while ! curl http://localhost:8080 > /dev/null 2>&1; do
  echo "$(date) - waiting for web server"
  sleep 4
done

# Waiting for selenium server
while ! curl http://localhost:4444 > /dev/null 2>&1; do
  echo "$(date) - waiting for selenium server"
  sleep 4
done

# Run VNC viewer
if [[ $(command -v vinagre) ]]; then
  vinagre localhost > /dev/null 2>&1 &
fi

# Run the tests
SECONDS=0
EXTENSION=$1 TEST=$2 REBUILD= docker-compose -f $(dirname $0)/docker-compose.yml run system-tests
duration=$SECONDS
echo "It took $(($duration / 60)) minutes and $(($duration % 60)) seconds to run the tests."

# Stop the containers
if [ -z "$2" ]; then
  docker container stop $(docker container ls -q --filter name=tests_*) > /dev/null 2>&1
fi

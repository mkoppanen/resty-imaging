#!/bin/bash

TEST_NUM=0

if_fail() {
  local ret_code=$1
  local url=$2
  local expected=$3
  local actual=$4

  if [[ $ret_code != 0 ]]
  then
  	echo "${url} failed. expected=[${expected}] actual=[${actual}]"
  	exit 1
  fi
}

test_url() {
	local url=$1
	local expect=$2

	let TEST_NUM="TEST_NUM+1"

	echo -n "test ${TEST_NUM}: "
	res=$(curl -I -s "${url}" | head -1)

	echo "${res}" | grep "${expect}"
	if_fail $? "${url}" "${expect}" "${res}"

}

test_url http://localhost:8080/resize/w=150,h=150,m=crop/https://foo.example.com "403"
test_url http://localhost:8080/resize/w=100,h=100,m=crop/https://upload.wikimedia.org/wikipedia/commons/d/db/Patern_test.jpg "200"
test_url http://localhost:8080/resize/w=150,h=150,m=crop/https://upload.wikimedia.org/wikipedia/commons/d/db/Patern_test.jpg "200"


#!/bin/bash

while true; do { 
  echo -ne "HTTP/1.0 200 OK\r\nContent-Length: $(wc -c <fakedata.htm)\r\n\r\n"; 
  cat fakedata.htm; } | nc -l -p 3000 ; 
done

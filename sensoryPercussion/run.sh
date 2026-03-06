#!/bin/bash
killall chuck 2>/dev/null
chuck --channels4 "$(dirname "$0")/sensoryPercussion_just.ck"

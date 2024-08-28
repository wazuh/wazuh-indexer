#!/bin/bash

# Check if VERSION file has exactly one line and that line is non-empty
if [ "$(wc -l <VERSION)" -ne 0 ]; then
    echo "Error: VERSION file must contain exactly one line."
    exit 1
fi
if [ -z "$(cat VERSION)" ]; then
    echo "Error: VERSION file is empty."
    exit 1
fi

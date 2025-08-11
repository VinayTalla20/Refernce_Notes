#!/bin/bash

set -e

REQUIRED_CODE_COVERAGE_PERCENTAGE=80.0

# Check if the JaCoCo XML file path is provided
if [ $# -eq 0 ]; then
    echo "Please provide the JaCoCo XML report file path"
    exit 1
fi

JACOCO_XML=$1

# Check if the file exists
if [ ! -f "$JACOCO_XML" ]; then
    echo "File not found: $JACOCO_XML"
    exit 1
fi

# Ensure xmllint is installed
if ! command -v xmllint &> /dev/null; then
    echo "xmllint is not installed. Please install libxml2-utils"
    sudo apt-get install bc libxml2-utils -y
fi

# Define a function to calculate coverage percentage
calculate_coverage() {
    local covered=$1
    local missed=$2
    local total=$((covered + missed))
    if [ $total -eq 0 ]; then
        echo "0.0"
    else
        echo "scale=1; $covered * 100 / $total" | bc
    fi
}

echo "Coverage Data:"

# Initialize total instruction coverage counters
total_instruction_covered=0
total_instruction_missed=0

# Get coverage for various types
for type in INSTRUCTION BRANCH LINE COMPLEXITY METHOD CLASS; do
    covered=$(xmllint --xpath "sum(/report/counter[@type='$type']/@covered)" $JACOCO_XML)
    missed=$(xmllint --xpath "sum(/report/counter[@type='$type']/@missed)" $JACOCO_XML)
    total=$((covered + missed))
    coverage=$(calculate_coverage $covered $missed)
    echo "${type} Coverage: ${covered} covered, ${missed} missed, ${total} total (${coverage}%)"

    # Accumulate INSTRUCTION coverage as the total coverage
    if [ "$type" = "INSTRUCTION" ]; then
        total_instruction_covered=$covered
        total_instruction_missed=$missed
    fi
done

# Calculate and output total coverage (echo here for GitLab usage)
total_coverage=$(calculate_coverage $total_instruction_covered $total_instruction_missed)

if awk "BEGIN {exit !(${total_coverage} >= ${REQUIRED_CODE_COVERAGE_PERCENTAGE})}"; then
    echo "✅ Pass Pipeline with Code Coverage ${total_coverage}%"
    echo "Total Coverage: ${total_coverage}%"
else
    echo "Required Code Coverage should be above ${REQUIRED_CODE_COVERAGE_PERCENTAGE}%"
    echo "Total Coverage: ${total_coverage}%"
    exit 1
fi

#!/bin/bash

set -euo pipefail

# SPDX-License-Identifier: Apache-2.0
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# Default values
DEFAULT_ECS_VERSION="v8.11.0"
DEFAULT_INDEXER_PATH="/wazuh-indexer"

# Function to display usage information
show_usage() {
  echo "Usage: $0 <ECS_MODULE> [<INDEXER_PATH>] [<ECS_VERSION>]"
  echo "  * ECS_MODULE: Module to generate mappings for"
  echo "  * INDEXER_PATH: Path to the Wazuh indexer repository (default: /wazuh-indexer)"
  echo "  * ECS_VERSION: ECS version to generate mappings for (default: v8.11.0)"
  echo "Example: $0 vulnerability-detector ~/wazuh-indexer v8.11.0"
}

# Function to remove multi-fields from the generated index template
remove_multi_fields() {
  local in_file="$1"
  local out_file="$2"

  jq 'del(
    .mappings.properties.host.properties.os.properties.full.fields,
    .mappings.properties.host.properties.os.properties.name.fields,
    .mappings.properties.vulnerability.properties.description.fields
  )' "$in_file" > "$out_file"
}

# Function to generate mappings
generate_mappings() {
  local ecs_module="$1"
  local indexer_path="$2"
  local ecs_version="$3"

  local in_files_dir="$indexer_path/ecs/$ecs_module/fields"
  local out_dir="$indexer_path/ecs/$ecs_module/mappings/$ecs_version"

  # Ensure the output directory exists
  mkdir -p "$out_dir"

  # Generate mappings
  python scripts/generator.py --strict --ref "$ecs_version" \
    --include "$in_files_dir/custom/" \
    --subset "$in_files_dir/subset.yml" \
    --template-settings "$in_files_dir/template-settings.json" \
    --template-settings-legacy "$in_files_dir/template-settings-legacy.json" \
    --mapping-settings "$in_files_dir/mapping-settings.json" \
    --out "$out_dir"

  # Replace unsupported types
  echo "Replacing unsupported types in generated mappings"
  find "$out_dir" -type f -exec sed -i 's/constant_keyword/keyword/g' {} \;
  find "$out_dir" -type f -exec sed -i 's/flattened/flat_object/g' {} \;
  find "$out_dir" -type f -exec sed -i 's/scaled_float/float/g' {} \;
  find "$out_dir" -type f -exec sed -i '/scaling_factor/d' {} \;

  local in_file="$out_dir/generated/elasticsearch/legacy/template.json"
  local out_file="$out_dir/generated/elasticsearch/legacy/template-tmp.json"

  # Delete the "tags" field from the index template
  echo "Deleting the \"tags\" field from the index template"
  jq 'del(.mappings.properties.tags)' "$in_file" > "$out_file"
  mv "$out_file" "$in_file"

  # Remove multi-fields from the generated index template
  echo "Removing multi-fields from the index template"
  remove_multi_fields "$in_file" "$out_file"
  mv "$out_file" "$in_file"

  # Transform legacy index template for OpenSearch compatibility
  jq '{
    "index_patterns": .index_patterns,
    "priority": .order,
    "template": {
      "settings": .settings,
      "mappings": .mappings
    }
  }' "$in_file" > "$out_dir/generated/elasticsearch/legacy/opensearch-template.json"

  echo "Mappings saved to $out_dir"
}

# Parse command line arguments
if [ -z "${1:-}" ]; then
  show_usage
  exit 1
fi

ECS_MODULE="$1"
INDEXER_PATH="${2:-$DEFAULT_INDEXER_PATH}"
ECS_VERSION="${3:-$DEFAULT_ECS_VERSION}"

# Generate mappings
generate_mappings "$ECS_MODULE" "$INDEXER_PATH" "$ECS_VERSION"

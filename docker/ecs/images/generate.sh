#!/bin/bash

set -e
set -u

# Default values
DEFAULT_ECS_VERSION="v.8.11.0"
DEFAULT_INDEX_PATH="/wazuh-indexer"

# Function to display usage information
show_usage() {
  echo "Usage: $0 <ECS_VERSION> <INDEXER_PATH> <ECS_MODULE> [--upload <URL>]"
  echo "  * ECS_MODULE: Module to generate mappings for"
  echo "  * INDEXER_PATH: Path to the wazuh-indexer repository"
  echo "  * ECS_VERSION: ECS version to generate mappings for"
  echo "Example: $0 v8.11.0 ~/wazuh-indexer vulnerability-detector --upload https://indexer:9200"
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
  local in_files_dir="$INDEXER_PATH/ecs/$ECS_MODULE/fields"
  local out_dir="$INDEXER_PATH/ecs/$ECS_MODULE/mappings/$ECS_VERSION"

  # Ensure the output directory exists
  mkdir -p "$out_dir" || exit 1

  # Generate mappings
  python scripts/generator.py --strict --ref "$ECS_VERSION" \
    --include "$in_files_dir/custom/" \
    --subset "$in_files_dir/subset.yml" \
    --template-settings "$in_files_dir/template-settings.json" \
    --template-settings-legacy "$in_files_dir/template-settings-legacy.json" \
    --mapping-settings "$in_files_dir/mapping-settings.json" \
    --out "$out_dir" || exit 1

  # Replace "constant_keyword" type (not supported by OpenSearch) with "keyword"
  echo "Replacing \"constant_keyword\" type with \"keyword\""
  find "$out_dir" -type f -exec sed -i 's/constant_keyword/keyword/g' {} \;

  # Replace "flattened" type (not supported by OpenSearch) with "flat_object"
  echo "Replacing \"flattened\" type with \"flat_object\""
  find "$out_dir" -type f -exec sed -i 's/flattened/flat_object/g' {} \;

  # Replace "scaled_float" type with "float"
  echo "Replacing \"scaled_float\" type with \"float\""
  find "$out_dir" -type f -exec sed -i 's/scaled_float/float/g' {} \;
  echo "Removing scaling_factor lines"
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
  cat "$in_file" | jq '{
    "index_patterns": .index_patterns,
    "priority": .order,
    "template": {
      "settings": .settings,
      "mappings": .mappings
    }
  }' >"$out_dir/generated/elasticsearch/legacy/opensearch-template.json"

  # Check if the --upload flag has been provided
  # if [ "$UPLOAD" == "--upload" ]; then
  #   upload_mappings "$out_dir" "$URL" || exit 1
  # fi

  echo "Mappings saved to $out_dir"
}

# Function to upload generated composable index template to the OpenSearch cluster
#upload_mappings() {
#  local out_dir="$1"
#  local URL="$2"
#
#  echo "Uploading index template to the OpenSearch cluster"
#  for file in "$out_dir/generated/elasticsearch/composable/component"/*.json; do
#    component_name=$(basename "$file" .json)
#    echo "Uploading $component_name"
#    curl -u admin:admin -X PUT "$URL/_component_template/$component_name?pretty" -H 'Content-Type: application/json' -d@"$file" || exit 1
#  done
#}

# Check if ECS_MODULE is provided
if [ -z "${1:-}" ]; then
  show_usage
  exit 1
fi

ECS_MODULE="$1"
INDEXER_PATH="${2:-$DEFAULT_INDEX_PATH}"
ECS_VERSION="${3:-$DEFAULT_ECS_VERSION}"
# UPLOAD="${4:-false}"
# URL="${5:-https://localhost:9200}"

# Generate mappings
generate_mappings "$ECS_VERSION" "$INDEXER_PATH" "$ECS_MODULE"

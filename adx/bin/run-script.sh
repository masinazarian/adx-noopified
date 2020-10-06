#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
#set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

export SOURCE_DATA_URL='https://apps.bea.gov/regional/zip/SAEXP.zip'
export S3_BUCKET='rearc-data-provider'
export DATASET_NAME='bea-personal-consumption-expenditures-by-state'
export DATASET_ARN=''  #arn:aws:dataexchange:us-east-1:796406704065:data-sets/b0e69f775c6eefca4b88e3364a30b082'
export DATASET_ID=''
export PRODUCT_NAME='BEA - Personal Consumption Expenditures (PCE) by State'
export PRODUCT_ID='BLANK'
export REGION='us-east-1'

while [[ ${#DATASET_NAME} -gt 53 ]]; do
    echo "dataset-name must be under 53 characters in length, use a shorter name!"
    exit 1
done

while [[ ${#PRODUCT_NAME} -gt 72 ]]; do
    echo "product-name must be under 72 characters in length, use a shorter name!"
    exit 1
done

echo "SOURCE_DATA_URL: $SOURCE_DATA_URL"
echo "S3_BUCKET: $S3_BUCKET"
echo "DATASET_NAME: $DATASET_NAME"
echo "DATASET_ARN: $DATASET_ARN"
echo "PRODUCT_NAME: $PRODUCT_NAME"
echo "PRODUCT_ID: $PRODUCT_ID"
echo "REGION: $REGION"
echo "PROFILE: $PROFILE"

# create dataset on ADX
echo "creating dataset on ADX"
DATASET_COMMAND="aws dataexchange create-data-set --asset-type "S3_SNAPSHOT" --description file://dataset-description.md --name \"${PRODUCT_NAME}\" --region $REGION --output json$PROFILE"
DATASET_OUTPUT=$(eval $DATASET_COMMAND)
DATASET_ARN=$(echo $DATASET_OUTPUT | tr '\r\n' ' ' | jq -r '.Arn')
DATASET_ID=$(echo $DATASET_OUTPUT | tr '\r\n' ' ' | jq -r '.Id')

echo "DATASET_OUTPUT: $DATASET_OUTPUT"
echo "DATASET_ARN: $DATASET_ARN"
echo "DATASET_ID: $DATASET_ID"

# create first dataset revision
echo "creating the first dataset revision; no product_id is passed as argument"
python src/create_dataset_revision.py \
    --source_data_url "$SOURCE_DATA_URL" \
    --region "$REGION" \
    --s3_bucket "$S3_BUCKET" \
    --dataset_name "$DATASET_NAME" \
    --dataset_id "$DATASET_ID" \
    --dataset_arn "$DATASET_ARN" \
    --product_name "$PRODUCT_NAME" 

# check dataset revision status
echo "grabbing dataset revision status"
DATASET_REVISION_STATUS=$(aws dataexchange list-data-set-revisions --data-set-id "$DATASET_ID" --region "$REGION" --query "sort_by(Revisions, &CreatedAt)[-1].Finalized"$PROFILE)

echo "DATASET_OUTPUT: $DATASET_OUTPUT"
echo "DATASET_ARN: $DATASET_ARN"
echo "DATASET_ID: $DATASET_ID"
echo "aws dataexchange list-data-set-revisions --data-set-id \"$DATASET_ID\" --region \"$REGION\" --query \"sort_by(Revisions, &CreatedAt)[-1].Finalized\"$PROFILE"

if [[ $DATASET_REVISION_STATUS == "true" ]]
then
  echo "Dataset revision completed successfully"
  echo ""

#   echo "Manually create the ADX product and paste the PRODUCT_ID below:"
#   export PRODUCT_ID='prod-????'  # <<< paste the product id from AWS ADX console here

#   echo ""
#   echo "S3_BUCKET: $S3_BUCKET"
#   echo "REGION: $REGION"
#   echo "DATASET_NAME: $DATASET_NAME"
#   echo "DATASET_ARN: $DATASET_ARN"
#   echo "DATASET_ID: $DATASET_ID"
#   echo "PRODUCT_ID: $PRODUCT_ID"
#   echo ""
#   echo "For the ProductId param use the Product ID of the ADX product"

#   echo "Updating dataset revision"
#     python src/create_datset_revision.py \
#         --source_data_url "$SOURCE_DATA_URL" \
#         --region "$REGION" \
#         --s3_bucket "$S3_BUCKET" \
#         --dataset_name "$DATASET_NAME" \
#         --dataset_id "$DATASET_ID" \
#         --dataset_arn "$DATASET_ARN" \
#         --product_name "$PRODUCT_NAME" \
#         --product_id "$PRODUCT_ID"

else
  echo "Dataset revision failed"
  cat response.json
fi
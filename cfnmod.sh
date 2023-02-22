#!/bin/bash

# cfn init
# cfn validate
# cfn submit

set -Eeuo pipefail

rm -Rf packaged-template-*.yaml
rm -Rf translated-template-*.json
rm -Rf submodule
submodules=( cicd dynamo glue iam kms s3 )
for module in "${submodules[@]}"
do
  # generate valid cfn module template
  # pushd "$module"
#  sam package --template-file ./template-"$module".yaml --s3-bucket sdlf-cfn-artifacts-eu-west-1-707076337478 --s3-prefix sdlf --output-template-file packaged-template-"$module".yaml
  sam package --template-file ./template-"$module".yaml --s3-bucket sdlf-cfn-artifacts-eu-west-1-218988792545 --s3-prefix sdlf --output-template-file packaged-template-"$module".yaml
  python3 ../sam-translate.py --template-file=packaged-template-"$module".yaml --output-template=translated-template-"$module".json
  # popd

  # create module
  mkdir submodule
  pushd submodule
  cfn init --artifact-type MODULE --type-name "awslabs::sdlf::team$module::MODULE" && rm fragments/sample.json
  cp -i -a ../translated-template-"$module".json fragments/
  cfn validate
  TYPE_VERSION_ARN=$(cfn submit | tee logs | grep "ProgressStatus" | tr "'" '"' | jq -r '.TypeVersionArn')
  cat logs && rm logs
  echo "registering new version as default"
  aws cloudformation set-type-default-version --type MODULE --arn "$TYPE_VERSION_ARN"
  echo "done"
  popd
  rm -Rf submodule
done
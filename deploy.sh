#!/bin/bash
sflag=false
tflag=false
rflag=false
eflag=false
dflag=false
fflag=false
oflag=false
cflag=false
aflag=false

DIRNAME=$PWD

usage () { echo "
    -h -- Opens up this help message
    -s -- Name of the AWS profile to use for the Shared DevOps Account
    -t -- AWS account ids of Child Accounts
    -r -- AWS Region to deploy to (e.g. eu-west-1)
    -e -- Environment to deploy to (dev, test or prod)
    -d -- Demo mode
    -f -- Deploys SDLF Foundations
"; }
options=':s:t:r:e:dfocha'
while getopts "$options" option
do
    case "$option" in
        s  ) sflag=true; DEVOPS_PROFILE=${OPTARG};;
        t  ) tflag=true; CHILD_ACCOUNTS=${OPTARG};;
        r  ) rflag=true; REGION=${OPTARG};;
        e  ) eflag=true; ENV=${OPTARG};;
        d  ) dflag=true;;
        f  ) fflag=true;;
        a  ) aflag=true;;
        h  ) usage; exit;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done

if ! "$sflag"
then
    echo "-s not specified, using default..." >&2
    DEVOPS_PROFILE="default"
fi
if ! "$tflag"
then
    echo "-t not specified, exiting..." >&2
    exit 1
fi
if ! "$rflag"
then
    echo "-r not specified, using default region..." >&2
    REGION=$(aws configure get region --profile "$DEVOPS_PROFILE")
fi
if ! "$eflag"
then
    echo "-e not specified, using dev environment..." >&2
    ENV=dev
fi
if ! "$dflag"
then
    echo "-d not specified, demo mode off..." >&2
    DEMO=false
else
    echo "-d specified, demo mode on..." >&2
    DEMO=true
    fflag=true
    oflag=true
    cflag=true
    git config --global user.email "robot@example.com"
    git config --global user.name "robot"
    echo y | sudo yum install jq
fi


DEVOPS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text --profile "$DEVOPS_PROFILE")

function template_protection()
{
    CURRENT_ENV=$1
    CURRENT_STACK_NAME=$2
    CURRENT_REGION=$3
    CURRENT_PROFILE_NAME=$4

    if [ "$CURRENT_ENV" != "dev" ]
    then
        echo "Updating termination protection for stack $CURRENT_STACK_NAME"
        aws cloudformation update-termination-protection \
            --enable-termination-protection \
            --stack-name "$CURRENT_STACK_NAME" \
            --region "$CURRENT_REGION" \
            --profile "$CURRENT_PROFILE_NAME"
    else
        echo "Target is the dev account. Not applying template protection"
    fi
}

if "$fflag"
then
    echo "Deploying SDLF components repositories..." >&2
    # TODO can probably merge bootstrap and prerequisites
    STACK_NAME=sdlf-cicd-prerequisites
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$DIRNAME"/sdlf-cicd/template-cicd-prerequisites.yaml \
        --tags Key=Framework,Value=sdlf \
        --capabilities "CAPABILITY_NAMED_IAM" "CAPABILITY_AUTO_EXPAND" \
        --region "$REGION" \
        --profile "$DEVOPS_PROFILE"
    echo "Waiting for stack to be created ..."
    aws cloudformation wait stack-create-complete --profile "$DEVOPS_PROFILE" --region "$REGION" --stack-name "$STACK_NAME"
    template_protection "$ENV" "$STACK_NAME" "$REGION" "$DEVOPS_PROFILE"
    declare -a REPOSITORIES=("sdlf-cicd" "sdlf-foundations" "sdlf-team" "sdlf-pipeline" "sdlf-dataset" "sdlf-datalakeLibrary" "sdlf-pipLibrary" "sdlf-stageA" "sdlf-stageB")
    for REPOSITORY in "${REPOSITORIES[@]}"
    do
        latest_commit=$(aws codecommit get-branch --repository-name "$REPOSITORY" --branch-name master --query 'branch.commitId' --output text)
        aws codecommit create-branch --repository-name "$REPOSITORY" --branch-name dev --commit-id "$latest_commit"
        aws codecommit create-branch --repository-name "$REPOSITORY" --branch-name test --commit-id "$latest_commit"
    done

    ARTIFACTS_BUCKET=$(aws ssm get-parameter --name /SDLF/S3/DevOpsArtifactsBucket --query "Parameter.Value" --output text)
    aws s3api put-object --bucket "$ARTIFACTS_BUCKET" --key sam-translate.py --body "$DIRNAME"/sdlf-cicd/sam-translate.py
    STACK_NAME=sdlf-cicd-bootstrap
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$DIRNAME"/sdlf-cicd/template-cicd-bootstrap.yaml \
        --tags Key=Framework,Value=sdlf \
        --capabilities "CAPABILITY_NAMED_IAM" "CAPABILITY_AUTO_EXPAND" \
        --region "$REGION" \
        --profile "$DEVOPS_PROFILE"
    echo "Waiting for stack to be created ..."
    aws cloudformation wait stack-create-complete --profile "$DEVOPS_PROFILE" --region "$REGION" --stack-name "$STACK_NAME"

    template_protection "$ENV" "$STACK_NAME" "$REGION" "$DEVOPS_PROFILE"

    mkdir "$DIRNAME"/output
    aws cloudformation package --profile "$DEVOPS_PROFILE" --template-file "$DIRNAME"/sdlf-cicd/template-cicd-sdlf-repositories.yaml --s3-bucket "$ARTIFACTS_BUCKET" --s3-prefix template-cicd-sdlf-repositories --output-template-file "$DIRNAME"/output/packaged-template.yaml
    STACK_NAME=sdlf-cicd-sdlf-repositories
    aws cloudformation deploy \
        --stack-name "$STACK_NAME" \
        --template "$DIRNAME"/output/packaged-template.yaml \
        --parameter-overrides \
            pChildAccounts="$CHILD_ACCOUNTS" \
        --tags Framework=sdlf \
        --capabilities "CAPABILITY_NAMED_IAM" "CAPABILITY_AUTO_EXPAND" \
        --region "$REGION" \
        --profile "$DEVOPS_PROFILE"
    echo "Waiting for stack to be created ..."
    aws cloudformation wait stack-create-complete --profile "$DEVOPS_PROFILE" --region "$REGION" --stack-name "$STACK_NAME"

    template_protection "$ENV" "$STACK_NAME" "$REGION" "$DEVOPS_PROFILE"
fi
